// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DSSLike} from "dss/dss.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Render, DataURI} from "./render.sol";

interface SumLike {
    function incs(address) external view returns (uint256,uint256,uint256,uint256,uint256);
}

struct Inc {
    address guy;
    uint256 net;
    uint256 tab;
    uint256 tax;
    uint256 num;
    uint256 hop;
}

contract DSSToken is ERC721 {
    using FixedPointMathLib for uint256;
    using DataURI for string;

    error InsufficientPayment(uint256 sent, uint256 cost);
    error Forbidden();

    uint256 constant WAD        = 1    ether;
    uint256 constant BASE_PRICE = 0.01 ether;
    uint256 constant INCREASE   = 1.1  ether;

    DSSLike public immutable dss;
    DSSLike public immutable coins;
    DSSLike public immutable price;

    address public owner;

    modifier auth() {
        if (msg.sender != owner) revert Forbidden();
        _;
    }

    modifier owns(uint256 tokenId) {
        if (msg.sender != ownerOf(tokenId)) revert Forbidden();
        _;
    }

    modifier exists(uint256 tokenId) {
        ownerOf(tokenId);
        _;
    }

    constructor(address _dss) ERC721("CounterDAO", "++") {
        owner = msg.sender;

        dss = DSSLike(_dss);

        coins = DSSLike(dss.build(bytes32("coins"), address(0)));
        price = DSSLike(dss.build(bytes32("price"), address(0)));

        coins.bless();
        price.bless();

        coins.use();
        price.use();
    }

    function mint() external payable {
        uint256 _cost = cost();
        if (msg.value != _cost) {
            revert InsufficientPayment(msg.value, _cost);
        }

        coins.hit();
        uint256 id = coins.see();

        DSSLike _count = DSSLike(dss.build(bytes32(id), address(0)));
        _count.bless();
        _count.use();

        _safeMint(msg.sender, id);
    }

    function hike() external {
        if (price.see() < 100) price.hit();
    }

    function drop() external {
        if (price.see() > 0) price.dip();
    }

    function cost() public view returns (uint256) {
        return cost(price.see());
    }

    function cost(uint256 net) public pure returns (uint256) {
        return BASE_PRICE.mulWadUp(INCREASE.rpow(net, WAD));
    }

    function hit(uint256 tokenId) external owns(tokenId) {
        count(tokenId).hit();
    }

    function dip(uint256 tokenId) external owns(tokenId) {
        count(tokenId).dip();
    }

    function see(uint256 tokenId) external view returns (uint256) {
        return count(tokenId).see();
    }

    function count(uint256 tokenId) public view exists(tokenId) returns (DSSLike) {
        return DSSLike(dss.scry(address(this), bytes32(tokenId), address(0)));
    }

    function inc(address guy) public view returns (Inc memory) {
        SumLike sum = SumLike(dss.sum());
        (uint256 net, uint256 tab, uint256 tax, uint256 num, uint256 hop) = sum.incs(guy);
        return Inc({
            guy: guy,
            net: net,
            tab: tab,
            tax: tax,
            num: num,
            hop: hop
        });
    }

    function tokenURI(uint256 tokenId) public view virtual override exists(tokenId) returns (string memory) {
        return tokenJSON(tokenId).toDataURI("application/json");
    }

    function tokenJSON(uint256 tokenId)
        public
        view
        exists(tokenId)
        returns (string memory)
    {
        return string.concat(
            '{"name": "CounterDAO", "description": "I frobbed an Inc and all I got was this lousy token", "image": "',
            tokenSVG(tokenId).toDataURI("image/svg+xml"),
            '"}'
        );
    }

    function tokenSVG(uint256 tokenId)
        public
        view
        exists(tokenId)
        returns (string memory)
    {
        Inc memory countInc = inc(address(count(tokenId)));
        Inc memory priceInc = inc(address(price));
        return Render.render(tokenId, coins.see(), countInc, priceInc);
    }

}
