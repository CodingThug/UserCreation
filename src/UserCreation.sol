// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract UserCreation{
// ----- State Variable ----- // 
    address public owner;

    uint public getUserPrice = 0.0005 ether;
    uint public userCreationPrice = 0.005 ether;
    uint public userId = 1;

    User[] public users;

    mapping(address => User) public listOfUsers;
    mapping(address => User) public userStatus;

// ----- Structs ----- //
    struct User{
      string name;
      uint age;
      bool isMarried;
      address user;
      uint userId;
    }

// ----- Modifiers ----- //
    modifier onlyOwner(){
      require(msg.sender == owner, "You don't have those privileges here, my g.");
      _;
    }

    modifier userCreatePrice(){
      require(msg.value == userCreationPrice, "You gotta pay to create a user, and if you short, go re-up, then we got you.");
      _;
    }

    modifier getTheUserPrice(){
      require(msg.value == getUserPrice, "You gotta throw in the right funds to see that info.");
      _;
    }

// ----- Events ----- //
    event UserCreated(address indexed newUser, string userName, uint userId);
// ----- Enumerations ----- //
    enum ISAUSER{
        NOTAUSER,
        NEWUSER
    }
    ISAUSER isAUser;
// ----- Errors ----- //
error ownerOrAlreadyCreated(address currentUser, uint currentId);
// ----- Constructor ----- //
    constructor(){
      owner = msg.sender;
      isAUser = ISAUSER.NOTAUSER;
    }
// ----- Functions ----- //
}

