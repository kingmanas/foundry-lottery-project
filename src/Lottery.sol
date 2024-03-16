// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFCoordinatorV2.sol";
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

    /// @title A sample Lottery Contract
    /// @author BlockBuddy
    /// @notice To create a simple lottery
    /// @dev implements ChainVrf tools

contract Lottery is VRFConsumerBaseV2{

    error Lottery__NotEnoughEthSent();
    error Lottery__NotEnoughTimePassed();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__UpKeepNotNeeded(uint256 balance, uint256 numberOfPlayers , uint256 lotterystate);
    
    // Type Declarations--->>

    enum LotteryState {
        OPEN,      //==0
        CALCULATING//==1
    }

    // State Variables--->>

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; //duration of the lottery in seconds
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackgasLimit;
    bytes32 private immutable i_gasLane; 

    uint256 private s_lastTimeStamp; 
    address payable[] private s_players;
    address private s_Winners;
    LotteryState private s_lotteryState;
     

    // ??EVENTS

    event EnteredLottery(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedLotteryWinner(uint256 indexed player);

    constructor(uint256 entranceFee , uint256 interval , address vrfCoordinator, bytes32 gasLane , uint64 subscriptionId , uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator){
        i_interval = interval;
        i_callBackgasLimit = callbackGasLimit;
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;
    }
    function enterLottery() external payable {
        if(msg.value < i_entranceFee){
            revert Lottery__NotEnoughEthSent();
        }
         if(s_lotteryState != LotteryState.OPEN){
        revert Lottery__LotteryNotOpen();
       }
        s_players.push(payable(msg.sender));
        emit EnteredLottery(msg.sender);
    }
    ///--->>>>>>> This is a function to see if the time has come to perform the upkeep
    // Following neds to be true for this to return true-->>
    // 1.Thr time has passed between raffle runs
    // 2.The raffle is in the open state
    // 3.The contract has eth (aka players)
    // 4.(implicit) The subsciption is funded with link
    function checkUpKeep(bytes memory) public view returns(bool upKeepNeeded , bytes memory){
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; 
        bool isOpen = LotteryState.OPEN == s_lotteryState;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance >0;
        upKeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return(upKeepNeeded,"0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external  {
        (bool upkeepNeeded ,) = checkUpKeep("");
        if(!upkeepNeeded){
            revert Lottery__UpKeepNotNeeded(
               address(this).balance,
               s_players.length,
               uint256(s_lotteryState)
            );
        }
       if( (block.timestamp - s_lastTimeStamp) < i_interval){
        revert Lottery__NotEnoughTimePassed();
       }
       s_lotteryState = LotteryState.CALCULATING;
      
            uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackgasLimit,
            NUM_WORDS
        );

        emit RequestedLotteryWinner(requestId);

    }
    // CEI: Check , Effects and Interactions

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory words
    ) internal override{
        // CHECKS
        // EFFECTS-->>
        uint256 indexOfWinner = words[0] % s_players.length;
        address winner = s_players[indexOfWinner];
        s_Winners = winner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        // INTERACTIONS-->>
        (bool callSuccess,) = winner.call{value: address(this).balance}("");
        if(!callSuccess){
            revert Lottery__TransferFailed();
        }
    }

    // GETTER FUNCTIONS
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }
    function getLotteryState() external view returns(LotteryState){
        return s_lotteryState;
    }
    function getPlayers(uint256 index) external view returns(address){
        return s_players[index];
    }
    function getWinner() external view returns(address winner){
        return s_Winners;
    }
    function getNumberOfPlayers() external view returns(uint256){
        return s_players.length;
    }
    function getTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}