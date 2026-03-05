# Periodicmonitor

ENS (Ethereum Name Service) domain expiration monitor. Connects to Ethereum via Chainstack to track domain expiration dates and alert before they expire.

## Setup

```bash
mix setup          # Install deps, create DB, run migrations, setup assets
mix phx.server     # Start server at localhost:4000
```

## Configuration

### Ethereum Endpoints

Configure your Chainstack HTTPS and WSS endpoints in `config/dev.exs`:

```elixir
config :periodicmonitor, :ethereum,
  https_endpoint: "https://your-chainstack-https-endpoint",
  wss_endpoint: "wss://your-chainstack-wss-endpoint"
```

For production, set environment variables:

- `ETHEREUM_HTTPS_ENDPOINT` — Chainstack HTTPS URL
- `ETHEREUM_WSS_ENDPOINT` — Chainstack WSS URL

### ENS Names

Configure the list of ENS names to monitor in `config/dev.exs`:

```elixir
config :periodicmonitor, :ens_names, [
  "name1.eth",
  "name2.eth"
]
```

For production, set the `ENS_NAMES` environment variable (comma-separated):

```bash
ENS_NAMES="name1.eth,name2.eth" mix phx.server
```

## Diagnostics

Test your Ethereum HTTPS connection:

```bash
mix ethereum.health_check
```

This calls `eth_blockNumber` on the configured endpoint and displays the current block number.

## Development

```bash
mix test           # Run tests
mix precommit      # Full check: compile (warnings-as-errors), format, test
```
