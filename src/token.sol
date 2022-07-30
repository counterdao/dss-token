// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DSSLike} from "dss/dss.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract DSSToken is ERC721 {
    using FixedPointMathLib for uint256;

    error InsufficientPayment(uint256 sent, uint256 cost);

    uint256 constant WAD        = 1    ether;
    uint256 constant BASE_PRICE = 0.01 ether;
    uint256 constant INCREASE   = 1.1  ether;

    DSSLike public immutable dss;
    DSSLike public immutable coins;
    DSSLike public immutable price;

    constructor(address _dss) ERC721("CounterDAO", "++") {
        dss = DSSLike(_dss);

        coins = DSSLike(dss.build(bytes32("coins"), msg.sender));
        price = DSSLike(dss.build(bytes32("price"), msg.sender));

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
        _safeMint(msg.sender, coins.see());
    }

    function hit() external {
        if (price.see() < 100) price.hit();
    }

    function dip() external {
        if (price.see() > 0) price.dip();
    }

    function cost() public view returns (uint256) {
        return cost(price.see());
    }

    function cost(uint256 count) public pure returns (uint256) {
        return BASE_PRICE.mulWadUp(INCREASE.rpow(count, WAD));
    }

    function tokenURI(uint256) public view virtual override returns (string memory) {
        return "";
    }
}
