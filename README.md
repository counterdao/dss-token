# dss-token
![Build Status](https://github.com/counterdao/dss-token/actions/workflows/.github/workflows/ci.yml/badge.svg?branch=main)

## DSSToken — frob an inc, get a dss-token

`DSSToken` is an example ERC721 token that uses [dss](https://github.com/counterdao/dss). The contract
makes use of several `DSS` counters:

- `coins` tracks the current token ID.
- `price` is used to calculate the `mint` price.
- Each token has its own `count`, accessible to the token owner.

To `mint` your own `DSSToken`, call `mint` and send ether equal to the current `cost`.

The minimum `cost` of a `DSSToken` is 0.01 ether. However, anyone may call `hike` and `drop` to modify the
current `cost` by 10%. If you choose to `mint`, consider using
[Flashbots Protect](https://docs.flashbots.net/flashbots-protect/overview) to avoid unwanted reverts.

Additionally, `mint`, `hike`, and `drop` will distribute `CTR` governance token to
the caller if a sufficient balance remains in the `DSSToken` contract.

Proceeds from `dss-token` will offset the cost of `dss` deployment and compensate the CounterDAO Protocol
Engineering Core Unit.

### View functions:
- `cost`: Get the current `mint` price.
- `see`: Read a token's counter.

### Public functions:
- `mint`: Mint a `DSSToken` to caller.
- `hike`: Increase `cost` by 10%.
- `drop`: Decrease `cost` by 10%.

### Permissioned functions:
- `hit`: Increment a token's counter. Token owner only.
- `dip`: Decrement a token's counter. Token owner only.
