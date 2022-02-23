pragma solidity ^0.8.4;

import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./libraries/AddressByteEncoder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

// deploy this contract to 2+ chains for testing.
//
// sendTokens() function works like this:
//  1. burn local tokens (logic in sendTokens)
//  2. send a LayerZero message to the destination MultiChainToken address on another chain
//  3. mint tokens on destination (logic in lzReceive)
contract MultiChainToken is ERC20, ILayerZeroReceiver, Ownable {

    ILayerZeroEndpoint public endpoint;
    address private MultiChainTokenAddressBSC;
    address private MultiChainTokenAddressEthereum;

    // constructor mints tokens to the deployer
    constructor(string memory name_, string memory symbol_, address _layerZeroEndpoint) ERC20(name_, symbol_){
        endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);
        _mint(msg.sender, 100 * 10**18); // mint the deployer 100 tokens.
    }

    function setExternalMultiChainAddresses(
        address _MultiChainTokenAddressEthereum,
        address _MultiChainTokenAddressBSC
    ) public onlyOwner {
        MultiChainTokenAddressEthereum = _MultiChainTokenAddressEthereum;
        MultiChainTokenAddressBSC = _MultiChainTokenAddressBSC;
        renounceOwnership();
    }

    function sendTokens(
        uint16 _chainId,                            // send tokens to this chainId
        address _dstMultiChainTokenAddr,     // destination address of MultiChainToken
        uint _qty                                   // how many tokens to send
    )
    public
    payable 
    {
        bytes memory adr = AddressByteEncoder.addrToPackedBytes(_dstMultiChainTokenAddr);
        _sendTokens(_chainId, adr, _qty);
    }

    // send tokens to another chain.
    // this function sends the tokens from your address to the same address on the destination.
    function _sendTokens(
        uint16 _chainId,                            // send tokens to this chainId
        bytes memory _dstMultiChainTokenAddr,     // destination address of MultiChainToken
        uint _qty                                   // how many tokens to send
    )
    private
    {
        // burn the tokens locally.
        // tokens will be minted on the destination.
        require(
            allowance(msg.sender, address(this)) >= _qty,
            "You need to approve the contract to send your tokens!"
        );

        // and burn the local tokens *poof*
        _burn(msg.sender, _qty);

        // abi.encode() the payload with the values to send
        bytes memory payload = abi.encode(msg.sender, _qty);

        // send LayerZero message
        endpoint.send{value:msg.value}(
            _chainId,                       // destination chainId
            _dstMultiChainTokenAddr,        // destination address of MultiChainToken
            payload,                        // abi.encode()'ed bytes
            payable(msg.sender),            // refund address (LayerZero will refund any superflous gas back to caller of send()
            address(0x0),                   // 'zroPaymentAddress' unused for this mock/example
            bytes("")                       // 'txParameters' unused for this mock/example
        );
    }

    // receive the bytes payload from the source chain via LayerZero
    // _fromAddress is the source MultiChainToken address
    function lzReceive(uint16 _srcChainId, bytes memory _fromAddress, uint64 _nonce, bytes memory _payload) override external{
        require(msg.sender == address(endpoint)); // boilerplate! lzReceive must be called by the endpoint for security
        address fromAddress = AddressByteEncoder.packedBytesToAddr(_fromAddress);
        require(fromAddress == MultiChainTokenAddressBSC || fromAddress == MultiChainTokenAddressEthereum, "Only token contract a and b can send");

        // decode
        (address toAddr, uint qty) = abi.decode(_payload, (address, uint));

        // mint the tokens back into existence, to the toAddr from the message payload
        _mint(toAddr, qty);
    }

}
