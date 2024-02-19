// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
/**
 * @title A sample Raffle Contract
 * @author Nakul tiwari
 * @notice This comtract creates raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2{
    error Raffle__NotEnoughEthSent();
    error Raffle__TranferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance,uint256 numPlayers, uint256 raffleState);
    //enum 

    enum RaffleState{
        OPEN,
        CALCULATING
    }
    //State Variables
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;  //duration of lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscribtionId;
    uint32 private immutable i_callbackGasLimit;

    
    address payable[] private s_players;
    uint256 private s_LastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    //EVENTS
    event Enteredraffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event requestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval,address vrfCoordinator,bytes32 gasLane,uint64 subscriptionId,uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscribtionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_LastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }
    function enterRaffle() external payable{
        if(msg.value<i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit Enteredraffle(msg.sender);
    }

/**
 * @dev This function does the chainlink automation nodes call to see if its time to perform an upkeep!
 * the folowing should be true to run:
 * 1)The time interval should have been passed betwween Raffle Runs 
 * 2) The Raffle is in OPEN State
 * 3) The contract has ETH(players)
 * 4)The subscription should be funded with link!
 */
    function checkUpkeep(bytes memory /*checkData*/) public view returns(bool upkeepNeeded, bytes memory /*performData*/){
        bool timeHasPassed = ((block.timestamp-s_LastTimeStamp)>=i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalanace = address(this).balance > 0;
        bool hasPlayers = s_players.length>0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalanace && hasPlayers);
        return (upkeepNeeded,"0x0");

    }
    function performUpkeep(bytes calldata /* performData */) external{
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length,uint256(s_raffleState));
        } 
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscribtionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );    
        emit requestedRaffleWinner(requestId);

    }
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner= winner;
        s_raffleState = RaffleState.OPEN;

        // reset the array as old players need to pay to join the new raffle
        s_players = new address payable[](0);
        s_LastTimeStamp= block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TranferFailed();
        }
        emit WinnerPicked(winner);
    }

    // ** GETTERS **//

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
}
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
    function getplayers(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }
    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
    function getLengthOfPlayers() external view returns(uint256 ){
        return s_players.length;
    }
    function getLastTimeStamp() external view returns(uint256){
        return s_LastTimeStamp;
    }

}