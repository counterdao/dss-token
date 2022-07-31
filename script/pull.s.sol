// SPDX-License-Identifier: AGPL-3.0-or-later

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

import "forge-std/Script.sol";

interface DSSTokenLike {
    function pull(address) external;
}

contract Pull is Script {

    function pull(address dssToken, address dst) public {
        DSSTokenLike token = DSSTokenLike(dssToken);
        token.pull(dst);
    }

    function run() external {
        vm.startBroadcast();

        address dssToken = vm.envAddress("DSS_DSS_TOKEN_ADDRESS");
        address dst      = vm.envAddress("DSS_TOKEN_DST_ADDRESS");
        pull(dssToken, dst);

        vm.stopBroadcast();
    }
}
