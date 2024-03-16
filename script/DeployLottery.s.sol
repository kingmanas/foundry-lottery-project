// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription , FundSubscription , AddConsumer} from "./Interactions.s.sol";
contract DeployLottery is Script{
    function run() external returns(Lottery , HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        (
             uint256 entranceFee ,
         uint256 interval ,
          address vrfCoordinator,
           bytes32 gasLane ,
            uint64 subscriptionId ,
             uint32 callbackGasLimit,
             address link
            //  uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){ // If we dont have a subscription we create one
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator);
            // And then fund that subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link);
        }

        vm.startBroadcast();
        Lottery lottery = new Lottery(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(lottery), vrfCoordinator, subscriptionId  /*deployerKey*/);
        return (lottery , helperConfig);

    }
}