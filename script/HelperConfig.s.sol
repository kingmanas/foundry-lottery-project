// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";

contract HelperConfig is Script{
    struct NetworkConfig {
        uint256 entranceFee ;
         uint256 interval ;
          address vrfCoordinator;
           bytes32 gasLane ;
            uint64 subscriptionId ;
             uint32 callbackGasLimit;
             address link;
            //  uint256 deployerKey;
    }
NetworkConfig public activeNetworkConfig;

    constructor() {
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getorCreateAnvilConfig();
        }
    }



   function getSepoliaEthConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 1893,//Will update with subId
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            // deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
   function getorCreateAnvilConfig() public  returns(NetworkConfig memory networkconfig){
       if(activeNetworkConfig.vrfCoordinator != address(0)){
        return activeNetworkConfig;
       }

       uint96 baseFee = 0.25 ether; //0.25 link
       uint96 gasPriceLink = 1e9; //1 gwei link

    //  we will deploy a mock contract for our anvil chain to get the vrfcoordinator address and link token address
       vm.startBroadcast();
       VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
        baseFee,
        gasPriceLink
       );
       LinkToken link = new LinkToken();
       vm.stopBroadcast();

         return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0,// Our script will add this
            callbackGasLimit: 500000,
            link: address(link)
            // deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        }); 
    }
}