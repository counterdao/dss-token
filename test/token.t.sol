// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Test.sol";

import {DSSToken, Inc} from "../src/token.sol";

import {DSS} from "dss/dss.sol";
import {Sum} from "dss/sum.sol";
import {Use} from "dss/use.sol";
import {Hitter} from "dss/hit.sol";
import {Dipper} from "dss/dip.sol";
import {Nil} from "dss/nil.sol";
import {Spy} from "dss/spy.sol";

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockCTR is ERC20 {
    constructor() ERC20("CounterDAO", "CTR", 18) {
        _mint(msg.sender, 100000 ether);
    }

    function push(address dst, uint256 wad) external {
        transfer(dst, wad);
    }
}

contract DSSTokenTest is Test, ERC721TokenReceiver {
    MockCTR  internal ctr;
    DSSToken internal token;

    Sum internal sum;
    Use internal use;
    Nil internal nil;
    Spy internal spy;

    Hitter internal hitter;
    Dipper internal dipper;

    DSS internal dss;

    address me    = address(this);
    address alice = mkaddr("alice");
    address eve   = mkaddr("eve");

    receive() external payable {}

    function mkaddr(string memory name) public returns (address addr) {
        addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
    }

    function setUp() public {
        ctr = new MockCTR();

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

        token = new DSSToken(address(dss), address(ctr));

        ctr.push(address(token), 100000 ether);
    }

    function test_token_has_name() public {
        assertEq(token.name(), "CounterDAO");
    }

    function test_token_has_symbol() public {
        assertEq(token.symbol(), "++");
    }

    function test_token_has_owner() public {
        assertEq(token.owner(), me);
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

    function test_hike_increases_price_counter() public {
        (uint256 price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.hike();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 1);
    }

    function test_hike_gives_ctr() public {
        assertEq(ctr.balanceOf(me), 0);

        token.hike();

        assertEq(ctr.balanceOf(me), 10 ether);
    }

    function test_drop_decreases_price_counter() public {
        (uint256 price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.hike();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 1);

        token.drop();

        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);
    }

    function test_drop_gives_ctr() public {
        assertEq(ctr.balanceOf(me), 0);

        token.hike();
        token.drop();

        assertEq(ctr.balanceOf(me), 20 ether);
    }

    function test_mint_assigns_token() public {
        token.mint{value: 0.01 ether}();
        assertEq(token.balanceOf(me), 1);
        assertEq(token.ownerOf(1), me);
    }

    function test_mint_creates_counter() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            address(token.count(1)),
            dss.scry(address(token), bytes32(uint256(1)), address(0))
        );

        token.mint{value: 0.01 ether}();
        assertEq(
            address(token.count(2)),
            dss.scry(address(token), bytes32(uint256(2)), address(0))
        );
    }

    function test_mint_gives_ctr() public {
        assertEq(ctr.balanceOf(me), 0);

        token.mint{value: 0.01 ether}();

        assertEq(ctr.balanceOf(me), 100 ether);
    }

    function test_token_owner_can_hit() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        assertEq(token.see(1), 1);
    }

    function test_token_owner_can_hit_after_transfer() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        assertEq(token.see(1), 1);

        token.transferFrom(me, alice, 1);

        vm.prank(alice);
        token.hit(1);
        assertEq(token.see(1), 2);

        vm.expectRevert(DSSToken.Forbidden.selector);
        token.hit(1);
    }

    function test_non_owner_cannot_hit() public {
        token.mint{value: 0.01 ether}();

        vm.prank(eve);
        vm.expectRevert(DSSToken.Forbidden.selector);
        token.hit(1);
    }

    function test_token_owner_can_dip() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        assertEq(token.see(1), 1);

        token.dip(1);
        assertEq(token.see(1), 0);
    }

    function test_token_owner_can_dip_after_transfer() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        assertEq(token.see(1), 1);

        token.transferFrom(me, alice, 1);

        vm.prank(alice);
        token.dip(1);
        assertEq(token.see(1), 0);

        vm.expectRevert(DSSToken.Forbidden.selector);
        token.dip(1);
    }

    function test_non_owner_cannot_dip() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        assertEq(token.see(1), 1);

        vm.prank(eve);
        vm.expectRevert(DSSToken.Forbidden.selector);
        token.dip(1);
    }

    function test_inc_gets_counter_info() public {
        token.mint{value: 0.01 ether}();

        token.hit(1);
        token.hit(1);
        token.hit(1);
        token.dip(1);

        Inc memory count = token.inc(address(token.count(1)));
        assertEq(count.guy, address(token.count(1)));
        assertEq(count.net, 2);
        assertEq(count.tab, 3);
        assertEq(count.tax, 1);
        assertEq(count.num, 4);
        assertEq(count.hop, 1);

        Inc memory price = token.inc(address(token.price()));
        assertEq(price.guy, address(token.price()));
        assertEq(price.net, 0);
        assertEq(price.tab, 0);
        assertEq(price.tax, 0);
        assertEq(price.num, 0);
        assertEq(price.hop, 1);

        Inc memory coins = token.inc(address(token.coins()));
        assertEq(coins.guy, address(token.coins()));
        assertEq(coins.net, 1);
        assertEq(coins.tab, 1);
        assertEq(coins.tax, 0);
        assertEq(coins.num, 1);
        assertEq(coins.hop, 1);
    }

    function test_mint_reverts_insufficient_payment() public {
        vm.expectRevert(
            abi.encodeWithSelector(DSSToken.WrongPayment.selector, 0, 0.01 ether)
        );
        token.mint{value: 0}();
    }

    function test_cost_function() public {
        assertEq(token.cost(), 0.01 ether);

        token.hike();
        assertEq(token.cost(), 0.011 ether);

        token.hike();
        assertEq(token.cost(), 0.0121 ether);
    }

    function test_cost_function_by_count() public {
        assertEq(token.cost(0), 0.01 ether);
        assertEq(token.cost(10), 0.025937424601000000 ether);
        assertEq(token.cost(100), 137.806123398222701833 ether);
    }

    function test_hike_does_not_increment_above_100() public {
        uint256 price;
        for (uint256 i; i < 100; i++) {
            token.hike();
            (price,,,,) = sum.incs(address(token.price()));
            assertEq(price, i + 1);
        }

        token.hike();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);

        token.hike();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);

        token.hike();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 100);
    }

    function test_drop_does_not_revert_below_zero() public {
        uint256 price;

        token.drop();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);

        token.drop();
        (price,,,,) = sum.incs(address(token.price()));
        assertEq(price, 0);
    }

    function xtest_returns_token_uri() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjogIkNvdW50ZXJEQU8iLCAiZGVzY3JpcHRpb24iOiAiSSBmcm9iYmVkIGFuIEluYyBhbmQgYWxsIEkgZ290IHdhcyB0aGlzIGxvdXN5IHRva2VuIiwgImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjRiV3h1Y3owaWFIUjBjRG92TDNkM2R5NTNNeTV2Y21jdk1qQXdNQzl6ZG1jaUlIZHBaSFJvUFNJek1EQWlJR2hsYVdkb2REMGlNekF3SWlCemRIbHNaVDBpWW1GamEyZHliM1Z1WkRvak4wTkRNMEl6SWo0OGNHRjBhQ0JwWkQwaWRHOXdJaUJrUFNKTklERXdJREV3SUVnZ01qZ3dJR0V4TUN3eE1DQXdJREFnTVNBeE1Dd3hNQ0JXSURJNE1DQmhNVEFzTVRBZ01DQXdJREVnTFRFd0xERXdJRWdnTWpBZ1lURXdMREV3SURBZ01DQXhJQzB4TUN3dE1UQWdWaUF4TUNCNklpQm1hV3hzUFNJak4wTkRNMEl6SWlBK1BDOXdZWFJvUGp4d1lYUm9JR2xrUFNKaWIzUjBiMjBpSUdROUlrMGdNamt3SURJNU1DQklJREl3SUdFeE1Dd3hNQ0F3SURBZ01TQXRNVEFzTFRFd0lGWWdNakFnWVRFd0xERXdJREFnTUNBeElERXdMQzB4TUNCSUlESTRNQ0JoTVRBc01UQWdNQ0F3SURFZ01UQXNNVEFnVmlBeU9UQWdlaUlnWm1sc2JEMGlJemREUXpOQ015SWdQand2Y0dGMGFENDhkR1Y0ZENCa2IyMXBibUZ1ZEMxaVlYTmxiR2x1WlQwaWJXbGtaR3hsSWlCbWIyNTBMV1poYldsc2VUMGliVzl1YjNOd1lXTmxJaUJtYjI1MExYTnBlbVU5SWpraUlHWnBiR3c5SW5kb2FYUmxJaUErUEhSbGVIUlFZWFJvSUdoeVpXWTlJaU4wYjNBaUlENDhJVnREUkVGVVFWdEpibU1nTUhnNE9UQmhOME0yTmpCbE5FSTJNRFEyTVRSQ05URXhSa1F6TlVVeU9EZGhORUUxT1RrME1qSmhJSHdnYm1WME9pQXdJSHdnZEdGaU9pQXdJSHdnZEdGNE9pQXdJSHdnYm5WdE9pQXdJSHdnYUc5d09pQXhYVjArUEdGdWFXMWhkR1VnWVhSMGNtbGlkWFJsVG1GdFpUMGljM1JoY25SUFptWnpaWFFpSUdaeWIyMDlJakFsSWlCMGJ6MGlNVEF3SlNJZ1pIVnlQU0l4TWpCeklpQmlaV2RwYmowaU1ITWlJSEpsY0dWaGRFTnZkVzUwUFNKcGJtUmxabWx1YVhSbElpQStQQzloYm1sdFlYUmxQand2ZEdWNGRGQmhkR2crUEM5MFpYaDBQangwWlhoMElIZzlJalV3SlNJZ2VUMGlORFVsSWlCMFpYaDBMV0Z1WTJodmNqMGliV2xrWkd4bElpQmtiMjFwYm1GdWRDMWlZWE5sYkdsdVpUMGliV2xrWkd4bElpQm1iMjUwTFdaaGJXbHNlVDBpU0dWc2RtVjBhV05oSUU1bGRXVXNJRWhsYkhabGRHbGpZU3dnUVhKcFlXd3NJSE5oYm5NdGMyVnlhV1lpSUdadmJuUXRjMmw2WlQwaU1UVXdJaUJtYjI1MExYZGxhV2RvZEQwaVltOXNaQ0lnWm1sc2JEMGlkMmhwZEdVaUlENDhJVnREUkVGVVFWc3JLMTFkUGp3dmRHVjRkRDQ4ZEdWNGRDQjRQU0kxTUNVaUlIazlJamN3SlNJZ2RHVjRkQzFoYm1Ob2IzSTlJbTFwWkdSc1pTSWdabTl1ZEMxbVlXMXBiSGs5SWtobGJIWmxkR2xqWVNCT1pYVmxMQ0JJWld4MlpYUnBZMkVzSUVGeWFXRnNMQ0J6WVc1ekxYTmxjbWxtSWlCbWIyNTBMWE5wZW1VOUlqSXdJaUJtYVd4c1BTSjNhR2wwWlNJZ1BqRXZNVHd2ZEdWNGRENDhkR1Y0ZENCa2IyMXBibUZ1ZEMxaVlYTmxiR2x1WlQwaWJXbGtaR3hsSWlCbWIyNTBMV1poYldsc2VUMGliVzl1YjNOd1lXTmxJaUJtYjI1MExYTnBlbVU5SWpraUlHWnBiR3c5SW5kb2FYUmxJaUErUEhSbGVIUlFZWFJvSUdoeVpXWTlJaU5pYjNSMGIyMGlJRDQ4SVZ0RFJFRlVRVnRKYm1NZ01IZzVRV1pDTURnNVJHTTNNVEExTURjM056WmpNREJsUWpBNE56Y3hNek0zTVRFeE9UWmtPVEZHSUh3Z2JtVjBPaUF3SUh3Z2RHRmlPaUF3SUh3Z2RHRjRPaUF3SUh3Z2JuVnRPaUF3SUh3Z2FHOXdPaUF3WFYwK1BHRnVhVzFoZEdVZ1lYUjBjbWxpZFhSbFRtRnRaVDBpYzNSaGNuUlBabVp6WlhRaUlHWnliMjA5SWpBbElpQjBiejBpTVRBd0pTSWdaSFZ5UFNJeE1qQnpJaUJpWldkcGJqMGlNSE1pSUhKbGNHVmhkRU52ZFc1MFBTSnBibVJsWm1sdWFYUmxJaUErUEM5aGJtbHRZWFJsUGp3dmRHVjRkRkJoZEdnK1BDOTBaWGgwUGp3dmMzWm5QZz09In0="
        );
    }

    function test_token_uri_reverts_unminted_token() public {
        vm.expectRevert("NOT_MINTED");
        token.tokenURI(1);
    }

    function xtest_returns_token_json() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenJSON(1),
            '{"name": "CounterDAO", "description": "I frobbed an Inc and all I got was this lousy token", "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMDAiIGhlaWdodD0iMzAwIiBzdHlsZT0iYmFja2dyb3VuZDojN0NDM0IzIj48cGF0aCBpZD0idG9wIiBkPSJNIDEwIDEwIEggMjgwIGExMCwxMCAwIDAgMSAxMCwxMCBWIDI4MCBhMTAsMTAgMCAwIDEgLTEwLDEwIEggMjAgYTEwLDEwIDAgMCAxIC0xMCwtMTAgViAxMCB6IiBmaWxsPSIjN0NDM0IzIiA+PC9wYXRoPjxwYXRoIGlkPSJib3R0b20iIGQ9Ik0gMjkwIDI5MCBIIDIwIGExMCwxMCAwIDAgMSAtMTAsLTEwIFYgMjAgYTEwLDEwIDAgMCAxIDEwLC0xMCBIIDI4MCBhMTAsMTAgMCAwIDEgMTAsMTAgViAyOTAgeiIgZmlsbD0iIzdDQzNCMyIgPjwvcGF0aD48dGV4dCBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiBmb250LWZhbWlseT0ibW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IndoaXRlIiA+PHRleHRQYXRoIGhyZWY9IiN0b3AiID48IVtDREFUQVtJbmMgMHg4OTBhN0M2NjBlNEI2MDQ2MTRCNTExRkQzNUUyODdhNEE1OTk0MjJhIHwgbmV0OiAwIHwgdGFiOiAwIHwgdGF4OiAwIHwgbnVtOiAwIHwgaG9wOiAxXV0+PGFuaW1hdGUgYXR0cmlidXRlTmFtZT0ic3RhcnRPZmZzZXQiIGZyb209IjAlIiB0bz0iMTAwJSIgZHVyPSIxMjBzIiBiZWdpbj0iMHMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIiA+PC9hbmltYXRlPjwvdGV4dFBhdGg+PC90ZXh0Pjx0ZXh0IHg9IjUwJSIgeT0iNDUlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiBmb250LWZhbWlseT0iSGVsdmV0aWNhIE5ldWUsIEhlbHZldGljYSwgQXJpYWwsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTUwIiBmb250LXdlaWdodD0iYm9sZCIgZmlsbD0id2hpdGUiID48IVtDREFUQVsrK11dPjwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjcwJSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1mYW1pbHk9IkhlbHZldGljYSBOZXVlLCBIZWx2ZXRpY2EsIEFyaWFsLCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjIwIiBmaWxsPSJ3aGl0ZSIgPjEvMTwvdGV4dD48dGV4dCBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiBmb250LWZhbWlseT0ibW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IndoaXRlIiA+PHRleHRQYXRoIGhyZWY9IiNib3R0b20iID48IVtDREFUQVtJbmMgMHg5QWZCMDg5RGM3MTA1MDc3NzZjMDBlQjA4NzcxMzM3MTExOTZkOTFGIHwgbmV0OiAwIHwgdGFiOiAwIHwgdGF4OiAwIHwgbnVtOiAwIHwgaG9wOiAwXV0+PGFuaW1hdGUgYXR0cmlidXRlTmFtZT0ic3RhcnRPZmZzZXQiIGZyb209IjAlIiB0bz0iMTAwJSIgZHVyPSIxMjBzIiBiZWdpbj0iMHMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIiA+PC9hbmltYXRlPjwvdGV4dFBhdGg+PC90ZXh0Pjwvc3ZnPg=="}'
        );
    }

    function test_token_json_reverts_unminted_token() public {
        vm.expectRevert("NOT_MINTED");
        token.tokenJSON(1);
    }

    function xtest_returns_token_svg() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenSVG(1),
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#7CC3B3"><path id="top" d="M 10 10 H 280 a10,10 0 0 1 10,10 V 280 a10,10 0 0 1 -10,10 H 20 a10,10 0 0 1 -10,-10 V 10 z" fill="#7CC3B3" ></path><path id="bottom" d="M 290 290 H 20 a10,10 0 0 1 -10,-10 V 20 a10,10 0 0 1 10,-10 H 280 a10,10 0 0 1 10,10 V 290 z" fill="#7CC3B3" ></path><text dominant-baseline="middle" font-family="monospace" font-size="9" fill="white" ><textPath href="#top" ><![CDATA[Inc 0x890a7C660e4B604614B511FD35E287a4A599422a | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text><text x="50%" y="45%" text-anchor="middle" dominant-baseline="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="150" font-weight="bold" fill="white" ><![CDATA[++]]></text><text x="50%" y="70%" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="20" fill="white" >1/1</text><text dominant-baseline="middle" font-family="monospace" font-size="9" fill="white" ><textPath href="#bottom" ><![CDATA[Inc 0x9AfB089Dc710507776c00eB0877133711196d91F | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 0]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text></svg>'
        );
    }

    function test_token_svg_reverts_unminted_token() public {
        vm.expectRevert("NOT_MINTED");
        token.tokenSVG(1);
    }

    function test_owner_can_swap() public {
        token.swap(alice);

        assertEq(token.owner(), alice);

        vm.expectRevert(DSSToken.Forbidden.selector);
        token.swap(me);
    }

    function test_non_owner_cannot_swap() public {
        vm.prank(eve);
        vm.expectRevert(DSSToken.Forbidden.selector);
        token.swap(eve);
    }

    function test_owner_can_pull() public {
        uint256 balanceBefore = payable(me).balance;

        vm.deal(alice, 0.03 ether);
        vm.startPrank(alice);

        token.mint{value: 0.01 ether}();
        token.mint{value: 0.01 ether}();
        token.mint{value: 0.01 ether}();

        vm.stopPrank();

        token.pull(me);

        uint256 balanceAfter = payable(me).balance;
        assertEq(balanceAfter - balanceBefore, 0.03 ether);
    }
}
