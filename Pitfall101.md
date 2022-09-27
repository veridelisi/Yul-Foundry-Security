#### [26. Unexpected Ether](#ether)
 * [The Vulnerability](#ether-vuln)
 * [Preventative Techniques](#ether-prev)
 * [Real-World Examples: Unknown](#ether-example)


<h2 id="ether"><span id="SP-3">26. Unexpected Ether</span></h2>

Typically when ether is sent to a contract, it must execute either the fallback function, or another function described in the contract. There are two exceptions to this, where ether can exist in a contract without having executed any code. Contracts which rely on code execution for every ether sent to the contract can be vulnerable to attacks where ether is forcibly sent to a contract.

For further reading on this, see [How to Secure Your Smart Contracts: 6](https://medium.com/loom-network/how-to-secure-your-smart-contracts-6-solidity-vulnerabilities-and-how-to-avoid-them-part-2-730db0aa4834) and [ Solidity security patterns - forcing ether to a contract ](http://danielszego.blogspot.com.au/2018/03/solidity-security-patterns-forcing.html).

<h3 id="ether-vuln">The Vulnerability</h3>

A common defensive programming technique that is useful in enforcing correct state transitions or validating operations is *invariant-checking*. This technique involves defining a set of invariants (metrics or parameters that should not change) and checking these invariants remain unchanged after a single (or many) operation(s). This is typically good design, provided the invariants being checked are in fact invariants. One example of an invariant is the `totalSupply` of a fixed issuance [ERC20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md) token. As no functions should modify this invariant, one could add a check to the `transfer()` function that ensures the `totalSupply` remains unmodified to ensure the function is working as expected.

In particular, there is one apparent *invariant*, that may be tempting to use
but can in fact be manipulated by external users (regardless of the rules put
in place in the smart contract) .This is the current ether stored in the
contract. Often when developers first learn Solidity they have the
misconception that a contract can only accept or obtain ether via payable
functions. This misconception can lead to  contracts that have false
assumptions about the ether balance within them which can lead to a range of
vulnerabilities. The smoking gun for this vulnerability is the (incorrect) use
of `this.balance`. As we will see, incorrect uses of `this.balance` can lead to
serious vulnerabilities of this type.

There are two ways in which ether can (forcibly) be sent to a contract without using a `payable` function or executing any code on the contract. These are listed below.

#### Self Destruct / Suicide

Any contract is able to implement the [`selfdestruct(address)`](http://solidity.readthedocs.io/en/latest/introduction-to-smart-contracts.html#self-destruct) function, which removes all bytecode from the contract address and sends all ether stored there to the parameter-specified address. If this specified address is also a contract, no functions (including the fallback) get called. Therefore, the `selfdestruct()` function can be used to forcibly send ether to any contract regardless of any code that may exist in the contract. This is inclusive of contracts without any payable functions. This means, any attacker can create a contract with a `selfdestruct()` function, send ether to it, call `selfdestruct(target)` and force ether to be sent to a `target` contract. Martin Swende has an excellent [blog post](http://martin.swende.se/blog/Ethereum_quirks_and_vulns.html) describing some quirks of the self-destruct opcode (Quirk #2) along with a description of how client nodes were checking incorrect invariants which could have lead to a rather catastrophic nuking of clients.

#### Pre-sent Ether

The second way a contract can obtain ether without using a `selfdestruct()` function or calling any payable functions is to pre-load the contract address with ether. Contract addresses are deterministic, in fact the address is calculated from the keccak256 (sometimes synonomous with SHA3) hash of the address creating the contract and the transaction nonce which creates the contract. Specifically, it is of the form: `address = sha3(rlp.encode([account_address,transaction_nonce]))` (see [Keyless Ether](#keyless-eth) for some fun use cases of this). This means, anyone can calculate what a contract address will be before it is created and thus send ether to that address. When the contract does get created it will have a non-zero ether balance.

Let's explore some pitfalls that can arise given the above knowledge.

Consider the overly-simple contract,

EtherGame.sol:
```solidity
contract EtherGame {

    uint public payoutMileStone1 = 3 ether;
    uint public mileStone1Reward = 2 ether;
    uint public payoutMileStone2 = 5 ether;
    uint public mileStone2Reward = 3 ether;
    uint public finalMileStone = 10 ether;
    uint public finalReward = 5 ether;

    mapping(address => uint) redeemableEther;
    // users pay 0.5 ether. At specific milestones, credit their accounts
    function play() public payable {
        require(msg.value == 0.5 ether); // each play is 0.5 ether
        uint currentBalance = this.balance + msg.value;
        // ensure no players after the game as finished
        require(currentBalance <= finalMileStone);
        // if at a milestone credit the players account
        if (currentBalance == payoutMileStone1) {
            redeemableEther[msg.sender] += mileStone1Reward;
        }
        else if (currentBalance == payoutMileStone2) {
            redeemableEther[msg.sender] += mileStone2Reward;
        }
        else if (currentBalance == finalMileStone ) {
            redeemableEther[msg.sender] += finalReward;
        }
        return;
    }

    function claimReward() public {
        // ensure the game is complete
        require(this.balance == finalMileStone);
        // ensure there is a reward to give
        require(redeemableEther[msg.sender] > 0);
        uint transferValue = redeemableEther[msg.sender];
        redeemableEther[msg.sender] = 0;
        msg.sender.transfer(transferValue);
    }
 }
```

This contract represents a simple game (which would naturally invoke [race-conditions](#race-conditions)) whereby players send `0.5 ether` quanta to the contract in hope to be the player that reaches one of three milestones first. Milestone's are denominated in ether. The first to reach the milestone may claim a portion of the ether when the game has ended. The game ends when the final milestone (`10 ether`) is reached and users can claim their rewards.

The issues with the `EtherGame` contract come from the poor use of `this.balance` in both lines \[14\] (and by association \[16\]) and \[32\]. A mischievous attacker could forcibly send a small amount of ether, let's say `0.1 ether` via the `selfdestruct()` function (discussed above) to prevent any future players from reaching a milestone. As all legitimate players can only send `0.5 ether` increments, `this.balance` would no longer be half integer numbers, as it would also have the `0.1 ether` contribution. This prevents all the if conditions on lines \[18\], \[21\] and \[24\] from being true.

Even worse, a vengeful attacker who missed a milestone, could forcibly send `10 ether` (or an equivalent amount of ether that pushes the contract's balance above the `finalMileStone`) which would lock all rewards in the contract forever. This is because the `claimReward()` function will always revert, due to the require on line \[32\] (i.e. `this.balance` is greater than `finalMileStone`).

<h3 id="ether-prevention">Preventative Techniques</h3>

This vulnerability typically arises from the misuse of `this.balance`. Contract logic, when possible, should avoid being dependent on exact values of the balance of the contract because it can be artificially manipulated. If applying logic based on `this.balance`, ensure to account for unexpected balances.

If exact values of deposited ether are required, a self-defined variable should be used that gets incremented in payable functions, to safely track the deposited ether. This variable will not be influenced by the forced ether sent via a `selfdestruct()` call.

With this in mind, a corrected version of the `EtherGame` contract could look like:
```solidity
contract EtherGame {

    uint public payoutMileStone1 = 3 ether;
    uint public mileStone1Reward = 2 ether;
    uint public payoutMileStone2 = 5 ether;
    uint public mileStone2Reward = 3 ether;
    uint public finalMileStone = 10 ether;
    uint public finalReward = 5 ether;
    uint public depositedWei;

    mapping (address => uint) redeemableEther;

    function play() public payable {
        require(msg.value == 0.5 ether);
        uint currentBalance = depositedWei + msg.value;
        // ensure no players after the game as finished
        require(currentBalance <= finalMileStone);
        if (currentBalance == payoutMileStone1) {
            redeemableEther[msg.sender] += mileStone1Reward;
        }
        else if (currentBalance == payoutMileStone2) {
            redeemableEther[msg.sender] += mileStone2Reward;
        }
        else if (currentBalance == finalMileStone ) {
            redeemableEther[msg.sender] += finalReward;
        }
        depositedWei += msg.value;
        return;
    }

    function claimReward() public {
        // ensure the game is complete
        require(depositedWei == finalMileStone);
        // ensure there is a reward to give
        require(redeemableEther[msg.sender] > 0);
        uint transferValue = redeemableEther[msg.sender];
        redeemableEther[msg.sender] = 0;
        msg.sender.transfer(transferValue);
    }
 }
```
Here, we have just created a new variable, `depositedWei` which keeps track of the known ether deposited, and it is this variable to which we perform our requirements and tests. Notice, that we no longer have any reference to `this.balance`.

### 6. Unprotected call to selfdestruct:

**WARNING**: A user/attacker can mistakenly/intentionally kill the contract if `selfdestruct` is not protected, transferring its balance elsewhere.

**BEST PRACTICE**: Protect access to `selfdestruct` functions or remove them.

> The parity mutli-sig smart contract wallet was killed when an attacker gained unauthorized ownership and called `kill()` function

```solidity
// kills the contract sending everything to `_to`.
function kill(address _to) onlymanyowners(sha3(msg.data)) external {
  suicide(_to);
}
```

see [here](https://swcregistry.io/docs/SWC-106)

### 7. Modifier side-effects:

**WARNING**: External calls in modifiers will typically **violate** the *checks-effects-interactions* pattern.

- These side-effects may go unnoticed by developers/auditors because the modifier code is typically far from the function implementation.

**BEST PRACTICE**: Modifiers should have no side-effects. They should only *implement checks* and *not make state changes*.

> The modifier `isEligible` of the contracts below makes `Election` susceptible to a reentrancy attack via an external call to `registry`:

```solidity
contract Registry {
    address owner;

    function isVoter(address _addr) external returns(bool) {
        // Code
    }
}

contract Election {
    Registry registry;

    modifier isEligible(address _addr) {
        require(registry.isVoter(_addr));
        _;
    }

    function vote() isEligible(msg.sender) public {
        // Code
    }
}
```

see [here](https://consensys.net/blog/blockchain-development/solidity-best-practices-for-smart-contract-security/)

### 8. Incorrect modifier:

**WARNING**: If a `modifier` does not execute `_` or `revert`, the function using that modifier will *return the default value* causing unexpected behavior.

**BEST PRACTICE**: All paths in a modifier should execute `_` or `revert`

> If the condition in `myModif` is false, the execution of `get()` returns 0. It is better to revert:

Solution: All paths in a modifier should execute _ or revert

```
modifier goodModif(){

if(..)

{ _; }

else

{ revert(“ERROR”);

// or _; }

}

function get() goodModif returns(address){}
```

### 10. Void constructor:

**WARNING**: Calls to *unimplemented* base contract constructors leads to misplaced assumptions.

**BEST PRACTICE**: Check if the *constructor is implemented*, or remove call if not.

> The constructor of `contract B` calls the unimplemented constructor of `A`

```solidity
contract A{}
contract B is A{
    constructor() public A(){}
}
```

see [here](https://github.com/crytic/slither/wiki/Detector-Documentation#void-constructor)

### 12. Controlled delegatecall:

`delegatecall()` or `callcode()` to an `address` *controlled by the user* allows **execution of malicious contracts** in the context of the caller’s state.

**BEST PRACTICE**: Ensure *trusted destination* `address` for `delegatecall()` and `callcode()`.

> This proxy pattern is not secure if `callee` is Untrusted

```solidity

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// NOTE: Deploy this contract first
contract B {
    // NOTE: storage layout must be the same as contract A
    uint public num;
    address public sender;
    uint public value;

 function setVars(uint _num) public payable {
      num = _num;
      sender = msg.sender;
      value = msg.value;
    }
}

contract A {
    uint public num;
    address public sender;
    uint public value;

    function setVars(address _contract, uint _num) public payable {
        // A's storage is set, B is not modified.
       (bool success, bytes memory data) = _contract.delegatecall(
        abi.encodeWithSignature("setVars(uint256)", _num)
        );
    }
}
```

When someone will cal function setVars from contract A, delegatecall will be called. Inside delegatecall we see that it will call function setVars(uint256) from contract with address equal to _contract. The value which will be sent to this function is equal to _num. Thanks delegatecall setVars function from contract B will start execute. But here is the core of it. If this function change the value of any variable, it will be change not in contract B, but in contract A. How function setVars from contract B will know which variable change?  In contract B function setVars set num (variable in slot number 0) to _num, sender (variable in slot number 1) to msg.sender and value (variable in slot number 2) to msg.value. **When we call this function by delegatecall we set the variable in slot number 0 in contract A to _num, the variable in slot number 1 in contract A to msg.sender and so on. Therefore, it is very important to have the same storage layout in both contract.**

see [here](https://solidity-by-example.org/delegatecall/)

### 13. Reentrancy vulnerabilities:

*Untrusted external contract calls* could *call back* to the calling contract, leading to unexpected results such as *multiple withdrawals* or *out-of-order events*.

**BEST PRACTICE**: Use *check-effects-interactions* pattern or *reentrancy guards* or *Ensure all state changes happen before calling external contracts*


```solidity


  function withdrawBAD(uint amount) public{
    // THIS CODE IS UNSECURE: REENTRANCY
    // check-interact-effect pattern UNimplemented
    if (credit[msg.sender]>= amount) {
      require(msg.sender.call.value(amount)());
      credit[msg.sender]-=amount;
    }
  }  
  function withdrawTRUE(uint amount) public{
    // THIS CODE IS SECURE: REENTRANCY
    // check-interact-effect pattern implemented
    if (credit[msg.sender]>= amount) {
      credit[msg.sender]-=amount;
      require(msg.sender.call.value(amount)());
    
    }
  }  
 
```

see [here](https://swcregistry.io/docs/SWC-107)

### 15. Avoid transfer()/send() as reentrancy mitigations:

`transfer()` and `send()` have been previously recommended as a security best-practice to prevent reentrancy attacks because they only *forward 2300 gas*.

**WARNING**: the *gas repricing* of opcodes in certain hard forks *may break deployed contracts* depending on the 2300 gas stipend.

**BEST PRACTICE**: Use `call()` to send Ether, without hardcoded gas limits. Ensure *reentrancy protection* via *checks-effects-interactions pattern* or *reentrancy guards*.

> One should avoid hardcoded gas limits in calls, because hard forks may change opcode gas costs and break deployed contracts:

```solidity
contract Vulnerable {
    function withdraw(uint256 amount) external {
        // This forwards 2300 gas, which may not be enough if the recipient
        // is a contract and gas costs change.
        msg.sender.transfer(amount);
    }
}

contract Fixed {
    function withdraw(uint256 amount) external {
        // This forwards all available gas. Be sure to check the return value!
        (bool success, ) = msg.sender.call.value(amount)("");
        require(success, "Transfer failed.");
    }
}
```

see [here](https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/)
see [here](https://swcregistry.io/docs/SWC-134)

### 22. ERC20 approve() race condition:

**BEST PRACTICE**: Use `safeIncreaseAllowance()` and `safeDecreaseAllowance()` from OpenZeppelin’s `SafeERC20` implementation to *prevent race conditions* from manipulating the allowance amounts.

```solidity
function safeIncreaseAllowance(
    IERC20 token,
    address spender,
    uint256 value
) internal {
    uint256 newAllowance = token.allowance(address(this), spender) + value;
    _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
}
```

see [here](https://swcregistry.io/docs/SWC-114)

