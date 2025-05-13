// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
/**
 * @title UserCreation
 * @author Your Name (or Your DApp Name)
 * @notice This contract allows users to create profiles, deposit, and withdraw Ether.
 * It also includes administrative functions for managing the contract.
 * @dev Uses OpenZeppelin's ReentrancyGuard and Chainlink Price Feeds.
 */

contract UserCreation is ReentrancyGuard {
    // State Variables

    /**
     * @notice The address of the contract owner with administrative privileges.
     */
    address public owner;

    /**
     * @notice The fee required to create a new user profile, in wei.
     */
    uint256 public userCreationPrice = 0.005 ether; // Default price

    /**
     * @notice A counter to assign unique IDs to users. Starts at 1.
     */
    uint256 public nextUserId = 1;

    /**
     * @notice A flag to pause or unpause critical contract functions.
     * @dev When true, certain user actions like creating users, depositing, or withdrawing are disabled.
     */
    bool public paused;

    /**
     * @notice The maximum allowed length for a user's name.
     */
    uint256 public constant MAX_NAME_LENGTH = 32;

    /**
     * @notice The interface for the Chainlink ETH/USD price feed.
     */
    AggregatorV3Interface internal priceFeed;

    // Structs

    /**
     * @notice Represents a user profile.
     * @param name The user's chosen name.
     * @param age The user's age.
     * @param isMarried The user's marital status.
     * @param userId A unique identifier for the user.
     */
    struct User {
        string name;
        uint256 age;
        bool isMarried;
        uint256 userId; // This ID comes from the global nextUserId
    }

    // Mappings

    /**
     * @notice Maps a user's Ethereum address to their User struct.
     * @dev This is the primary storage for user profiles, allowing efficient lookup by address.
     */
    mapping(address => User) public userProfiles;

    /**
     * @notice Maps a user's Ethereum address to their deposited Ether balance within the contract.
     */
    mapping(address => uint256) public userDeposits;

    // Events

    /**
     * @notice Emitted when a new user profile is successfully created.
     * @param userAddress The address of the newly created user.
     * @param userName The name chosen by the user.
     * @param userId The unique ID assigned to the user.
     */
    event UserCreated(address indexed userAddress, string userName, uint256 userId);

    /**
     * @notice Emitted when a user successfully deposits Ether into the contract.
     * @param userAddress The address of the user making the deposit.
     * @param amount The amount of Ether deposited, in wei.
     */
    event Deposit(address indexed userAddress, uint256 amount);

    /**
     * @notice Emitted when a user successfully withdraws Ether from the contract.
     * @param userAddress The address of the user making the withdrawal.
     * @param amount The amount of Ether withdrawn, in wei.
     */
    event Withdrawal(address indexed userAddress, uint256 amount);

    /**
     * @notice Emitted when an administrative action is performed by the owner.
     * @param admin The address of the owner performing the action.
     * @param action A description of the action taken (e.g., "Price updated", "Contract paused").
     */
    event AdminAction(address indexed admin, string action);

    // Modifiers

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "UC: Unauthorized, only owner can call.");
        _;
    }

    /**
     * @dev Throws if the sent Ether value does not exactly match the `userCreationPrice`.
     */
    modifier exactCreationPrice() {
        require(msg.value == userCreationPrice, "UC: Incorrect payment amount for user creation.");
        _;
    }

    /**
     * @dev Throws if the contract is currently paused.
     */
    modifier whenNotPaused() {
        require(!paused, "UC: Contract is currently paused.");
        _;
    }

    /**
     * @dev Throws if the contract is not paused. Used for functions that should only run when paused (e.g., emergencyWithdraw).
     */
    modifier whenPaused() {
        require(paused, "UC: Contract is not paused.");
        _;
    }

    /**
     * @notice Sets the initial owner and the Chainlink price feed address.
     * @param _initialPriceFeedAddress The address of the Chainlink ETH/USD price feed for the target network.
     */
    constructor(address _initialPriceFeedAddress) {
        owner = msg.sender;
        require(_initialPriceFeedAddress != address(0), "UC: Initial price feed address cannot be zero.");
        priceFeed = AggregatorV3Interface(_initialPriceFeedAddress);
        emit AdminAction(msg.sender, "Contract deployed and initialized.");
    }

    // --- Admin Functions ---

    /**
     * @notice Allows the owner to set a new price for user creation.
     * @dev Emits an AdminAction event.
     * @param _newPrice The new creation price in wei.
     */
    function setUserCreationPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice != userCreationPrice, "UC: New price must be different from the current price.");
        require(_newPrice > 0, "UC: Creation price must be greater than zero."); // Added check for non-zero price
        userCreationPrice = _newPrice;
        emit AdminAction(msg.sender, "User creation price updated.");
    }

    /**
     * @notice Allows the owner to update the Chainlink price feed address.
     * @dev Emits an AdminAction event.
     * @param _newPriceFeedAddress The new address for the Chainlink price feed.
     */
    function setPriceFeedAddress(address _newPriceFeedAddress) external onlyOwner {
        require(_newPriceFeedAddress != address(0), "UC: New price feed address cannot be zero.");
        require(_newPriceFeedAddress != address(priceFeed), "UC: New price feed address must be different.");
        priceFeed = AggregatorV3Interface(_newPriceFeedAddress);
        emit AdminAction(msg.sender, "Price feed address updated.");
    }

    /**
     * @notice Allows the owner to toggle the paused state of the contract.
     * @dev Emits an AdminAction event indicating whether the contract was paused or unpaused.
     */
    function togglePause() external onlyOwner {
        paused = !paused;
        if (paused) {
            emit AdminAction(msg.sender, "Contract paused.");
        } else {
            emit AdminAction(msg.sender, "Contract unpaused.");
        }
    }

    /**
     * @notice Allows the owner to withdraw all Ether from the contract in an emergency.
     * @dev This function can only be called when the contract is paused.
     * It uses `nonReentrant` as an extra precaution, though direct transfers are generally safe.
     * Emits an AdminAction event.
     */
    function emergencyWithdraw() external onlyOwner whenPaused nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "UC: No balance to withdraw.");

        (bool success,) = owner.call{value: balance}("");
        require(success, "UC: Emergency withdrawal failed.");

        emit AdminAction(msg.sender, "Emergency withdrawal performed.");
    }

    // --- User Functions ---

    /**
     * @notice Allows a new user to create a profile by paying the `userCreationPrice`.
     * @dev Validates user input and ensures the user does not already exist.
     * Emits a UserCreated event.
     * @param _userName The desired username (must be <= MAX_NAME_LENGTH).
     * @param _age The user's age (must be >= 18).
     * @param _isMarried The user's marital status.
     */
    function createUser(string memory _userName, uint256 _age, bool _isMarried)
        external
        payable
        exactCreationPrice // Ensures msg.value == userCreationPrice
        whenNotPaused
    {
        require(userProfiles[msg.sender].userId == 0, "UC: User profile already exists for this address.");
        require(msg.sender != address(0), "UC: Cannot create user for the zero address.");

        bytes memory userNameBytes = bytes(_userName);
        require(userNameBytes.length > 0, "UC: User name cannot be empty.");
        require(userNameBytes.length <= MAX_NAME_LENGTH, "UC: User name exceeds maximum length.");

        require(_age >= 18, "UC: User must be at least 18 years old.");

        // No refund logic needed here because `exactCreationPrice` modifier ensures
        // msg.value == userCreationPrice. If it's not exact, the transaction reverts.

        uint256 newId = nextUserId;
        userProfiles[msg.sender] = User(_userName, _age, _isMarried, newId);

        emit UserCreated(msg.sender, _userName, newId);
        nextUserId++;
    }

    /**
     * @notice Allows a registered user to deposit Ether into their account within the contract.
     * @dev The contract must not be paused. Emits a Deposit event.
     * @dev msg.value is the amount to deposit.
     */
    function deposit() external payable whenNotPaused {
        require(userProfiles[msg.sender].userId != 0, "UC: User profile does not exist. Cannot deposit.");
        require(msg.value > 0, "UC: Deposit amount must be greater than zero.");

        userDeposits[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows a registered user to withdraw their deposited Ether.
     * @dev The contract must not be paused. Uses `nonReentrant` guard.
     * Emits a Withdrawal event.
     */
    function withdraw() external nonReentrant whenNotPaused {
        uint256 amount = userDeposits[msg.sender];
        require(amount > 0, "UC: No balance to withdraw.");
        // No need to check address(this).balance >= amount here, as the user can only withdraw
        // their own deposited funds. If the contract somehow has less than `amount` (which
        // shouldn't happen with correct deposit/withdrawal logic), the transfer will fail.
        // However, for robustness, especially if other Ether-handling functions are added,
        // a check `require(address(this).balance >= amount, "UC: Insufficient contract balance for withdrawal.");`
        // could be considered, though it might be redundant in the current setup.

        userDeposits[msg.sender] = 0; // Follows checks-effects-interactions pattern

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "UC: Ether transfer failed during withdrawal.");

        emit Withdrawal(msg.sender, amount);
    }

    // --- View Functions ---

    /**
     * @notice Gets the latest ETH price in USD from Chainlink.
     * @dev Does not account for decimals of the asset, assumes standard 18 decimals for ETH.
     * The price returned is ETH in USD with 8 decimals (Chainlink default for ETH/USD).
     * @return price The latest ETH price in USD (e.g., 300000000000 means $3000.00).
     */
    function getLatestEthPriceInUsd() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        // The price from Chainlink ETH/USD already has 8 decimals.
        return price;
    }

    /**
     * @notice Converts a given amount of Ether (in wei) to its equivalent value in USD.
     * @dev Uses the latest ETH/USD price from Chainlink.
     * The result will have 8 decimal places (from the price feed).
     * @param _ethAmountInWei The amount of Ether in wei (1 ether = 1e18 wei).
     * @return usdValue The equivalent value in USD, with 8 decimal places.
     * For example, if price is $3000 (3000 * 10^8) and _ethAmountInWei is 1 ETH (1 * 10^18 wei),
     * result is (1 * 10^18 * 3000 * 10^8) / 10^18 = 3000 * 10^8.
     */
    function convertEthToUsd(uint256 _ethAmountInWei) public view returns (uint256) {
        int256 ethPriceUsd = getLatestEthPriceInUsd(); // This has 8 decimals
        require(ethPriceUsd > 0, "UC: ETH price must be positive.");

        // Calculation: (amountWei * priceWith8Decimals) / 10^18 (to scale wei to ether)
        // The result will effectively be USD value with 8 decimals.
        return (_ethAmountInWei * uint256(ethPriceUsd)) / 1e18;
    }

    /**
     * @notice Retrieves the profile of a given user address.
     * @param _userAddress The address of the user.
     * @return name The user's name.
     * @return age The user's age.
     * @return isMarried The user's marital status.
     * @return userId The user's unique ID. Returns 0 if user does not exist.
     */
    function getUserProfile(address _userAddress)
        public
        view
        returns (string memory name, uint256 age, bool isMarried, uint256 userId)
    {
        User storage user = userProfiles[_userAddress];
        return (user.name, user.age, user.isMarried, user.userId);
    }

    // --- Fallback and Receive ---
    // This contract is not intended to receive Ether directly without a function call.
    // Omitting receive() and fallback() payable functions means that any direct Ether
    // transfer to the contract (not calling a specific payable function like deposit or createUser)
    // will be reverted. This is a common security practice to prevent Ether from being
    // accidentally locked in the contract.
    // If you wanted to accept Ether via direct sends, you would implement:
    // receive() external payable { /* ... */ }
    // fallback() external payable { /* ... */ }
}
