//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {svg} from 'hot-chain-svg/SVG.sol';
import {utils} from 'hot-chain-svg/Utils.sol';

library Render {
    function render(uint256 _tokenId, uint256 _supply) internal pure returns (string memory) {
        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#7CC3B3">',
                svg.el(
                    'path',
                    string.concat(
                        svg.prop('id', 'top'),
                        svg.prop('d', 'M 10 10 H 280 a10,10 0 0 1 10,10 V 280 a10,10 0 0 1 -10,10 H 20 a10,10 0 0 1 -10,-10 V 10 z'),
                        svg.prop('fill', '#7CC3B3')
                    ),
                    ''
                ),
                svg.el(
                    'path',
                    string.concat(
                        svg.prop('id', 'bottom'),
                        svg.prop('d', 'M 290 290 H 20 a10,10 0 0 1 -10,-10 V 20 a10,10 0 0 1 10,-10 H 280 a10,10 0 0 1 10,10 V 290 z'),
                        svg.prop('fill', '#7CC3B3')
                    ),
                    ''
                ),
                svg.text(
                    string.concat(
                        svg.prop('dominant-baseline', 'middle'),
                        svg.prop('font-family', 'monospace'),
                        svg.prop('font-size', '9'),
                        svg.prop('fill', 'white')
                    ),
                    string.concat(
                        svg.el(
                            'textPath',
                            string.concat(
                                svg.prop('href', '#top')
                            ),
                            string.concat(
                                svg.cdata('Inc 0x890a7C660e4B604614B511FD35E287a4A599422a | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 1'),
                                svg.el(
                                    'animate',
                                    string.concat(
                                        svg.prop('attributeName', 'startOffset'),
                                        svg.prop('from', '0%'),
                                        svg.prop('to', '100%'),
                                        svg.prop('dur', '120s'),
                                        svg.prop('begin', '0s'),
                                        svg.prop('repeatCount', 'indefinite')
                                    ),
                                    ''
                                )
                            )
                        )
                    )
                ),
                svg.text(
                    string.concat(
                        svg.prop('x', '50%'),
                        svg.prop('y', '45%'),
                        svg.prop('text-anchor', 'middle'),
                        svg.prop('dominant-baseline', 'middle'),
                        svg.prop('font-family', 'Helvetica Neue, Helvetica, Arial, sans-serif'),
                        svg.prop('font-size', '150'),
                        svg.prop('font-weight', 'bold'),
                        svg.prop('fill', 'white')
                    ),
                    string.concat(
                        svg.cdata('++')
                    )
                ),
                svg.text(
                    string.concat(
                        svg.prop('x', '50%'),
                        svg.prop('y', '70%'),
                        svg.prop('text-anchor', 'middle'),
                        svg.prop('font-family', 'Helvetica Neue, Helvetica, Arial, sans-serif'),
                        svg.prop('font-size', '20'),
                        svg.prop('fill', 'white')
                    ),
                    string.concat(utils.uint2str(_tokenId), "/", utils.uint2str(_supply))
                ),
                svg.text(
                    string.concat(
                        svg.prop('dominant-baseline', 'middle'),
                        svg.prop('font-family', 'monospace'),
                        svg.prop('font-size', '9'),
                        svg.prop('fill', 'white')
                    ),
                    string.concat(
                        svg.el(
                            'textPath',
                            string.concat(
                                svg.prop('href', '#bottom')
                            ),
                            string.concat(
                                svg.cdata('Inc 0x9AfB089Dc710507776c00eB0877133711196d91F | net: 0 | tab: 0 | tax: 0 | num: 0 | hop: 0'),
                                svg.el(
                                    'animate',
                                    string.concat(
                                        svg.prop('attributeName', 'startOffset'),
                                        svg.prop('from', '0%'),
                                        svg.prop('to', '100%'),
                                        svg.prop('dur', '120s'),
                                        svg.prop('begin', '0s'),
                                        svg.prop('repeatCount', 'indefinite')
                                    ),
                                    ''
                                )
                            )
                        )
                    )
                ),
                '</svg>'
            );
    }
}
