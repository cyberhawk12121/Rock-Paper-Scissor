// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import { RockPaperScissors } from "../src/RockPaperScissors.sol";
import { Test } from "forge-std/Test.sol";

contract RockPaperScissorsTest is Test {
    RockPaperScissors rps;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    function setUp() public {
        rps = new RockPaperScissors();
        deal(alice, 10 ether);
        deal(bob, 10 ether);
        deal(carol, 10 ether);
    }

    function testStartGame() public {
        bytes32 _player1Response = keccak256(abi.encode(RockPaperScissors.State.ROCK, "alice"));
        vm.prank(alice);
        rps.startGame{ value: 1 ether }(_player1Response);

        (address player1, address player2, uint256 staked, bytes32 player1Move,, uint256 endTime,) = rps.games(1);
        assertEq(player1, alice);
        assertEq(address(rps).balance, 1 ether);
        assertEq(player2, address(0));
        assertEq(staked, 1 ether);
        assertEq(player1Move, _player1Response);
        assertEq(endTime, block.timestamp + 1 days);
    }

    function testWithdrawStartedGame() public {
        bytes32 _player1Response = keccak256(abi.encode(RockPaperScissors.State.ROCK, "alice"));
        vm.startPrank(alice);
        rps.startGame{ value: 1 ether }(_player1Response);
        assertEq(address(rps).balance, 1 ether);
        rps.withdrawGame(1);
        vm.stopPrank();

        assertEq(address(rps).balance, 0);
    }

    function testJoinGame() public {
        bytes32 _player1Response = keccak256(abi.encode(RockPaperScissors.State.ROCK, "alice"));
        vm.startPrank(alice);
        rps.startGame{ value: 1 ether }(_player1Response);
        vm.expectRevert("Cannot join own game");
        rps.joinGame{ value: 1 ether }(1, RockPaperScissors.State.SCISSOR);
        vm.stopPrank();

        // Player 2 joins the game with same staked amount
        vm.startPrank(bob);
        // expect failure if staking less
        vm.expectRevert("Must stake the same amount as player 1");
        rps.joinGame{ value: 0.9 ether }(1, RockPaperScissors.State.SCISSOR);
        // succeed with same staked amount
        rps.joinGame{ value: 1 ether }(1, RockPaperScissors.State.SCISSOR);
        vm.stopPrank();

        // Fails if two players have already joined the game
        vm.prank(carol);
        vm.expectRevert("Player2 already exists");
        rps.joinGame{ value: 2 ether }(1, RockPaperScissors.State.SCISSOR);

        (address player1, address player2, uint256 staked, bytes32 player1Move,, uint256 endTime,) = rps.games(1);
        assertEq(player1, alice);
        assertEq(player2, bob);
        assertEq(staked, 2 ether);
        assertEq(player1Move, _player1Response);
        assertEq(endTime, block.timestamp + 1 days);
    }

    function testJoinAlreadyJoinedGame() public { }

    function testBothPlayersSameMove() public { }

    function testBothPlayersDifferentMove() public { }

    function testRevealBeforeJoin() public { }

    function testRevealBeforeJoin2() public { }

    function testMultipleGames() public { }
}
