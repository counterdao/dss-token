// SPDX-License-Identifier: AGPL-3.0-or-later

// token.sol -- I frobbed an inc and all I got was this lousy token

// Copyright (C) 2022 Horsefacts <horsefacts@terminally.online>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.15;

import {DSSLike} from "dss/dss.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Render, DataURI} from "./render.sol";

interface SumLike {
    function incs(address)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256);
}

interface CTRLike {
    function balanceOf(address) external view returns (uint256);
    function push(address, uint256) external;
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

    error WrongPayment(uint256 sent, uint256 cost);
    error Forbidden();
    error PullFailed();

    uint256 constant WAD        = 1    ether;
    uint256 constant BASE_PRICE = 0.01 ether;
    uint256 constant INCREASE   = 1.1  ether;

    DSSLike public immutable dss;
    DSSLike public immutable coins;
    DSSLike public immutable price;
    CTRLike public immutable ctr;

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

    constructor(address _dss, address _ctr) ERC721("CounterDAO", "++") {
        owner = msg.sender;

        dss = DSSLike(_dss);
        ctr = CTRLike(_ctr);

        coins = DSSLike(dss.build("coins", address(0)));
        price = DSSLike(dss.build("price", address(0)));

        coins.bless();
        price.bless();

        coins.use();
        price.use();
    }

    function mint() external payable {
        uint256 _cost = cost();
        if (msg.value != _cost) {
            revert WrongPayment(msg.value, _cost);
        }

        coins.hit();
        uint256 id = coins.see();

        DSSLike _count = DSSLike(dss.build(bytes32(id), address(0)));
        _count.bless();
        _count.use();

        _give(msg.sender, 100 * WAD);
        _safeMint(msg.sender, id);
    }

    function hike() external {
        if (price.see() < 100) {
            price.hit();
            _give(msg.sender, 10 * WAD);
        }
    }

    function drop() external {
        if (price.see() > 0) {
            price.dip();
            _give(msg.sender, 10 * WAD);
        }
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

    function pull(address dst) external auth {
        (bool ok,) = payable(dst).call{ value: address(this).balance }("");
        if (!ok) revert PullFailed();
    }

    function swap(address guy) external auth {
        owner = guy;
    }

    function see(uint256 tokenId) external view returns (uint256) {
        return count(tokenId).see();
    }

    function count(uint256 tokenId) public view returns (DSSLike) {
        return DSSLike(dss.scry(address(this), bytes32(tokenId), address(0)));
    }

    function inc(address guy) public view returns (Inc memory) {
        SumLike sum = SumLike(dss.sum());
        (uint256 net, uint256 tab, uint256 tax, uint256 num, uint256 hop) =
            sum.incs(guy);
        return Inc(guy, net, tab, tax, num, hop);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        exists(tokenId)
        returns (string memory)
    {
        return tokenJSON(tokenId).toDataURI("application/json");
    }

    function tokenJSON(uint256 tokenId)
        public
        view
        exists(tokenId)
        returns (string memory)
    {
        Inc memory countInc = inc(address(count(tokenId)));
        return Render.json(tokenId, tokenSVG(tokenId).toDataURI("image/svg+xml"), countInc);
    }

    function tokenSVG(uint256 tokenId)
        public
        view
        exists(tokenId)
        returns (string memory)
    {
        Inc memory countInc = inc(address(count(tokenId)));
        Inc memory priceInc = inc(address(price));
        return Render.image(tokenId, coins.see(), countInc, priceInc);
    }

    function _give(address dst, uint256 wad) internal {
        if (ctr.balanceOf(address(this)) >= wad) ctr.push(dst, wad);
    }
}
