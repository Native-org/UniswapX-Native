// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {NativeRouterExecutor} from "../src/sample-executors/NativeRouterExecutor.sol";
import {NativeRouterExecutor} from "../src/sample-executors/NativeRouterExecutor.sol";
import {INativeRouter} from "../src/external/INativeRouter.sol";
import {IReactor} from "../src/interfaces/IReactor.sol";

contract DeploySwapRouter02Executor is Script {
    function setUp() public {}

    function run() public returns (NativeRouterExecutor executor) {
        uint256 privateKey = vm.envUint("FOUNDRY_PRIVATE_KEY");
        IReactor reactor = IReactor(vm.envAddress("FOUNDRY_NATIVEROUTEREXECUTOR_DEPLOY_REACTOR"));
        address whitelistedCaller = vm.envAddress("FOUNDRY_NATIVEROUTEREXECUTOR_DEPLOY_WHITELISTED_CALLER");
        address owner = vm.envAddress("FOUNDRY_NATIVEROUTEREXECUTOR_DEPLOY_OWNER");
        INativeRouter nativeRouter = INativeRouter(vm.envAddress("FOUNDRY_NATIVEROUTEREXECUTOR_DEPLOY_NATIVEROUTER"));

        vm.startBroadcast(privateKey);
        executor = new NativeRouterExecutor{salt: 0x00}(whitelistedCaller, reactor, owner, nativeRouter);
        vm.stopBroadcast();

        console2.log("SwapRouter02Executor", address(executor));
        console2.log("owner", executor.owner());
    }
}
