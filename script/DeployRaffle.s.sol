// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscriptions, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        if (networkConfig.subscriptionId == 0) {
            (networkConfig.subscriptionId,) = new CreateSubscription().createSubscription(networkConfig.vrfCoordinator);
            // fund it
            FundSubscriptions fundSubscriptions = new FundSubscriptions();
            fundSubscriptions.fundSubscription(
                networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link
            );
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.callbackGasLimit,
            networkConfig.subscriptionId
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId);
        return (raffle, helperConfig);
    }
}
