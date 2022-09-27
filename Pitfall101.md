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
