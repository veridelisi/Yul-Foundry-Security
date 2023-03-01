// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StorageContract {

     uint256 a = 9; // Slot 0
     uint256 b = 8; // Slot 1
     uint256 c = 7; // Slot 2
     uint256 d = 6; // Slot 3

function readStorageSlot0(uint yournumber) public view returns (bytes32 result) {   

assembly {
            result := sload(yournumber)
        }   
         
         }   
         
    }
