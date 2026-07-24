// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterScript is Script {
    Counter public counter;

    // EOA and private keys used in tests
    address conio;      uint256 conio_key;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        // Addresses Setup
        (conio, conio_key) = makeAddrAndKey("conio4everybuddy");
        counter = new Counter(conio);

        vm.stopBroadcast();
    }
}
