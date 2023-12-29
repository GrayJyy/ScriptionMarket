// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

contract SigUtils is Test {
    bytes32 internal DOMAIN_SEPARATOR;
    uint256 public MOCK_ORDER_PRICE_10ether = 10 ether;
    uint256 public MOCK_ORDER_AMOUNT_100 = 100;
    string public MOCK_TICK = "MSCMOCK";

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    /**
     * keccak256("Listing(address maker,uint256 time,uint256 amount,uint256 price,string tick)")
     */
    bytes32 public constant Listing_TYPEHASH = 0xb1ed21ffa654ebcf1742ed8c8d6513ae204dbf3d2c1e5dc44b073e7478a68c84;

    struct Listing {
        address maker;
        uint256 time;
        uint256 amount;
        uint256 price;
        string tick;
    }

    // computes the hash of a permit
    function getStructHash(Listing memory listing) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(Listing_TYPEHASH, listing.maker, listing.time, listing.amount, listing.price, listing.tick)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Listing memory listing) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(listing)));
    }

    function mockSignature(address seller, uint256 sellerKey) public view returns (bytes memory signature) {
        Listing memory listing = Listing({
            maker: seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        bytes32 digest = getTypedDataHash(listing);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
