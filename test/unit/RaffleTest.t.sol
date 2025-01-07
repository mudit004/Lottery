// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public config;
    address public USER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane; // keyHash
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    /** Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() public {
        (raffle, config) = new DeployRaffle().deployContract();
        HelperConfig.NetworkConfig memory helperConfig = config.getConfig();
        // console.log(helperConfig.entranceFee);
        entranceFee = helperConfig.entranceFee;
        interval = helperConfig.interval;
        vrfCoordinator = helperConfig.vrfCoordinator;
        gasLane = helperConfig.gasLane;
        callbackGasLimit = helperConfig.callbackGasLimit;
        subscriptionId = helperConfig.subscriptionId;

        vm.deal(USER, STARTING_BALANCE);
    }
    modifier raffleEntered() {
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    function testEnterRaffleRevertIfLessValue() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.005 ether}();
    }

    function testRaffleRecordsWhenPlayerEnter() public {
        //Arrange
        vm.prank(USER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        assert(raffle.getPlayer(0) == USER);
    }

    function testEnteringRaffleEmitEvent() public {
        //Arrange
        vm.prank(USER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(address(USER));
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDoesNotAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(USER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        //Assert
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__RaffleStateNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
    
    /*/////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        //Arrange
        vm.prank(USER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        //Arrange
        vm.prank(USER);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(USER);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(USER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                block.timestamp,
                raffleState,
                currentBalance,
                numPlayers
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesraffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestID) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /*//////////////////////////////////////////////////////////////
                         FULLFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEntered
    {
        address expectedWinner = address(2);

        // Arrange
        uint256 additionalEntrances = 6;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
