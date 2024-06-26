// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {SupporterRewards} from "../src/SupporterRewards.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {CMDKGenesisKit} from "../src/CMDKGenesisKit.sol";
import {ICMDKGenesisKit} from "../src/interfaces/ICMDKGenesisKit.sol";

contract DeployEmtRewards is Script {
    function run() public {
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address supporterToken = vm.envAddress("EMT_TOKEN");
        address cmdkToken = vm.envAddress("CMDK_TOKEN");

        vm.startBroadcast(privateKey);

        address beacon = Upgrades.deployBeacon("SupporterRewards.sol:SupporterRewards", deployerAddress);

        uint256 startBurnPrice = 1000;
        uint256 increaseStep = 100;

        SupporterRewards supporterRewards = SupporterRewards(
            Upgrades.deployBeaconProxy(
                beacon,
                abi.encodeCall(
                    SupporterRewards.initialize,
                    (deployerAddress, supporterToken, cmdkToken, startBurnPrice, increaseStep)
                )
            )
        );

        ICMDKGenesisKit(cmdkToken).setSkipNFTForAddress(address(supporterRewards), true);
        ICMDKGenesisKit(cmdkToken).transfer(address(supporterRewards), 500 * 10 ** 18);

        console2.log("EMT SupporterRewards deployed at:", address(supporterRewards));

        vm.stopBroadcast();
    }
}
