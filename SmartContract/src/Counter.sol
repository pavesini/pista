// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    
    /****************************************************************
        GLOBALS
    ****************************************************************/
    
    uint256 public  Number;                         // The counter
    uint256 public  AdminCounter;                   // Number of admin accounts
    bool    public  Paused;                         // Contract State

    mapping(address => bool)    public  IsAdmin;    // Mapping for admin addresses


    /****************************************************************
        EVENTS & ERRORS
    ****************************************************************/

    // Counter event, fires when `Number` changes
    event Fired(address sender, uint counter);

    // Records the authorization of an address by an admin
    event Authorized(address who, bool status, address by);


    /****************************************************************
        MODIFIERS
    ****************************************************************/

    /**
        Requires the caller (msg.sender) of the function is an Admin
     */
    modifier onlyAdmin() {
        require (IsAdmin[msg.sender] == true, "Not Admin");
        _;
    }

    /**
        Prevents the modified function from running during pause
     */
    modifier onlyIfNotPaused() {
        require (Paused == false, "Contract Puased");
        _;
    }


    /****************************************************************
        CONSTRUCTOR
    ****************************************************************/

    constructor(address _1stadmin) {
        // Set contract creator as admin
        IsAdmin[_1stadmin] = true;
        AdminCounter = 1;
        emit Authorized(_1stadmin, true, msg.sender);
    }


    /****************************************************************
        GOVERNANCE FUNCTIONS
    ****************************************************************/

    /**
        Un/Pauses the contract
     */
    function pause(bool _pause) public onlyAdmin {
        Paused = _pause;
    }


    /**
        Re/Sets the admin status of an address
        must be called by an admin address
     */
     function authorize(address _addr, bool _isadmin) public onlyAdmin {
        require (IsAdmin[_addr] != _isadmin, "State unchanged");
        if (_isadmin) {
            AdminCounter++;
        } else {
            require (AdminCounter > 1, "Need 1 admin");
            AdminCounter--;
        }
        IsAdmin[_addr] = _isadmin;
        emit Authorized(_addr, _isadmin, msg.sender);
     }


    /****************************************************************
        COUNTER FUNCTIONS
    ****************************************************************/

    /**
        Forces the `Number` to a specific value
        must be called by an admin account
        emits a `Fired` event
     */
    function setNumber(uint256 newNumber) public onlyAdmin {
        Number = newNumber;
        emit Fired(msg.sender, Number);
    }


    /**
        Increments `Number`
        can be called by any address
        reverts if contract is paused
     */
    function increment() public onlyIfNotPaused {
        Number++;
        emit Fired(msg.sender, Number);
    }
}
