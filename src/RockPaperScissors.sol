// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RockPaperScissors is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public gameID;

    struct Game {
        address player1;
        address player2;
        uint256 stakedAmount;
        bytes32 player1Move;
        State player2Move;
        uint256 revealTime;
        address winner;
    }

    mapping(uint256 => Game) public games;

    enum State {
        ROCK,
        PAPER,
        SCISSOR
    }

    error Invalid_Move();

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    modifier validGameID(uint256 _gameId) {
        require(_gameId <= gameID, "Game ID is invalid");
        _;
    }

    function startGame(bytes32 _hash) public payable {
        require(msg.value > 0, "Must stake more than 0");
        ++gameID;
        games[gameID].player1 = msg.sender;
        games[gameID].player1Move = _hash;
        games[gameID].stakedAmount = msg.value;
        games[gameID].revealTime = block.timestamp + 1 days;
    }

    /**
     * @param _gameId : ID of the game being played
     * @param _move: The move player 2 made
     *  @notice Player 2 joins and gives his move
     */
    function joinGame(uint256 _gameId, State _move) public payable validGameID(_gameId) {
        require(msg.value == games[_gameId].stakedAmount, "Must stake the same amount as player 1");
        require(games[_gameId].player2 == address(0), "Player2 already exists");
        require(games[_gameId].player1 != msg.sender, "Cannot join own game");
        games[_gameId].player2 = msg.sender;
        games[_gameId].player2Move = _move;
        games[_gameId].stakedAmount += msg.value;
    }

    /**
     * @param _gameId : ID of the game being played
     * @param _player1Move: The move player 1 made
     * @param _salt : Salt that was used to hash his move
     * @notice Player1 must reveal his move once the player 2 has played his
     */
    function reveal(uint256 _gameId, State _player1Move, string memory _salt) public validGameID(_gameId) {
        Game storage game = games[_gameId];
        bytes32 calculatedHash = keccak256(abi.encodePacked(_player1Move, _salt));
        // Validation
        if (calculatedHash != game.player1Move) revert Invalid_Move();

        // Winner conditions
        if (game.player2Move == State.PAPER && _player1Move == State.ROCK) {
            game.winner = game.player2;
        } else if (game.player2Move == State.SCISSOR && _player1Move == State.PAPER) {
            game.winner = game.player2;
        } else if (game.player2Move == State.ROCK && _player1Move == State.SCISSOR) {
            game.winner = game.player2;
        } else if (game.player2Move == _player1Move) {
            uint256 stakedAmount = game.stakedAmount;
            address player2 = game.player2;
            address player1 = game.player1;
            // If tied - game over!
            delete games[_gameId];
            payable(player2).transfer(stakedAmount / 2);
            payable(player1).transfer(stakedAmount / 2);
        } else {
            game.winner = game.player1;
        }
    }

    /**
     * @param _gameId : ID of the game
     * @notice Claim player wins in two conditions:
     *     1. If he is the winner
     *     2. Or if the player1 has not revealed his move before the reveal expire time
     */
    function claimPrize(uint256 _gameId) public validGameID(_gameId) {
        Game storage game = games[_gameId];
        uint256 prize = game.stakedAmount;
        if (game.winner != address(0)) {
            address winner = game.winner;
            delete games[_gameId];
            payable(winner).transfer(prize);
            return;
        }

        if (game.winner == address(0) && game.revealTime < block.timestamp) {
            address player2 = game.player2;
            delete games[_gameId];
            payable(player2).transfer(prize);
        }
    }

    /**
     * @param _gameId The game to withdraw from
     * @notice Withdraw the game before the player 2 joins
     */
    function withdrawGame(uint256 _gameId) public validGameID(_gameId) {
        require(games[_gameId].player1 == msg.sender, "Invalid player");
        require(games[_gameId].player2 == address(0), "Cannot withdraw now!");

        uint256 stakedAmount = games[_gameId].stakedAmount;
        delete games[_gameId];
        payable(msg.sender).transfer(stakedAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
