// SPDX-License-Identifier: MIT

/// @title A contract for programmatically creating a subscription
/// @author BlockBuddy
/// @notice Craeting a subscription programatically
/// @dev using VRFCoordinatorV2Mock for creating subscription

pragma solidity ^0.8.19;

import {Script,console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public returns(uint64){
          HelperConfig helperConfig = new HelperConfig();
            (,, address vrfCoordinator ,,,,
        ) = helperConfig.activeNetworkConfig();

    }
    function createSubscription(address vrfCoordinator) public returns(uint64){
        console.log("Creating Subsciption on chainId: ", block.chainid);
    //    We neeed to call createSubsciption function on VRFCoordinatorV2Mock
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your Sub Id is",subId);
        console.log("Please update SUbsciption on HelperConfig");
        return subId;
    }
    function run() external returns(uint64){
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
         HelperConfig helperConfig = new HelperConfig();
            (,, address vrfCoordinator ,,uint64 subId,,address link
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator,subId,link);
    }
    function fundSubscription(address vrfCoordinator , uint64 subId , address link) public {
        console.log("Funding Subscription: ", subId);
        console.log("Using VRFCooridnator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        if(block.chainid == 31337){
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
                );
                vm.stopBroadcast();
        }else{
             vm.startBroadcast();
             LinkToken(link).transferAndCall(vrfCoordinator,FUND_AMOUNT, abi.encode(subId));
        }
    }
    function run() external {
        fundSubscriptionUsingConfig();
    }

}
//  We want to add a consumer
contract AddConsumer is Script{

    function addConsumer(address lottery, address vrfCoordinator ,uint64 subId /*uint256 deployerKey*/ ) public {
        console.log("Adding consumer contracts: " , lottery);
        console.log("Using VRFCoordinator: " , vrfCoordinator);
        console.log("On chainId: " , block.chainid);
        vm.startBroadcast(/*deployerKey*/);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, lottery);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig(); 
          (,, address vrfCoordinator ,,uint64 subId,,/*uint256 deployerKey*/
        ) = helperConfig.activeNetworkConfig();
        addConsumer(lottery , vrfCoordinator , subId /* deployerKey*/);

           }
    function run() external { // we want to get the most recentkly deploted contract of the Lottery contract 
    address lottery = DevOpsTools.get_most_recent_deployment("Lottery", block.chainid);
    addConsumerUsingConfig(lottery);
    }
}