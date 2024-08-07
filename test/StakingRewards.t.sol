// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ISupporterRewards} from "../src/interfaces/ISupporterRewards.sol";
import {IStakingRewards} from "../src/interfaces/IStakingRewards.sol";
import {SupporterRewards} from "../src/SupporterRewards.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import {CMDKGenesisKit} from "../src/CMDKGenesisKit.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {StakingRewardsV2} from "./mocks/StakingRewardsV2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC404} from "erc404/interfaces/IERC404.sol";

contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    SupporterRewards public supporterRewards;
    ERC20Mock public supporterToken;
    CMDKGenesisKit public cmdkToken;
    address rewardsProxyAddress;
    address constant burnAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 constant NFT = 10 ** 18;
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    address owner = address(1);
    address tokenHolder = address(2);
    address anotherTokenHolder = address(3);
    address stranger = address(4);

    uint256 initialBurnCost = 1_000 ether;
    uint256 burnCostIncrement = 100 ether;
    uint256 initialStakeCost = 1_000 ether;
    uint256 stakeCostIncrement = 100 ether;
    uint256 totalAllocation = 4 * NFT;

    function helper_deployStakingRewards(address cmdkTokenAddress) internal returns (StakingRewards) {
        rewardsProxyAddress = Upgrades.deployTransparentProxy(
            "StakingRewards.sol",
            owner,
            abi.encodeCall(StakingRewards.initialize, (owner, cmdkTokenAddress))
        );
        return StakingRewards(rewardsProxyAddress);
    }

    function helper_deploySupporterRewards(
        address supporterTokenAddress,
        address stakingRewardsAddress
    ) internal returns (SupporterRewards) {
        address rewardsProxy = Upgrades.deployTransparentProxy(
            "SupporterRewards.sol",
            owner,
            abi.encodeCall(
                SupporterRewards.initialize,
                (
                    owner,
                    supporterTokenAddress,
                    initialBurnCost,
                    burnCostIncrement,
                    initialStakeCost,
                    stakeCostIncrement,
                    totalAllocation,
                    stakingRewardsAddress,
                    true
                )
            )
        );
        return SupporterRewards(rewardsProxy);
    }

    function setUp() public {
        vm.startPrank(owner);
        supporterToken = new ERC20Mock();
        supporterToken.mint(tokenHolder, 5_000 ether);
        supporterToken.mint(anotherTokenHolder, 5_000 ether);
        cmdkToken = new CMDKGenesisKit(owner);
        cmdkToken.transfer(tokenHolder, 10 * NFT);
        cmdkToken.transfer(anotherTokenHolder, 10 * NFT);
        stakingRewards = helper_deployStakingRewards(address(cmdkToken));
        supporterRewards =
            helper_deploySupporterRewards(address(supporterToken), address(stakingRewards));
        cmdkToken.setERC721TransferExempt(address(stakingRewards), true);
        stakingRewards.grantRole(BURNER_ROLE, address(supporterRewards));
        cmdkToken.setERC721TransferExempt(address(stakingRewards), true);
        cmdkToken.transfer(address(stakingRewards), 1 * NFT);
        vm.stopPrank();
    }

    function test_setup() public view {
        assertEq(stakingRewards.claimEnabled(), false);
        assertEq(cmdkToken.balanceOf(address(stakingRewards)), 1 * NFT);
    }

    function test_stake() public {
        vm.startPrank(tokenHolder);
        cmdkToken.approve(address(stakingRewards), 1 * NFT);
        vm.expectEmit();
        emit IStakingRewards.TokensStaked(1 * NFT);
        stakingRewards.stakeTokens(1 * NFT);
        vm.stopPrank();
        assertEq(cmdkToken.balanceOf(tokenHolder), 9 * NFT);
        IStakingRewards.Stake memory stake = stakingRewards.usersStake(tokenHolder, 0);
        assertEq(stake.amount, 1 * NFT);
    }

    function test_userCount() public {
        vm.startPrank(tokenHolder);
        cmdkToken.approve(address(stakingRewards), 1 * NFT);
        stakingRewards.stakeTokens(1 * NFT);
        vm.stopPrank();
        uint256 numUsers = stakingRewards.userCount();
        assertEq(numUsers, 1);
        address firstUser = stakingRewards.user(0);
        assertEq(firstUser, tokenHolder);
        vm.startPrank(anotherTokenHolder);
        cmdkToken.approve(address(stakingRewards), 1 * NFT);
        stakingRewards.stakeTokens(1 * NFT);
        vm.stopPrank();
        numUsers = stakingRewards.userCount();
        assertEq(numUsers, 2);
        address secondUser = stakingRewards.user(1);
        assertEq(secondUser, anotherTokenHolder);
    }

    function test_stakeInternal_onlyRole_revert() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, BURNER_ROLE
            )
        );
        stakingRewards.stakeInternalTokens(stranger, 1 * NFT);
    }

    function test_claimAll_claimEnbled_revert() public {
        vm.startPrank(tokenHolder);
        cmdkToken.approve(address(stakingRewards), 10 * NFT);
        stakingRewards.stakeTokens(10 * NFT);
        vm.expectRevert(IStakingRewards.ClaimingNotEnabled.selector);
        stakingRewards.claimAll();
        assertEq(cmdkToken.balanceOf(address(tokenHolder)), 0);
        vm.stopPrank();
    }

    function test_setClaimEnabled_onlyOwner_revert() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, DEFAULT_ADMIN_ROLE
            )
        );
        stakingRewards.setClaimEnabled(true);
    }

    function test_claimAll_staked() public {
        vm.prank(owner);
        stakingRewards.setClaimEnabled(true);
        vm.startPrank(tokenHolder);
        cmdkToken.approve(address(stakingRewards), 10 * NFT);
        stakingRewards.stakeTokens(10 * NFT);
        stakingRewards.claimAll();
        assertEq(cmdkToken.balanceOf(address(tokenHolder)), 10 * NFT);
        assertEq(cmdkToken.balanceOf(address(stakingRewards)), 1 * NFT);
        vm.stopPrank();
    }

    function test_claimAll_burnt() public {
        vm.prank(owner);
        stakingRewards.setClaimEnabled(true);
        vm.startPrank(anotherTokenHolder);
        uint256 burnAmount = 1 * initialBurnCost;
        supporterToken.approve(address(supporterRewards), burnAmount);
        supporterRewards.burnSupporterToken(burnAmount);
        uint256 startBalance = cmdkToken.balanceOf(anotherTokenHolder);
        stakingRewards.claimAll();
        uint256 endBalance = cmdkToken.balanceOf(anotherTokenHolder);
        assertEq(endBalance - startBalance, 1 * NFT);
        assertEq(cmdkToken.balanceOf(address(stakingRewards)), 0);
        vm.stopPrank();
    }

    function test_claim_noDoubleClaim() public {
        vm.prank(owner);
        stakingRewards.setClaimEnabled(true);
        vm.startPrank(tokenHolder);
        cmdkToken.approve(address(stakingRewards), 10 * NFT);
        stakingRewards.stakeTokens(10 * NFT);
        stakingRewards.claimAll();
        vm.expectRevert(IStakingRewards.MustBeNonZero.selector);
        stakingRewards.claimAll();
        assertEq(cmdkToken.balanceOf(address(tokenHolder)), 10 * NFT);
        assertEq(cmdkToken.balanceOf(address(stakingRewards)), 1 * NFT);
        vm.stopPrank();
    }

    function test_withdrawTokens() public {
        uint256 startBalance = cmdkToken.balanceOf(owner);
        vm.prank(owner);
        stakingRewards.withdrawTokens(1 * NFT);
        uint256 endBalance = cmdkToken.balanceOf(owner);
        assertEq(endBalance - startBalance, 1 * NFT);
        assertEq(cmdkToken.balanceOf(address(stakingRewards)), 0);
    }

    function test_withdrawTokens_onlyOwner_revert() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, DEFAULT_ADMIN_ROLE
            )
        );
        stakingRewards.withdrawTokens(1 * NFT);
    }

    function test_upgrade() public {
        vm.startPrank(owner);
        Upgrades.upgradeProxy(
            rewardsProxyAddress,
            "StakingRewardsV2.sol",
            abi.encodeCall(StakingRewardsV2.initializeV2, ())
        );
        assertEq(StakingRewardsV2(rewardsProxyAddress).version(), 2);
        assertEq(StakingRewardsV2(rewardsProxyAddress).claimEnabled(), false);
    }
}
