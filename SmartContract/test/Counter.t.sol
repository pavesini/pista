// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    // EOA and private keys used in tests
    address conio;      uint256 conio_key;
    address sui;        uint256 sui_key;
    address pista;      uint256 pista_key;

    /****************************************************************
        SETUP
    ****************************************************************/

    function setUp() public {
        // Addresses Setup
        (conio, conio_key) = makeAddrAndKey("conio4everybuddy");
        (sui, sui_key) = makeAddrAndKey("sui4tee");
        (pista, pista_key) = makeAddrAndKey("pistacchiosa");

        // Deeploy Contract
        counter = new Counter(conio);
    }

    /****************************************************************
        BASIC FUNCTIONS
    ****************************************************************/

    // Test conio is an admin
    function test_admin1() public view {
        console.log(conio);
        assertEq(counter.IsAdmin(conio), true, "E:admin1:1");
    }

    // Test Authorize
    function test_authorize() public {
        vm.prank(conio);
        counter.authorize(sui, true);
        assertEq(counter.IsAdmin(sui), true, "E:auth:1");

        vm.prank(conio);
        counter.authorize(sui, false);
        assertEq(counter.IsAdmin(sui), false, "E:auth:2");
    }

    // Test increment function
    function test_increment() public {
        uint256 N = counter.Number();
        counter.increment();
        assertEq(counter.Number(), N+1);
    }

    // Test setNumber function
    function testFuzz_setNumber(uint256 x) public {
        vm.prank(conio);
        counter.setNumber(x);
        assertEq(counter.Number(), x);
    }

    // Test auth+setNumber
    function test_auth_and_set() public {
        vm.prank(conio);
        counter.authorize(sui, true);
        assertEq(counter.IsAdmin(sui), true, "E:auth:1");

        vm.prank(sui);
        counter.setNumber(5);
        assertEq(counter.Number(), 5);
    }

    /****************************************************************
        PAUSE FUNCTIONS
    ****************************************************************/

    // Test pausing contract
    function test_pause() public {
        assertEq(counter.Paused(), false, "E:pause:1");
        vm.prank(conio);
        counter.pause(true);
        assertEq(counter.Paused(), true, "E:pause:1");
    }

    // Thes other authorized address can pause contract
    function test_auth_and_pause() public {
        vm.prank(conio);
        counter.authorize(sui, true);
        assertEq(counter.IsAdmin(sui), true, "E:auth:1");

        assertEq(counter.Paused(), false, "E:pause:1");
        vm.prank(sui);
        counter.pause(true);
        assertEq(counter.Paused(), true, "E:pause:1");
    }

    // Test EOA cannot call `increment` during pause
    // At the end of the day this is the real test...
    function test_pause_and_inc() public {
        test_pause();

        vm.expectRevert(bytes("Contract Paused"));
        counter.increment();
    }


    function test_unpause_and_inc() public {
        test_pause();

        vm.prank(conio);
        counter.pause(false);
        assertEq(counter.Paused(), false, "E:pause:1");

        test_increment();
    }
}
