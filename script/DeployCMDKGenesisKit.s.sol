// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {SupporterRewards} from "../src/SupporterRewards.sol";
import {CMDKGenesisKit} from "../src/CMDKGenesisKit.sol";

contract DeployCMDKGenesisKit is Script {
    function run() public {
        address owner = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        CMDKGenesisKit cmdkGenesisKit = new CMDKGenesisKit(owner);

        console.log("CMDKGenesisKit deployed at:", address(cmdkGenesisKit));

        vm.stopBroadcast();
    }
}
