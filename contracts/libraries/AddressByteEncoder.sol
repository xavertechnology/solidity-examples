// small Library for address and bytes encoding and decoding
library AddressByteEncoder{
    function packedBytesToAddr(bytes calldata _b) public pure returns (address){
        address addr;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, sub(_b.offset, 2 ), add(_b.length, 2))
            addr := mload(sub(ptr,10))
        }
        return addr;
    }

    function addrToPackedBytes(address _a) public pure returns (bytes memory){
        bytes memory data = abi.encodePacked(_a);
        return data;
    }
}