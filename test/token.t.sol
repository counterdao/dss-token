// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {DSSToken} from "../src/token.sol";

import {DSS} from "dss/dss.sol";
import {Sum} from "dss/sum.sol";
import {Use} from "dss/use.sol";
import {Hitter} from "dss/hit.sol";
import {Dipper} from "dss/dip.sol";
import {Nil} from "dss/nil.sol";
import {Spy} from "dss/spy.sol";

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

contract DSSTokenTest is Test, ERC721TokenReceiver {
    DSSToken internal token;

    Sum internal sum;
    Use internal use;
    Nil internal nil;
    Spy internal spy;

    Hitter internal hitter;
    Dipper internal dipper;

    DSS internal dss;

    address me = address(this);

    function setUp() public {
        sum = new Sum();
        use = new Use(address(sum));
        nil = new Nil(address(sum));
        spy = new Spy(address(sum));

        hitter = new Hitter(address(sum));
        dipper = new Dipper(address(sum));

        dss = new DSS(
            address(sum),
            address(use),
            address(spy),
            address(hitter),
            address(dipper),
            address(nil)
        );

        token = new DSSToken(address(dss));
    }

    function test_token_has_name() public {
        assertEq(token.name(), "CounterDAO");
    }

    function test_token_has_symbol() public {
        assertEq(token.symbol(), "++");
    }

    function test_token_has_dss() public {
        assertEq(address(token.dss()), address(dss));
    }

    function test_coins_initialized_to_zero() public {
        (uint256 coins,,,,) = sum.incs(address(token.coins()));
        assertEq(coins, 0);
    }

    function test_price_initialized_to_zero() public {
        (uint256 price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);
    }

    function test_hit_increases_price_counter() public {
        (uint256 price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.hit();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 1);
    }

    function test_dip_decreases_price_counter() public {
        (uint256 price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.hit();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 1);

        token.dip();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);
    }

    function test_mint_assigns_token() public {
        token.mint{ value: 0.01 ether }();
        assertEq(token.balanceOf(me), 1);
        assertEq(token.ownerOf(1), me);
    }

    function test_mint_reverts_insufficient_payment() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DSSToken.InsufficientPayment.selector,
                0,
                0.01 ether
            )
        );
        token.mint{ value: 0 }();
    }

    function test_cost_function() public {
        assertEq(token.cost(), 0.01 ether);

        token.hit();
        assertEq(token.cost(), 0.011 ether);

        token.hit();
        assertEq(token.cost(), 0.0121 ether);
    }

    function test_cost_function_by_count() public {
        assertEq(token.cost(0),      0.01 ether);
        assertEq(token.cost(10),     0.025937424601000000 ether);
        assertEq(token.cost(100),    137.806123398222701833 ether);
    }

    function test_hit_does_not_increment_above_100() public {
        uint256 price;
        for (uint256 i; i < 100; i++) {
            token.hit();
            (price,,,,) = sum.incs(address(token.price()));
            assertEq(price, i + 1);
        }

        token.hit();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);

        token.hit();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);

        token.hit();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);
    }

    function test_dip_does_not_revert_below_zero() public {
        uint256 price;

        token.dip();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.dip();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);
    }
}
