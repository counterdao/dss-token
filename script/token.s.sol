// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {DSSToken} from "../src/token.sol";

contract DeployDSSToken is Script {
    function deployDSSToken(address dss, address ctr) public {
        DSSToken token = new DSSToken(dss, ctr);
    }

    function run() public {
        vm.broadcast();

        address dss = vm.envAddress("DSS_DSS_ADDRESS");
        address ctr = vm.envAddress("DSS_CTR_ADDRESS");
        deployDSSToken(dss, ctr);

        vm.stopBroadcast();
    }
}
