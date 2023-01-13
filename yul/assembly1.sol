// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract C {
    struct S {
        uint16 a;  // 2 bytes,  2 bytes total
        uint24 b;  // 3 bytes,  5 bytes total
        address c; // 20 bytes, 25 bytes total + end of slot 0x01
        address d; // 20 bytes, slot 0x02
    }

    // I've noted the storage slots each state is located at.
    // A single slot is 32 bytes :)
    uint256 boring=9;              // 0x00
    S s_struct;                  // 0x01, 0x02
    S[] s_array;                 // 0x03
    mapping(uint256 => S) s_map; // 0x04

    constructor() {
        s_struct = S({
            a: 10,
            b: 20,
            c: 0x047b37Ef4d76C2366F795Fb557e3c15E0607b7d8,
            d: 0x047b37Ef4d76C2366F795Fb557e3c15E0607b7d8

        });
    }
function getXwithYul() public view returns (uint256) {
        uint num;
        assembly {
            num := sload(0x00)
            //num := sload(boring.slot)
        }
        return num;
    }
    
    function setXwithYul(uint256 _x) public  {
        assembly {
            sstore(boring.slot, _x)
        }
    }
    
    function view_b() external view returns (uint24) {
    assembly {
        // before: 00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014 000a
        //                                                                         ^
        // after:  0000 00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014
        //          ^
        let v := shr(0x10, sload(0x01))

        // If both characters aren't 0, keep the bit (1). Otherwise, set to 0.
        // mask:   0000000000000000000000000000000000000000000000000000000000 FFFFFF
        // v:      000000000000000000047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014
        // result: 0000000000000000000000000000000000000000000000000000000000 000014
        v := and(0xffffff, v)

        // Store in memory bc return uses memory.
        mstore(0x40, v)

        // Return reads left to right.
        // Since our value is far right we can just return 32 bytes from the 64th byte in memory.
        return(0x40, 0x20)
    }
}
    
   //          unused bytes                     c                        b    a
// before: 00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014 000a
//          unused bytes                     c                        b    a
// after:  00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 0001F4 000a
function set_b(uint24 b) external {
    assembly {
        // Removing the `uint16` from the right.
        // before: 00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014 000a
        //                                                                         ^
        // after:  0000 00000000000000 047b37ef4d76c2366f795fb557e3c15e0607b7d8 000014
        //          ^
        let new_v := shr(0x10, sload(0x01))

        // Create our mask.
        new_v := and(0xffffff, new_v)

        // Input our value into the mask.
        new_v := xor(b, new_v)

        // Add back the removed `a` value bits.
        new_v := shl(0x10, new_v)

        // Replace original 32 bytes' `000014` with `0001F4`.
        new_v := xor(new_v, sload(0x01))

        // Store our new value.
        sstore(0x00, new_v)
    }
}
}
