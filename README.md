# Periodicmonitor

ENS (Ethereum Name Service) domain expiration monitor. Connects to Ethereum via Chainstack to track domain expiration dates and alert before they expire. Sends alerts via Session Messenger when domains approach expiration.

**Running at:** http://localhost:4000

## How Monitoring Works

The app runs a **Scheduler GenServer** that checks all monitored ENS domains once every 24 hours:

1. The scheduler queries the Ethereum blockchain via Chainstack to get each domain's expiration date
2. For each domain, it calculates which milestone applies:
   - **30 days** before expiration
   - **7 days** before expiration
   - **1 day** before expiration
3. If a domain hits a milestone that hasn't been notified yet, it sends a Session message to all configured recipients
4. The notification is logged to prevent duplicates (each domain/milestone pair is only notified once)

You can also manually check expirations and refresh data via the **Refresh** button on the web dashboard.

## Running as a Service (macOS)

The app is configured as a **macOS LaunchAgent** — it starts automatically when you log in and restarts if it crashes. No terminal needed.

| Service | Port | LaunchAgent |
|---------|------|-------------|
| Session Bot | 3100 | `com.periodicmonitor.session-service` |
| Periodicmonitor | 4000 | `com.periodicmonitor.phoenix` |

**Logs:** `~/Library/Logs/periodicmonitor.log` and `~/Library/Logs/session-service.log`

**Useful commands:**

```bash
# Check if running
curl http://localhost:3100/health    # Session bot
curl -s -o /dev/null -w "%{http_code}" http://localhost:4000  # Phoenix

# Restart a service
launchctl unload ~/Library/LaunchAgents/com.periodicmonitor.phoenix.plist
launchctl load ~/Library/LaunchAgents/com.periodicmonitor.phoenix.plist

# View logs
tail -f ~/Library/Logs/periodicmonitor.log
```

## Initial Setup

```bash
mix setup          # Install deps, create DB, run migrations, setup assets

# Session service (one-time)
cd session_service && bun install && cd ..
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

Notifications are sent when ENS domains reach expiration milestones:
- **30 days** before expiration
- **7 days** before expiration
- **1 day** before expiration

### Session Messenger (default)

Notifications are sent via Session Messenger through a Bun microservice.

**Prerequisites:**
- Install [Bun](https://bun.sh): `curl -fsSL https://bun.sh/install | bash`

**Setup:**

```bash
# Install Session service dependencies
cd session_service && bun install && cd ..

# Start the Session service (generates a bot mnemonic on first run)
cd session_service && bun run index.ts

# Generate a mnemonic for the bot (from another terminal)
curl http://localhost:3100/generate-mnemonic
```

**Configuration (environment variables):**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SESSION_BOT_MNEMONIC` | Yes | — | 13-word Session seed phrase for the bot |
| `SESSION_DISPLAY_NAME` | No | `ENS Monitor Bot` | Bot display name |
| `SESSION_RECIPIENTS` | Yes | — | Comma-separated Session IDs |
| `SESSION_SERVICE_URL` | No | `http://localhost:3100` | Microservice URL |
| `NOTIFICATION_TRANSPORT` | No | `session` | `session` or `email` |

**Testing:**

```bash
mix notifications.test_session
```

### Email (fallback)

To switch back to email notifications, set `NOTIFICATION_TRANSPORT=email` and configure:

- `MAILGUN_API_KEY` — Mailgun API key
- `MAILGUN_DOMAIN` — Mailgun domain
- `ALERT_RECIPIENTS` — comma-separated email addresses
- `ALERT_FROM_EMAIL` — sender email (default: `alerts@periodicmonitor.local`)

```bash
mix notifications.test_email
```

### Environment Behavior

- **Production**: The notification scheduler runs daily via the configured transport.
- **Dev/Test**: The scheduler is disabled. Use mix tasks to test manually.

## Development

```bash
mix test           # Run tests
mix precommit      # Full check: compile (warnings-as-errors), format, test
```
