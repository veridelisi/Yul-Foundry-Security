

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

### 26. Unexpected Ether and this.balance:

A `contract` can **receive Ether** via:
- payable functions
- selfdestruct()
- coinbase transaction
- pre-sent before creation

**WARNING**: Contract logic depending on `this.balance` can therefore be manipulated.

**BEST PRACTICE**: Do not make assumptions regarding `this.balance` for contract logic.

see [here](https://github.com/sigp/solidity-security-blog#3-unexpected-ether-1)
see [here](https://swcregistry.io/docs/SWC-132)

### 29. Locked Ether:

**WARNING**: Contracts that accept Ether via `payable` functions but without withdrawal mechanisms will lock up that Ether.

**BEST PRACTICE**: Remove `payable` attributes, or add a withdraw function.

see [here](https://github.com/crytic/slither/wiki/Detector-Documentation#contracts-that-lock-ether)

### 30. Dangerous usage of tx.origin:

**WARNING**: Use of `tx.origin` for authorization may be abused by a Man In The Middle (MITM) malicious contract forwarding calls from the legitimate user who interacts with it.

**BEST PRACTICE**: Do not use `tx.origin` for authorization. Use `msg.sender` instead.

see [here](https://swcregistry.io/docs/SWC-115)

### 31. Contract check:

**WARNING**: Checking if a call was made from a contract account is typically done using `extcodesize > 0` check, which may be circumvented by a contract during construction when it does not have source code available.

**ALTERNATIVE**: Checking if `tx.origin == msg.sender` is another option to verify if an account is a contract.

**CAVEAT**: Both methods have implications that need to be considered.

see [here](https://consensys.net/blog/blockchain-development/solidity-best-practices-for-smart-contract-security/)

### 46. Unindexed event parameters:

**WARNING**: Parameters of certain events are expected to be `indexed` (e.g. ERC20 Transfer/Approval events) so that they’re included in the block’s bloom filter for faster access.

**WARNING**: Failure to mark event parameters as `indexed`, when expected, might confuse off-chain tooling looking for such events.

### 49. Missing zero address validation:

**WARNING**: Setters of `address` type parameters should include a *zero-address check* otherwise contract functionality may become **inaccessible** or **tokens burnt forever**.

**BEST PRACTICE**: Validate that all address inputs are not zero-address 
**require(shareErc20Temp != address(0), "shareErc20Temp invalid");**


see [here](https://github.com/crytic/slither/wiki/Detector-Documentation#missing-zero-address-validation)
