// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title Raffle
 * @author mudit004
 * @notice Creating simple raffle
 * @dev Implements chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleStateNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 lastTimeStamp, RaffleState raffleState, uint256 balance, uint256 playersLength
    );

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    /**
     * VRF Variables
     */
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;

    /**
     * State Variables
     */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // @dev Duration of Lottery in seconds
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players;
    RaffleState private s_raffleState;

    /**
     * Events
     */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /**
     * Constructor
     */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit,
        uint256 subscriptionId
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    /**
     * FUNCTIONS
     */
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ether to enter the raffle");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleStateNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /// @notice  Invalid
    /// @dev Automatically checks when upkeep is needed
    /// @return upkeepNeeded Boolean variables telling need to run the automated function
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 1. Gwt Random Number
    // 2. Use random number to decide player
    // 3. Automatically called
    function performUpkeep(bytes calldata /* performData */ ) external {
        // check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(s_lastTimeStamp, s_raffleState, address(this).balance, s_players.length);
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId); /* It is Redundant as VRFCoordinator also emitting this event. 
        Using here to just make our test easier*/

        // Get a random Number from Chainlink VRF
    }

    //Checks-Effects-Interactions
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        console.log("Request ID: %d", requestId);
        console.log("Random Words: %d", randomWords[0]);
        console.log("Number of Player: %d", s_players.length);
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        // require(success, "Transfer failed");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Function
     */

    // Getter for entranceFee (immutable variable)
    // function getEntranceFee() public view returns (uint256) {
    //     return i_entranceFee;
    // }

    // Getter for interval (immutable variable)
    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    // Getter for lastTimeStamp (modifiable variable)
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    // Getter for recentWinner (modifiable variable)
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    // Getter for players array
    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    // Getter for raffleState (enum)
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
}
