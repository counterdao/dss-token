// SPDX-License-Identifier: AGPL-3.0-or-later
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
        _mint(msg.sender, 100_000 ether);
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
}

contract TestToken is DSSTokenTest {
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

    function test_token_uri_reverts_unminted_token() public {
        vm.expectRevert("NOT_MINTED");
        token.tokenURI(1);
    }

    function test_token_json_reverts_unminted_token() public {
        vm.expectRevert("NOT_MINTED");
        token.tokenJSON(1);
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

contract TestRender is DSSTokenTest {
    function test_render_token_uri() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjogIkNvdW50ZXJEQU8gIzEiLCAiZGVzY3JpcHRpb24iOiAiSSBmcm9iYmVkIGFuIGluYyBhbmQgYWxsIEkgZ290IHdhcyB0aGlzIGxvdXN5IGRzcy10b2tlbiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUI0Yld4dWN6MGlhSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNakF3TUM5emRtY2lJSFpwWlhkQ2IzZzlJakFnTUNBek1EQWdNekF3SWlCemRIbHNaVDBpWW1GamEyZHliM1Z1WkRvak4wTkRNMEl6TzJadmJuUXRabUZ0YVd4NU9raGxiSFpsZEdsallTQk9aWFZsTENCSVpXeDJaWFJwWTJFc0lFRnlhV0ZzTENCellXNXpMWE5sY21sbU95SStQSEJoZEdnZ2FXUTlJblJ2Y0NJZ1pEMGlUU0F4TUNBeE1DQklJREk0TUNCaE1UQXNNVEFnTUNBd0lERWdNVEFzTVRBZ1ZpQXlPREFnWVRFd0xERXdJREFnTUNBeElDMHhNQ3d4TUNCSUlESXdJR0V4TUN3eE1DQXdJREFnTVNBdE1UQXNMVEV3SUZZZ01UQWdlaUlnWm1sc2JEMGlJemREUXpOQ015SWdQand2Y0dGMGFENDhjR0YwYUNCcFpEMGlZbTkwZEc5dElpQmtQU0pOSURJNU1DQXlPVEFnU0NBeU1DQmhNVEFzTVRBZ01DQXdJREVnTFRFd0xDMHhNQ0JXSURJd0lHRXhNQ3d4TUNBd0lEQWdNU0F4TUN3dE1UQWdTQ0F5T0RBZ1lURXdMREV3SURBZ01DQXhJREV3TERFd0lGWWdNamt3SUhvaUlHWnBiR3c5SWlNM1EwTXpRak1pSUQ0OEwzQmhkR2crUEhSbGVIUWdaRzl0YVc1aGJuUXRZbUZ6Wld4cGJtVTlJbTFwWkdSc1pTSWdabTl1ZEMxbVlXMXBiSGs5SWsxbGJteHZMQ0J0YjI1dmMzQmhZMlVpSUdadmJuUXRjMmw2WlQwaU9TSWdabWxzYkQwaWQyaHBkR1VpSUQ0OGRHVjRkRkJoZEdnZ2FISmxaajBpSTNSdmNDSWdQandoVzBORVFWUkJXMGx1WXlBd2VEZ3hZV1ZoWVdNMFlURXdOekpsTXpsbFlUazRZV1ZtT1dZellXSmxObVUyTmpGbE5qa3hORFVnZkNCdVpYUTZJREFnZkNCMFlXSTZJREFnZkNCMFlYZzZJREFnZkNCdWRXMDZJREFnZkNCb2IzQTZJREZkWFQ0OFlXNXBiV0YwWlNCaGRIUnlhV0oxZEdWT1lXMWxQU0p6ZEdGeWRFOW1abk5sZENJZ1puSnZiVDBpTUNVaUlIUnZQU0l4TURBbElpQmtkWEk5SWpFeU1ITWlJR0psWjJsdVBTSXdjeUlnY21Wd1pXRjBRMjkxYm5ROUltbHVaR1ZtYVc1cGRHVWlJRDQ4TDJGdWFXMWhkR1UrUEM5MFpYaDBVR0YwYUQ0OEwzUmxlSFErUEhSbGVIUWdlRDBpTlRBbElpQjVQU0kwTlNVaUlIUmxlSFF0WVc1amFHOXlQU0p0YVdSa2JHVWlJR1J2YldsdVlXNTBMV0poYzJWc2FXNWxQU0p0YVdSa2JHVWlJR1p2Ym5RdGMybDZaVDBpTVRVd0lpQm1iMjUwTFhkbGFXZG9kRDBpWW05c1pDSWdabWxzYkQwaWQyaHBkR1VpSUQ0OElWdERSRUZVUVZzcksxMWRQand2ZEdWNGRENDhkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqY3dKU0lnZEdWNGRDMWhibU5vYjNJOUltMXBaR1JzWlNJZ1ptOXVkQzF6YVhwbFBTSXlNQ0lnWm1sc2JEMGlkMmhwZEdVaUlENHhJQzhnTVR3dmRHVjRkRDQ4ZEdWNGRDQjRQU0kxTUNVaUlIazlJamd3SlNJZ2RHVjRkQzFoYm1Ob2IzSTlJbTFwWkdSc1pTSWdabTl1ZEMxemFYcGxQU0l5TUNJZ1ptbHNiRDBpZDJocGRHVWlJRDR3UEM5MFpYaDBQangwWlhoMElHUnZiV2x1WVc1MExXSmhjMlZzYVc1bFBTSnRhV1JrYkdVaUlHWnZiblF0Wm1GdGFXeDVQU0pOWlc1c2J5d2diVzl1YjNOd1lXTmxJaUJtYjI1MExYTnBlbVU5SWpraUlHWnBiR3c5SW5kb2FYUmxJaUErUEhSbGVIUlFZWFJvSUdoeVpXWTlJaU5pYjNSMGIyMGlJRDQ4SVZ0RFJFRlVRVnRKYm1NZ01IaGtPVGhpTURNd01XRm1NRGcyWVRaaU9HTm1ZMkV4WkdVMU1qRXlaRE13WTJZNFptUmxORE5tSUh3Z2JtVjBPaUF3SUh3Z2RHRmlPaUF3SUh3Z2RHRjRPaUF3SUh3Z2JuVnRPaUF3SUh3Z2FHOXdPaUF4WFYwK1BHRnVhVzFoZEdVZ1lYUjBjbWxpZFhSbFRtRnRaVDBpYzNSaGNuUlBabVp6WlhRaUlHWnliMjA5SWpBbElpQjBiejBpTVRBd0pTSWdaSFZ5UFNJeE1qQnpJaUJpWldkcGJqMGlNSE1pSUhKbGNHVmhkRU52ZFc1MFBTSnBibVJsWm1sdWFYUmxJaUErUEM5aGJtbHRZWFJsUGp3dmRHVjRkRkJoZEdnK1BDOTBaWGgwUGp3dmMzWm5QZz09IiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogIm5ldCIsICJ2YWx1ZSI6ICIwIiwgImRpc3BsYXlfdHlwZSI6ICJudW1iZXIifSx7InRyYWl0X3R5cGUiOiAidGFiIiwgInZhbHVlIjogIjAiLCAiZGlzcGxheV90eXBlIjogIm51bWJlciJ9LHsidHJhaXRfdHlwZSI6ICJ0YXgiLCAidmFsdWUiOiAiMCIsICJkaXNwbGF5X3R5cGUiOiAibnVtYmVyIn0seyJ0cmFpdF90eXBlIjogIm51bSIsICJ2YWx1ZSI6ICIwIiwgImRpc3BsYXlfdHlwZSI6ICJudW1iZXIifSx7InRyYWl0X3R5cGUiOiAiaG9wIiwgInZhbHVlIjogIjEiLCAiZGlzcGxheV90eXBlIjogIm51bWJlciJ9XX0="
        );
    }

    function test_render_token_json() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenJSON(1),
            '{"name": "CounterDAO #1", "description": "I frobbed an inc and all I got was this lousy dss-token", "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzMDAgMzAwIiBzdHlsZT0iYmFja2dyb3VuZDojN0NDM0IzO2ZvbnQtZmFtaWx5OkhlbHZldGljYSBOZXVlLCBIZWx2ZXRpY2EsIEFyaWFsLCBzYW5zLXNlcmlmOyI+PHBhdGggaWQ9InRvcCIgZD0iTSAxMCAxMCBIIDI4MCBhMTAsMTAgMCAwIDEgMTAsMTAgViAyODAgYTEwLDEwIDAgMCAxIC0xMCwxMCBIIDIwIGExMCwxMCAwIDAgMSAtMTAsLTEwIFYgMTAgeiIgZmlsbD0iIzdDQzNCMyIgPjwvcGF0aD48cGF0aCBpZD0iYm90dG9tIiBkPSJNIDI5MCAyOTAgSCAyMCBhMTAsMTAgMCAwIDEgLTEwLC0xMCBWIDIwIGExMCwxMCAwIDAgMSAxMCwtMTAgSCAyODAgYTEwLDEwIDAgMCAxIDEwLDEwIFYgMjkwIHoiIGZpbGw9IiM3Q0MzQjMiID48L3BhdGg+PHRleHQgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgZm9udC1mYW1pbHk9Ik1lbmxvLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0id2hpdGUiID48dGV4dFBhdGggaHJlZj0iI3RvcCIgPjwhW0NEQVRBW0luYyAweDgxYWVhYWM0YTEwNzJlMzllYTk4YWVmOWYzYWJlNmU2NjFlNjkxNDUgfCBuZXQ6IDAgfCB0YWI6IDAgfCB0YXg6IDAgfCBudW06IDAgfCBob3A6IDFdXT48YW5pbWF0ZSBhdHRyaWJ1dGVOYW1lPSJzdGFydE9mZnNldCIgZnJvbT0iMCUiIHRvPSIxMDAlIiBkdXI9IjEyMHMiIGJlZ2luPSIwcyIgcmVwZWF0Q291bnQ9ImluZGVmaW5pdGUiID48L2FuaW1hdGU+PC90ZXh0UGF0aD48L3RleHQ+PHRleHQgeD0iNTAlIiB5PSI0NSUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTUwIiBmb250LXdlaWdodD0iYm9sZCIgZmlsbD0id2hpdGUiID48IVtDREFUQVsrK11dPjwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjcwJSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIyMCIgZmlsbD0id2hpdGUiID4xIC8gMTwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjgwJSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIyMCIgZmlsbD0id2hpdGUiID4wPC90ZXh0Pjx0ZXh0IGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJNZW5sbywgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IndoaXRlIiA+PHRleHRQYXRoIGhyZWY9IiNib3R0b20iID48IVtDREFUQVtJbmMgMHhkOThiMDMwMWFmMDg2YTZiOGNmY2ExZGU1MjEyZDMwY2Y4ZmRlNDNmIHwgbmV0OiAwIHwgdGFiOiAwIHwgdGF4OiAwIHwgbnVtOiAwIHwgaG9wOiAxXV0+PGFuaW1hdGUgYXR0cmlidXRlTmFtZT0ic3RhcnRPZmZzZXQiIGZyb209IjAlIiB0bz0iMTAwJSIgZHVyPSIxMjBzIiBiZWdpbj0iMHMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIiA+PC9hbmltYXRlPjwvdGV4dFBhdGg+PC90ZXh0Pjwvc3ZnPg==", "attributes": [{"trait_type": "net", "value": "0", "display_type": "number"},{"trait_type": "tab", "value": "0", "display_type": "number"},{"trait_type": "tax", "value": "0", "display_type": "number"},{"trait_type": "num", "value": "0", "display_type": "number"},{"trait_type": "hop", "value": "1", "display_type": "number"}]}'
        );
    }

    function test_render_token_svg() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenSVG(1),
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" style="background:#7CC3B3;font-family:Helvetica Neue, Helvetica, Arial, sans-serif;"><path id="top" d="M 10 10 H 280 a10,10 0 0 1 10,10 V 280 a10,10 0 0 1 -10,10 H 20 a10,10 0 0 1 -10,-10 V 10 z" fill="#7CC3B3" ></path><path id="bottom" d="M 290 290 H 20 a10,10 0 0 1 -10,-10 V 20 a10,10 0 0 1 10,-10 H 280 a10,10 0 0 1 10,10 V 290 z" fill="#7CC3B3" ></path><text dominant-baseline="middle" font-family="Menlo, monospace" font-size="9" fill="white" ><textPath href="#top" ><![CDATA[Inc 0x81aeaac4a1072e39ea98aef9f3abe6e661e69145 | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text><text x="50%" y="45%" text-anchor="middle" dominant-baseline="middle" font-size="150" font-weight="bold" fill="white" ><![CDATA[++]]></text><text x="50%" y="70%" text-anchor="middle" font-size="20" fill="white" >1 / 1</text><text x="50%" y="80%" text-anchor="middle" font-size="20" fill="white" >0</text><text dominant-baseline="middle" font-family="Menlo, monospace" font-size="9" fill="white" ><textPath href="#bottom" ><![CDATA[Inc 0xd98b0301af086a6b8cfca1de5212d30cf8fde43f | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text></svg>'
        );
    }
}
