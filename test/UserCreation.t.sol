// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/UserCreation.sol";

contract UserCreationTest is Test {
    UserCreation public userCreation;
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.prank(owner);
        userCreation = new UserCreation();
    }

    function testUserCreation() public {
        vm.prank(user1);
        userCreation.createUser{value: 0.005 ether}("Alice", 25, false);

        (string memory name,,, uint256 userId) = userCreation.listOfUsers(user1);
        assertEq(name, "Alice");
        assertEq(userId, 1);
    }

    function testDepositAndWithdraw() public {
        // First create user
        vm.prank(user1);
        userCreation.createUser{value: 0.005 ether}("Alice", 25, false);

        // Deposit
        vm.prank(user1);
        userCreation.deposit{value: 1 ether}();
        assertEq(userCreation.userDeposits(user1), 1 ether);

        // Withdraw
        uint256 initialBalance = user1.balance;
        vm.prank(user1);
        userCreation.withdraw();
        assertEq(userCreation.userDeposits(user1), 0);
        assertEq(user1.balance, initialBalance + 1 ether);
    }

    function testOnlyOwnerFunctions() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        userCreation.setCreationPrice(0.01 ether);
    }
}
