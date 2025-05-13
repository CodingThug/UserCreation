// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/UserCreation.sol";

contract UserCreationTest is Test {
    UserCreation public userCreation;
    address public constant OWNER = address(1);
    address public constant USER_1 = address(2);
    address public constant USER_2 = address(3);
    address public constant NON_OWNER = address(4);

    // Sepolia ETH/USD Price Feed Address
    address public constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // User creation parameters
    uint256 public constant DEFAULT_CREATION_PRICE = 0.005 ether;
    string public constant USER_1_NAME = "Alice";
    uint256 public constant USER_1_AGE = 25;
    bool public constant USER_1_IS_MARRIED = false;

    function setUp() public {
        // Deal Ether to accounts
        vm.deal(OWNER, 100 ether);
        vm.deal(USER_1, 100 ether);
        vm.deal(USER_2, 100 ether);
        vm.deal(NON_OWNER, 10 ether);

        // Deploy UserCreation contract as OWNER
        vm.startPrank(OWNER);
        userCreation = new UserCreation(SEPOLIA_ETH_USD_PRICE_FEED);
        // Removed setUserCreationPrice call, as initial price is already DEFAULT_CREATION_PRICE
        vm.stopPrank();
    }

    // --- Test User Creation ---
    function test_CreateUser_Success() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        vm.stopPrank();

        (string memory name, uint256 age, bool isMarried, uint256 userId) = userCreation.userProfiles(USER_1);
        assertEq(name, USER_1_NAME, "User name should match.");
        assertEq(age, USER_1_AGE, "User age should match.");
        assertEq(isMarried, USER_1_IS_MARRIED, "User marital status should match.");
        assertEq(userId, 1, "User ID should be 1 for the first user.");
        assertEq(userCreation.nextUserId(), 2, "nextUserId should increment after user creation.");
    }

    function test_CreateUser_Fail_IncorrectPayment() public {
        vm.prank(USER_1);
        vm.expectRevert(bytes("UC: Incorrect payment amount for user creation."));
        userCreation.createUser{value: 0.001 ether}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
    }

    function test_CreateUser_Fail_UserAlreadyExists() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        vm.stopPrank();

        vm.prank(USER_1);
        vm.expectRevert(bytes("UC: User profile already exists for this address."));
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}("Bob", 30, true);
    }

    function test_CreateUser_Fail_WhenPaused() public {
        vm.startPrank(OWNER);
        userCreation.togglePause();
        vm.stopPrank();

        vm.prank(USER_1);
        vm.expectRevert(bytes("UC: Contract is currently paused."));
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
    }

    // --- Test Deposit and Withdraw ---
    function test_DepositAndWithdraw_Success() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        vm.stopPrank();

        uint256 depositAmount = 1 ether;
        vm.startPrank(USER_1);
        userCreation.deposit{value: depositAmount}();
        vm.stopPrank();
        assertEq(userCreation.userDeposits(USER_1), depositAmount, "Deposit amount should be recorded.");

        uint256 initialBalanceUser1 = USER_1.balance;
        vm.startPrank(USER_1);
        userCreation.withdraw();
        vm.stopPrank();

        assertEq(userCreation.userDeposits(USER_1), 0, "User deposit balance should be zero after withdrawal.");
        assertEq(
            USER_1.balance, initialBalanceUser1 + depositAmount, "User Ether balance should increase after withdrawal."
        );
    }

    function test_Withdraw_Fail_NoBalance() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        vm.stopPrank();

        vm.prank(USER_1);
        vm.expectRevert(bytes("UC: No balance to withdraw."));
        userCreation.withdraw();
    }

    // --- Test Admin Functions ---
    function test_SetUserCreationPrice_Success() public {
        uint256 newPrice = 0.01 ether;
        vm.startPrank(OWNER);
        userCreation.setUserCreationPrice(newPrice);
        vm.stopPrank();
        assertEq(userCreation.userCreationPrice(), newPrice, "User creation price should be updated.");
    }

    function test_SetUserCreationPrice_Fail_NotOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(bytes("UC: Unauthorized, only owner can call."));
        userCreation.setUserCreationPrice(0.01 ether);
    }

    function test_SetUserCreationPrice_Fail_SamePrice() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("UC: New price must be different from the current price."));
        userCreation.setUserCreationPrice(DEFAULT_CREATION_PRICE);
    }

    function test_SetPriceFeedAddress_Success() public {
        address newFeedAddress = address(0xCafe);
        vm.startPrank(OWNER);
        userCreation.setPriceFeedAddress(newFeedAddress);
        vm.stopPrank();
    }

    function test_SetPriceFeedAddress_Fail_NotOwner() public {
        address newFeedAddress = address(0xCafe);
        vm.prank(NON_OWNER);
        vm.expectRevert(bytes("UC: Unauthorized, only owner can call."));
        userCreation.setPriceFeedAddress(newFeedAddress);
    }

    function test_TogglePause_Success() public {
        assertEq(userCreation.paused(), false, "Contract should initially be unpaused.");

        vm.startPrank(OWNER);
        userCreation.togglePause();
        vm.stopPrank();
        assertEq(userCreation.paused(), true, "Contract should be paused.");

        vm.startPrank(OWNER);
        userCreation.togglePause();
        vm.stopPrank();
        assertEq(userCreation.paused(), false, "Contract should be unpaused.");
    }

    function test_EmergencyWithdraw_Success_WhenPaused() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        userCreation.deposit{value: 2 ether}();
        vm.stopPrank();

        uint256 contractBalanceBefore = address(userCreation).balance;
        assertTrue(contractBalanceBefore > 0, "Contract should have a balance.");

        vm.startPrank(OWNER);
        userCreation.togglePause();
        uint256 ownerBalanceBefore = OWNER.balance;
        userCreation.emergencyWithdraw();
        vm.stopPrank();

        assertEq(address(userCreation).balance, 0, "Contract balance should be zero after emergency withdrawal.");
        assertEq(
            OWNER.balance, ownerBalanceBefore + contractBalanceBefore, "Owner should receive the contract's balance."
        );
    }

    function test_EmergencyWithdraw_Fail_NotPaused() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("UC: Contract is not paused."));
        userCreation.emergencyWithdraw();
    }

    // --- Test View Functions ---
    function test_GetUserProfile_Success() public {
        vm.startPrank(USER_1);
        userCreation.createUser{value: DEFAULT_CREATION_PRICE}(USER_1_NAME, USER_1_AGE, USER_1_IS_MARRIED);
        vm.stopPrank();

        (string memory name, uint256 age, bool isMarried, uint256 userId) = userCreation.getUserProfile(USER_1);

        assertEq(name, USER_1_NAME, "Profile name should match.");
        assertEq(age, USER_1_AGE, "Profile age should match.");
        assertEq(isMarried, USER_1_IS_MARRIED, "Profile marital status should match.");
        assertEq(userId, 1, "Profile user ID should match.");
    }

    function test_GetUserProfile_NonExistentUser() public view {
        (string memory name, uint256 age, bool isMarried, uint256 userId) = userCreation.getUserProfile(USER_2);

        assertEq(bytes(name).length, 0, "Profile name should be empty for non-existent user.");
        assertEq(age, 0, "Profile age should be zero for non-existent user.");
        assertEq(isMarried, false, "Profile marital status should be false for non-existent user.");
        assertEq(userId, 0, "Profile user ID should be zero for non-existent user.");
    }
}
