// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract UserCreation is ReentrancyGuard {
    // State Variables
    address public owner;
    uint256 public userCreationPrice = 0.005 ether;
    uint256 public userId = 1;
    bool public paused;
    uint256 public constant MAX_NAME_LENGTH = 32;
    AggregatorV3Interface internal priceFeed;

    // Structs
    struct User {
        string name;
        uint256 age;
        bool isMarried;
        uint256 userId;
    }

    // Mappings
    User[] public users;
    mapping(address => User) public listOfUsers;
    mapping(address => uint256) public userDeposits;

    // Events
    event UserCreated(address indexed newUser, string userName, uint256 userId);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event AdminAction(address indexed admin, string action);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    modifier userCreatePrice() {
        require(msg.value == userCreationPrice, "Incorrect payment");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() {
        owner = msg.sender;
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); // ETH/USD Sepolia
    }

    // Admin Functions
    function setCreationPrice(uint256 newPrice) external onlyOwner {
        require(newPrice != userCreationPrice, "Price unchanged");
        userCreationPrice = newPrice;
        emit AdminAction(msg.sender, "Price updated");
    }

    function togglePause() external onlyOwner {
        paused = !paused;
        emit AdminAction(msg.sender, paused ? "Contract paused" : "Contract unpaused");
    }

    function emergencyWithdraw() external onlyOwner {
        require(paused, "Contract not paused");
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
        emit AdminAction(msg.sender, "Emergency withdrawal");
    }

    // User Functions
    function createUser(string memory userName, uint256 age, bool isMarried)
        external
        payable
        userCreatePrice
        whenNotPaused
    {
        require(listOfUsers[msg.sender].userId == 0, "User already exists");
        require(msg.sender != address(0), "Invalid address");
        require(bytes(userName).length > 0, "Empty name");
        require(bytes(userName).length <= MAX_NAME_LENGTH, "Name too long");
        require(age >= 18, "Minimum age 18");

        // Refund excess ETH
        if (msg.value > userCreationPrice) {
            payable(msg.sender).transfer(msg.value - userCreationPrice);
        }

        users.push(User(userName, age, isMarried, userId));
        listOfUsers[msg.sender] = User(userName, age, isMarried, userId);

        emit UserCreated(msg.sender, userName, userId);
        userId++;
    }

    function deposit() external payable whenNotPaused {
        require(listOfUsers[msg.sender].userId != 0, "User not registered");
        userDeposits[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external nonReentrant whenNotPaused {
        uint256 amount = userDeposits[msg.sender];
        require(amount > 0, "No balance to withdraw");
        require(address(this).balance >= amount, "Insufficient contract balance");

        userDeposits[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    // Chainlink Price Feed
    function getEthInUsd(uint256 ethAmount) public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (ethAmount * uint256(price)) / 1e18;
    }
}
