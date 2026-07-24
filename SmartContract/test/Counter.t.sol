// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    // EOA and private keys used in tests
    address conio;      uint256 conio_key;

    function setUp() public {
        counter = new Counter(conio);

        // Addresses Setup
        (conio, conio_key) = makeAddrAndKey("conio4everybuddy");
    }

    function test_admin1() public view {
        console.log(conio);
        assertEq(counter.IsAdmin(conio), true, "E:admin1:1");
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.Number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        vm.prank(conio);
        counter.setNumber(x);
        assertEq(counter.Number(), x);
    }
}
