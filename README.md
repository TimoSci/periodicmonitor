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

## ENS Domain Monitoring

Check expiration dates for all configured ENS names:

```bash
mix ens.check_expirations
```

This queries the ENS BaseRegistrar and Registry contracts on Ethereum mainnet, retrieves expiration dates and owners, and stores results in the database.

## Web Interface

Start the server and visit [localhost:4000](http://localhost:4000):

```bash
mix phx.server
```

The dashboard displays all monitored ENS domains with color-coded status:
- **Green** — Active (>30 days to expiration)
- **Yellow** — Expiring (7-30 days)
- **Red** — Critical (<7 days)
- **Red pulsing** — Expired

Use the **Refresh** button to query Ethereum and update domain data.

## Notifications

Email notifications are sent when ENS domains reach expiration milestones:
- **30 days** before expiration
- **7 days** before expiration
- **1 day** before expiration

### Configuration

Set the following environment variables:

- `SENDGRID_API_KEY` — your SendGrid API key
- `ALERT_RECIPIENTS` — comma-separated email addresses (e.g., `user1@example.com,user2@example.com`)
- `ALERT_FROM_EMAIL` — sender email address (default: `alerts@periodicmonitor.local`)

### Testing Emails

```bash
mix notifications.test_email
```

This sends a test email to all configured recipients. Requires `ALERT_RECIPIENTS` to be set.

### Environment Behavior

- **Production**: The notification scheduler runs daily, sending alerts via SendGrid.
- **Dev/Test**: The scheduler is disabled. In dev, emails go to the local Swoosh mailbox at [localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox).

## Development

```bash
mix test           # Run tests
mix precommit      # Full check: compile (warnings-as-errors), format, test
```
