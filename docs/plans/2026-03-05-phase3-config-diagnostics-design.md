# Phase 3: Configuration & Diagnostics — Design

## Overview

Add Ethereum endpoint configuration, ENS name list configuration, and an HTTPS health check diagnostic tool.

## Configuration: Ethereum Endpoints

- Add `:ethereum` config key to `:periodicmonitor` app
- Keys: `https_endpoint` and `wss_endpoint`
- `config/config.exs`: placeholder defaults
- `config/dev.exs`: user's real Chainstack URLs (not committed)
- `config/runtime.exs`: read from `ETHEREUM_HTTPS_ENDPOINT` and `ETHEREUM_WSS_ENDPOINT` env vars in prod

## Configuration: ENS Names

- Add `:ens_names` config key to `:periodicmonitor` app
- List of strings, e.g. `["name1.eth", "name2.eth", "name3.eth"]`
- `config/config.exs`: empty list default
- `config/dev.exs`: user's actual ENS names

## Module: Periodicmonitor.Ethereum.RPC

- Encapsulates JSON-RPC calls to Ethereum via `Req`
- Initial function: `eth_block_number/0` — calls `eth_blockNumber` method
- Reads endpoint from application config
- Returns `{:ok, block_number}` or `{:error, reason}`
- Will be extended in Phase 4 for ENS contract queries

## Mix Task: mix ethereum.health_check

- Located at `lib/mix/tasks/ethereum.health_check.ex`
- Calls `Periodicmonitor.Ethereum.RPC.eth_block_number/0`
- Displays current block number on success, error message on failure
- Also displays the configured endpoint (masked for security)

## Tests

- Unit test for `Periodicmonitor.Ethereum.RPC` using `Req.Test` adapter (no real HTTP calls)
- Test for mix task output

## Future Scope (not implemented now)

- WSS health check — will be added when WebSocket subscriptions are needed
- WebSocket client dependency — deferred
