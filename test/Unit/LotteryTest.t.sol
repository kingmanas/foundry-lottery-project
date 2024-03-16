// SPDX-License-Identifier: MIT
//forge coverage --report debug > coverage.txt
pragma solidity ^0.8.19;

import {Test,console} from "lib/forge-std/src/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
contract Lotterytest is Test{
    
    event EnteredLottery(address indexed player);


    Lottery lottery;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 private constant STARTING_BALANCE = 10 ether;
      uint256 entranceFee ;
      uint256 interval ;
      address vrfCoordinator;
      bytes32 gasLane ;
      uint64 subscriptionId ;
      uint32 callbackGasLimit;
      address link;
    //   uint256 deployerKey;

    modifier Player {
        vm.prank(PLAYER);
        vm.deal(PLAYER,STARTING_BALANCE);
        _;
    }

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery,helperConfig) = deployer.run();
          (
             entranceFee,
             interval,
             vrfCoordinator,
             gasLane,
             subscriptionId,
             callbackGasLimit,
             link
            //  deployerKey
       
        ) = helperConfig.activeNetworkConfig();
         vm.deal(PLAYER,STARTING_BALANCE);
    }

    function testLotteryStateIsOpen() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }


    function testLotteryRevertsWhenDontPayEnough() public {
        //Assert
        vm.prank(PLAYER);
        //Act
        vm.expectRevert(Lottery.Lottery__NotEnoughEthSent.selector);//can also define which revert i wanted to have.
        lottery.enterLottery();

    }
    function testLotteryRecordsPlayersEntered() public Player {
    
       lottery.enterLottery{value: entranceFee}();//jab function payable ho to hum usme value ya ether bhej skte hai chahe vovalue leta ho ya nahi..
       address player = lottery.getPlayers(0);
       assert(player == PLAYER);
    }
    function testEmitEventOnEntrance() public Player{
    //    By setting expectations before the event emission, the testing framework can efficiently track and verify the emitted event. It ensures the framework is prepared to capture the specific event and its arguments.
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER);
         lottery.enterLottery{value: entranceFee}();
    }
    function testCantEnterWhenLotteryStateIsNotOpen() public Player {
        lottery.enterLottery{value: entranceFee}();
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }
    function testCantEnterWhenLotteryStateIsCalculating() public Player{
        lottery.enterLottery{value: entranceFee}();
        // We have to make the checkupKeep Function going to get the LotteryState from the perfromUpKeep function.

        vm.warp(block.timestamp + interval + 1);//sets the timestamp for the test
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
        
        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        vm.prank(PLAYER);
         lottery.enterLottery{value: entranceFee}();
    }
    /////////////////
    ///CHECKUPKEEP///
    ////////////////
    function testCheckUpKeepFailsIfHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upKeepNeeded ,) = lottery.checkUpKeep("");
        // Assert
        assert(!upKeepNeeded);
    }
    function testCheckUpKeepReturnFalseIfLotteryIsNotOpen() public Player{//we have to enter the lottery and change the lottery dtate to calculation by perfromUpKeep.
        
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");

        (bool upKeepNeeded ,) = lottery.checkUpKeep("");

        assert(upKeepNeeded == false);
    }

    function testEnoughTimeHasPassedToPerformCheckUpKeep() public {
        vm.roll(block.number + 1);

        (bool upKeepNeeded , ) = lottery.checkUpKeep("");

        assert(!upKeepNeeded);
    }
    function testCheckKeepUpReturnsTrueIfParametersAreMet() public Player {
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp +  interval + 1);
        vm.roll(block.number + 1);

        (bool checkUpKeepNeeded ,) = lottery.checkUpKeep("");

        assert(checkUpKeepNeeded == true);

    }
    /////////////////
    ///PERFROMUPKEEP///
    ////////////////
    function testPerformUpKeepRevertsIfCheckUpKeepIsTrue() public Player 
    {     lottery.enterLottery{value: entranceFee}();
          vm.roll(block.number + 1);
            vm.warp(block.timestamp +  interval + 1);

        lottery.performUpkeep("");  
    }
    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public{
        uint256 currentBalance =0;
        uint256 numPlayers = 0;
        uint256 lotteryState = 0;
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__UpKeepNotNeeded.selector , currentBalance , numPlayers , lotteryState));
        lottery.performUpkeep("");
    }
    modifier LotteryenteredandTimePassed {
          vm.prank(PLAYER);
       
         lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if we need to test using the output of an event..??
    function testPerformUpKeepUpdatesLotteryStateAndEmitsRequestId() public LotteryenteredandTimePassed{
     

        vm.recordLogs();//records all the events emitted by the next function
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();//used to get the recorded logs of the function and Vm is used as a datatype to record all of this.
        bytes32 requestId = entries[1].topics[1]; //to get the emit result of thet particular event and it gets recorded in bytes32 thats why its bytes32 there.

        assert(requestId>0);
        assert(lottery.getLotteryState() == Lottery.LotteryState.CALCULATING);
    }
    modifier skipFork(){
        if(block.chainid != 31337){
            return;
        }
        _;
    }
    
    ////////////////////////////
   ///FULFILL RANDOM WORDS////////
    ////////////////////////////
    
       function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomId)
        public
        LotteryenteredandTimePassed
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomId,
            address(lottery)
        );

        // vm.expectRevert("nonexistent request");

        // VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
        //     1,
        //     address(lottery)
        // );
    }
    function testFulfillRandomWordsPicksAnWinnerResetsAndSendsMoney() public LotteryenteredandTimePassed skipFork {
        //we want to get players that we want to make enter our lottery.
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex ; i < (startingIndex + additionalEntrants) ; i++){
            address player = address(uint160(i));//it will give out a new address everytime with the chaniging values of i.
            hoax(player , STARTING_BALANCE);//vm.prank + vm.deal ek saath krna
            lottery.enterLottery{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);
        vm.recordLogs();
        lottery.performUpkeep("");//emits requested
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = lottery.getTimeStamp();

        // Pretend to be chainlinkVrf to access the random words and pickwinner.

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId), address(lottery));
        
        // asserts
        assert(uint256(lottery.getLotteryState()) == 0);
        assert(lottery.getWinner() != address(0));
        assert(lottery.getNumberOfPlayers() == 0);
        assert(previousTimeStamp < lottery.getTimeStamp());
        
        assert(lottery.getWinner().balance == prize + STARTING_BALANCE - entranceFee);

    }
}