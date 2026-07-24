// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
    Counter contract
    This contract is a dummy contract aimed at showcasing PISTA
    The scenario is that of a smart contract that needs to process
    up to a certain amount of `increment` and `setNumber` transactions
    depending on external conditions.
    Those conditions are external to the contract like
    - allow up to X transactions over a period of time Y
    - the amount of transactions X might vary over time
    - the time frame Y might vary
    - some addresses might be allowed to increment or
    - ... other complex conditions

    The key point is that those conditions:
    - are external to the contract
    - are too complicated or expensive for the EVM
    - change over time
    - are subject to parameters external to the contract

    So "something else" must make a decision on when to stop the
    contract and prevent it from processing other transactions
    until unpaused
 */
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
        require (Paused == false, "Contract Paused");
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
