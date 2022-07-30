# dss-token
![Build Status](https://github.com/counterdao/dss-token/actions/workflows/.github/workflows/ci.yml/badge.svg?branch=main)

## DSSToken — frob an inc, get this lousy token

`DSSToken` is an example ERC721 token that uses [dss](https://github.com/counterdao/dss). The contract
makes use of several `DSS` counters:

- `coins` tracks the current token ID.
- `price` is used to calculate the `mint` price.
- Each token has its own `count`, accessible to the token owner.

Public functions:
- `cost`: Get the current `mint` price.
- `mint`: Mint a `DSSToken` to caller.
- `hike`: Increase `cost` by 10%.
- `drop`: Decrease `cost` by 10%.
- `see`: Read a token's counter.

Permissioned functions:
- `hit`: Increment a token's counter. (Token owner only).
- `dip`: Decrement a token's counter. (Token owner only).
