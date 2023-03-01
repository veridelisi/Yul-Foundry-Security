// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StorageContract {

     uint64 a = 9; // Slot 0
     uint64 b = 8; // Slot 0
     uint64 c = 7; // Slot 0
     uint64 d = 6; // Slot 0

function readStorageSlot0(uint yournumber) public view returns (bytes32 result) {   

assembly {
            result := sload(yournumber)
        }   
         
         }   

 function getSlotNumbers() public pure returns(uint64 slotA, uint64 slotB, uint64 slotC, uint64 slotD) {
        assembly {
            slotA := a.slot
            slotB := b.slot
            slotC := c.slot
            slotD := d.slot
    
        }
    }

    function getVariableOffsets() public view returns(uint64 offsetA, uint64 offsetB, uint64 offsetC, uint64 offsetD, bytes32 loc) {
        assembly {
            offsetA := a.offset
            offsetB := b.offset
            offsetC := c.offset
            offsetD := d.offset
            loc := sload(0)
    
        }
    }
         
    }
