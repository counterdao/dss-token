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
            "data:application/json;base64,eyJuYW1lIjogIkNvdW50ZXJEQU8gIzEiLCAiZGVzY3JpcHRpb24iOiAiSSBmcm9iYmVkIGFuIGluYyBhbmQgYWxsIEkgZ290IHdhcyB0aGlzIGxvdXN5IHRva2VuIiwgImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjRiV3h1Y3owaWFIUjBjRG92TDNkM2R5NTNNeTV2Y21jdk1qQXdNQzl6ZG1jaUlIWnBaWGRDYjNnOUlqQWdNQ0F6TURBZ016QXdJaUJ6ZEhsc1pUMGlZbUZqYTJkeWIzVnVaRG9qTjBORE0wSXpPMlp2Ym5RdFptRnRhV3g1T2tobGJIWmxkR2xqWVNCT1pYVmxMQ0JJWld4MlpYUnBZMkVzSUVGeWFXRnNMQ0J6WVc1ekxYTmxjbWxtT3lJK1BIQmhkR2dnYVdROUluUnZjQ0lnWkQwaVRTQXhNQ0F4TUNCSUlESTRNQ0JoTVRBc01UQWdNQ0F3SURFZ01UQXNNVEFnVmlBeU9EQWdZVEV3TERFd0lEQWdNQ0F4SUMweE1Dd3hNQ0JJSURJd0lHRXhNQ3d4TUNBd0lEQWdNU0F0TVRBc0xURXdJRllnTVRBZ2VpSWdabWxzYkQwaUl6ZERRek5DTXlJZ1Bqd3ZjR0YwYUQ0OGNHRjBhQ0JwWkQwaVltOTBkRzl0SWlCa1BTSk5JREk1TUNBeU9UQWdTQ0F5TUNCaE1UQXNNVEFnTUNBd0lERWdMVEV3TEMweE1DQldJREl3SUdFeE1Dd3hNQ0F3SURBZ01TQXhNQ3d0TVRBZ1NDQXlPREFnWVRFd0xERXdJREFnTUNBeElERXdMREV3SUZZZ01qa3dJSG9pSUdacGJHdzlJaU0zUTBNelFqTWlJRDQ4TDNCaGRHZytQSFJsZUhRZ1pHOXRhVzVoYm5RdFltRnpaV3hwYm1VOUltMXBaR1JzWlNJZ1ptOXVkQzFtWVcxcGJIazlJazFsYm14dkxDQnRiMjV2YzNCaFkyVWlJR1p2Ym5RdGMybDZaVDBpT1NJZ1ptbHNiRDBpZDJocGRHVWlJRDQ4ZEdWNGRGQmhkR2dnYUhKbFpqMGlJM1J2Y0NJZ1Bqd2hXME5FUVZSQlcwbHVZeUF3ZURZelpqSTFOekU0TlRRNU1UYzRaR0l5WWpVNU9XSXhaRGxrWmpSbU1EUTBPR0kzTnpVMU1tRWdmQ0J1WlhRNklEQWdmQ0IwWVdJNklEQWdmQ0IwWVhnNklEQWdmQ0J1ZFcwNklEQWdmQ0JvYjNBNklERmRYVDQ4WVc1cGJXRjBaU0JoZEhSeWFXSjFkR1ZPWVcxbFBTSnpkR0Z5ZEU5bVpuTmxkQ0lnWm5KdmJUMGlNQ1VpSUhSdlBTSXhNREFsSWlCa2RYSTlJakV5TUhNaUlHSmxaMmx1UFNJd2N5SWdjbVZ3WldGMFEyOTFiblE5SW1sdVpHVm1hVzVwZEdVaUlENDhMMkZ1YVcxaGRHVStQQzkwWlhoMFVHRjBhRDQ4TDNSbGVIUStQSFJsZUhRZ2VEMGlOVEFsSWlCNVBTSTBOU1VpSUhSbGVIUXRZVzVqYUc5eVBTSnRhV1JrYkdVaUlHUnZiV2x1WVc1MExXSmhjMlZzYVc1bFBTSnRhV1JrYkdVaUlHWnZiblF0YzJsNlpUMGlNVFV3SWlCbWIyNTBMWGRsYVdkb2REMGlZbTlzWkNJZ1ptbHNiRDBpZDJocGRHVWlJRDQ4SVZ0RFJFRlVRVnNySzExZFBqd3ZkR1Y0ZEQ0OGRHVjRkQ0I0UFNJMU1DVWlJSGs5SWpjd0pTSWdkR1Y0ZEMxaGJtTm9iM0k5SW0xcFpHUnNaU0lnWm05dWRDMXphWHBsUFNJeU1DSWdabWxzYkQwaWQyaHBkR1VpSUQ0eElDOGdNVHd2ZEdWNGRENDhkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqZ3dKU0lnZEdWNGRDMWhibU5vYjNJOUltMXBaR1JzWlNJZ1ptOXVkQzF6YVhwbFBTSXlNQ0lnWm1sc2JEMGlkMmhwZEdVaUlENHdQQzkwWlhoMFBqeDBaWGgwSUdSdmJXbHVZVzUwTFdKaGMyVnNhVzVsUFNKdGFXUmtiR1VpSUdadmJuUXRabUZ0YVd4NVBTSk5aVzVzYnl3Z2JXOXViM053WVdObElpQm1iMjUwTFhOcGVtVTlJamtpSUdacGJHdzlJbmRvYVhSbElpQStQSFJsZUhSUVlYUm9JR2h5WldZOUlpTmliM1IwYjIwaUlENDhJVnREUkVGVVFWdEpibU1nTUhnelltRTBabUl6T1dSa1kyWTNPR1kzTm1ObFpHTmtZekV3TXpVeVlUSTBNR1JpWldSaE5qSTVJSHdnYm1WME9pQXdJSHdnZEdGaU9pQXdJSHdnZEdGNE9pQXdJSHdnYm5WdE9pQXdJSHdnYUc5d09pQXhYVjArUEdGdWFXMWhkR1VnWVhSMGNtbGlkWFJsVG1GdFpUMGljM1JoY25SUFptWnpaWFFpSUdaeWIyMDlJakFsSWlCMGJ6MGlNVEF3SlNJZ1pIVnlQU0l4TWpCeklpQmlaV2RwYmowaU1ITWlJSEpsY0dWaGRFTnZkVzUwUFNKcGJtUmxabWx1YVhSbElpQStQQzloYm1sdFlYUmxQand2ZEdWNGRGQmhkR2crUEM5MFpYaDBQand2YzNablBnPT0iLCAiYXR0cmlidXRlcyI6IFt7InRyYWl0X3R5cGUiOiAibmV0IiwgInZhbHVlIjogIjAiLCAiZGlzcGxheV90eXBlIjogIm51bWJlciJ9LHsidHJhaXRfdHlwZSI6ICJ0YWIiLCAidmFsdWUiOiAiMCIsICJkaXNwbGF5X3R5cGUiOiAibnVtYmVyIn0seyJ0cmFpdF90eXBlIjogInRheCIsICJ2YWx1ZSI6ICIwIiwgImRpc3BsYXlfdHlwZSI6ICJudW1iZXIifSx7InRyYWl0X3R5cGUiOiAibnVtIiwgInZhbHVlIjogIjAiLCAiZGlzcGxheV90eXBlIjogIm51bWJlciJ9LHsidHJhaXRfdHlwZSI6ICJob3AiLCAidmFsdWUiOiAiMSIsICJkaXNwbGF5X3R5cGUiOiAibnVtYmVyIn1dfQ=="
        );
    }

    function test_render_token_json() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenJSON(1),
            '{"name": "CounterDAO #1", "description": "I frobbed an inc and all I got was this lousy token", "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzMDAgMzAwIiBzdHlsZT0iYmFja2dyb3VuZDojN0NDM0IzO2ZvbnQtZmFtaWx5OkhlbHZldGljYSBOZXVlLCBIZWx2ZXRpY2EsIEFyaWFsLCBzYW5zLXNlcmlmOyI+PHBhdGggaWQ9InRvcCIgZD0iTSAxMCAxMCBIIDI4MCBhMTAsMTAgMCAwIDEgMTAsMTAgViAyODAgYTEwLDEwIDAgMCAxIC0xMCwxMCBIIDIwIGExMCwxMCAwIDAgMSAtMTAsLTEwIFYgMTAgeiIgZmlsbD0iIzdDQzNCMyIgPjwvcGF0aD48cGF0aCBpZD0iYm90dG9tIiBkPSJNIDI5MCAyOTAgSCAyMCBhMTAsMTAgMCAwIDEgLTEwLC0xMCBWIDIwIGExMCwxMCAwIDAgMSAxMCwtMTAgSCAyODAgYTEwLDEwIDAgMCAxIDEwLDEwIFYgMjkwIHoiIGZpbGw9IiM3Q0MzQjMiID48L3BhdGg+PHRleHQgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgZm9udC1mYW1pbHk9Ik1lbmxvLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0id2hpdGUiID48dGV4dFBhdGggaHJlZj0iI3RvcCIgPjwhW0NEQVRBW0luYyAweDYzZjI1NzE4NTQ5MTc4ZGIyYjU5OWIxZDlkZjRmMDQ0OGI3NzU1MmEgfCBuZXQ6IDAgfCB0YWI6IDAgfCB0YXg6IDAgfCBudW06IDAgfCBob3A6IDFdXT48YW5pbWF0ZSBhdHRyaWJ1dGVOYW1lPSJzdGFydE9mZnNldCIgZnJvbT0iMCUiIHRvPSIxMDAlIiBkdXI9IjEyMHMiIGJlZ2luPSIwcyIgcmVwZWF0Q291bnQ9ImluZGVmaW5pdGUiID48L2FuaW1hdGU+PC90ZXh0UGF0aD48L3RleHQ+PHRleHQgeD0iNTAlIiB5PSI0NSUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTUwIiBmb250LXdlaWdodD0iYm9sZCIgZmlsbD0id2hpdGUiID48IVtDREFUQVsrK11dPjwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjcwJSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIyMCIgZmlsbD0id2hpdGUiID4xIC8gMTwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjgwJSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIyMCIgZmlsbD0id2hpdGUiID4wPC90ZXh0Pjx0ZXh0IGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJNZW5sbywgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IndoaXRlIiA+PHRleHRQYXRoIGhyZWY9IiNib3R0b20iID48IVtDREFUQVtJbmMgMHgzYmE0ZmIzOWRkY2Y3OGY3NmNlZGNkYzEwMzUyYTI0MGRiZWRhNjI5IHwgbmV0OiAwIHwgdGFiOiAwIHwgdGF4OiAwIHwgbnVtOiAwIHwgaG9wOiAxXV0+PGFuaW1hdGUgYXR0cmlidXRlTmFtZT0ic3RhcnRPZmZzZXQiIGZyb209IjAlIiB0bz0iMTAwJSIgZHVyPSIxMjBzIiBiZWdpbj0iMHMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIiA+PC9hbmltYXRlPjwvdGV4dFBhdGg+PC90ZXh0Pjwvc3ZnPg==", "attributes": [{"trait_type": "net", "value": "0", "display_type": "number"},{"trait_type": "tab", "value": "0", "display_type": "number"},{"trait_type": "tax", "value": "0", "display_type": "number"},{"trait_type": "num", "value": "0", "display_type": "number"},{"trait_type": "hop", "value": "1", "display_type": "number"}]}'
        );
    }

    function test_render_token_svg() public {
        token.mint{value: 0.01 ether}();
        assertEq(
            token.tokenSVG(1),
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" style="background:#7CC3B3;font-family:Helvetica Neue, Helvetica, Arial, sans-serif;"><path id="top" d="M 10 10 H 280 a10,10 0 0 1 10,10 V 280 a10,10 0 0 1 -10,10 H 20 a10,10 0 0 1 -10,-10 V 10 z" fill="#7CC3B3" ></path><path id="bottom" d="M 290 290 H 20 a10,10 0 0 1 -10,-10 V 20 a10,10 0 0 1 10,-10 H 280 a10,10 0 0 1 10,10 V 290 z" fill="#7CC3B3" ></path><text dominant-baseline="middle" font-family="Menlo, monospace" font-size="9" fill="white" ><textPath href="#top" ><![CDATA[Inc 0x63f25718549178db2b599b1d9df4f0448b77552a | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text><text x="50%" y="45%" text-anchor="middle" dominant-baseline="middle" font-size="150" font-weight="bold" fill="white" ><![CDATA[++]]></text><text x="50%" y="70%" text-anchor="middle" font-size="20" fill="white" >1 / 1</text><text x="50%" y="80%" text-anchor="middle" font-size="20" fill="white" >0</text><text dominant-baseline="middle" font-family="Menlo, monospace" font-size="9" fill="white" ><textPath href="#bottom" ><![CDATA[Inc 0x3ba4fb39ddcf78f76cedcdc10352a240dbeda629 | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1]]><animate attributeName="startOffset" from="0%" to="100%" dur="120s" begin="0s" repeatCount="indefinite" ></animate></textPath></text></svg>'
        );
    }
}
