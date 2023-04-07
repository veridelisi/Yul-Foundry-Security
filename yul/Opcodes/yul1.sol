// SPDX-License-Identifier: MIT
// compiler version must be greater than or equal to 0.8.17 and less than 0.9.0
// https://github.com/Perelyn-sama/yul_by_example/blob/main/src/HelloWorld.sol

pragma solidity 0.8.19;


contract HelloWorld {
    function Greet() external pure returns (string memory) {
        assembly {
            
            let greet := "VivaMexicoCabrones"
            // Store the string offset in mem[0x00].
            // This is an ABI requirement, 0x20 must be stored at any chosen offset.
            mstore(0x00, 0x20)
            // Store the length of the string in mem[offset + 32 bytes].
            mstore(0x20, 0x12) // 0x0c = 12, length of "Hello World!".
            // Store the string in mem[offset + 64 bytes].
            mstore(0x40, greet)
            // Returns the bytes from mem[offset to offset+size]
            return(0x00, 0x60)
        }
    }
}
