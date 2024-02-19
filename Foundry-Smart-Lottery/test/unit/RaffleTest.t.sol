//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // EVENTS
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit,link,) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleReturnswhenYouDontPayEnoughEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getplayers(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsonEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
    function testCantEnterWhenRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
    }
    ///////////CHECK UPKEEP////////////////////////////////
    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public{
        vm.warp(block.timestamp+ interval + 1);           //Arrange
        vm.roll(block.number+1);

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); //Act


        assert(!upkeepNeeded);        //Assert
    }
    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+ interval + 1);            // Arrange
        vm.roll(block.number+1);
        raffle.performUpkeep("");


        (bool upkeepNeeded,) = raffle.checkUpkeep(""); //Act  

        assert(!upkeepNeeded);        //Assert
    }
    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+ interval + 1);            
        vm.roll(block.number+1);

        //ACT//ASSER
        raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public{
        uint256 currentBalance=0;
        uint256 numPlayers = 0;          //ARRANGE
        uint256 raffleState = 0;


        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance,numPlayers,raffleState)); //ACT/ASERT
        raffle.performUpkeep("");
    }
    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+ interval + 1);            
        vm.roll(block.number+1);
        _;
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsrequestId() public raffleEnteredAndTimePassed{
         //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        Raffle.RaffleState rState= raffle.getRaffleState();
        //ASsert
        assert(uint256(requestId)>0);
        assert(uint256(rState) == 1);
    }
    ///////////Test For FulFillRandomWords//////////////////////////
    modifier skipFork(){
        if(block.chainid!=31337){
            return;
        }
        _;
    }
    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork{ 
         //Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }
    function testFullfillRandomWordsPicksWinnerResetsAndSendMoney() public raffleEnteredAndTimePassed skipFork{
        //Arrange
        uint256 additionalEntrance = 5;
        uint256 startingIndex =1;
        for(uint256 i=startingIndex; i<startingIndex; i++){
            address player = address(uint160(i));
            hoax(player,STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 prize = entranceFee * (additionalEntrance+1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //assert(uint256(raffle.getRaffleState())==0);
        //assert(raffle.getRecentWinner() != address(0));
        //assert(raffle.getLengthOfPlayers()==0);
        //assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_BALANCE + prize - entranceFee);
    }
}
