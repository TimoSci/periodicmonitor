# CLAUDE.md — ENS Domain Monitor (Periodic Monitor)

## Project Overview

This is a **Phoenix/Elixir web application** that monitors ENS (Ethereum Name Service) domain expiration dates and alerts users before their domains expire. It connects to the Ethereum blockchain via Chainstack (HTTPS and WSS endpoints) to query ENS contract data.

## Tech Stack

- **Elixir 1.17.2** / **Erlang/OTP 27**
- **Phoenix 1.8.4** with LiveView
- **PostgreSQL 16** (local, role `postgres` created, no password)
- **Ecto** for database
- **Req** for HTTP requests (do NOT use HTTPoison, Tesla, or httpc)
- **Tailwind CSS v4** (no tailwind.config.js needed)
- **esbuild** for JS bundling

## Current Status

### Completed
- [x] Development environment fully set up (Erlang, Elixir, Phoenix, PostgreSQL, PGAdmin, Node.js, Git)
- [x] Project scaffolded and compiling successfully
- [x] Database created (`periodicmonitor_dev`)
- [x] Phoenix server runs on localhost:4000
- [x] Fixed Regex compile error in `config/dev.exs` (removed invalid `E` flag from regex patterns)
- [x] Created PostgreSQL role `postgres` with superuser privileges

### TODO — In Priority Order

#### Phase 3: Configuration & Diagnostics
- [x] Create a configuration file for Ethereum endpoints (HTTPS and WSS from Chainstack)
- [x] Create a configuration file for the list of ENS names to monitor
- [ ] Build a diagnostic tool to test WSS connection to Ethereum (health check) — deferred to when WSS is needed
- [x] Build a diagnostic tool to test HTTPS connection to Ethereum (health check)

#### Phase 4: Core ENS Monitoring
- [x] Create database schema/migrations for storing ENS domain data (name, owner, expiration date, status, etc.)
- [x] Build the interface that connects to Ethereum and queries the ENS contract for each name in the config
- [x] Extract expiration dates from ENS registry/registrar contracts
- [x] Store results in PostgreSQL
- [ ] Verify migrations work correctly (user will check via PGAdmin)

#### Phase 5: Alerts & Web Interface
- [x] Define alert rules (active >30d, expiring 7-30d, critical <7d, expired)
- [x] Build Phoenix LiveView page to display monitored domains and their status
- [x] Show visual alerts for domains approaching expiration (pulse animation for expired)
- [x] Color-coded urgency levels (green/yellow/red)

#### Phase 6: Email Notifications
- [x] Create notification_logs table to track sent alerts
- [x] Build email module with Swoosh for expiration alerts
- [x] Implement milestone detection (30d, 7d, 1d)
- [x] Create Scheduler GenServer for daily checks
- [x] Configure SendGrid adapter for production
- [x] Add mix notifications.test_email task

## Development Rules

### Mandatory for Every Feature
1. **Write tests** for every new feature — use `mix test` to verify
2. **Update README.md** with usage instructions for every new feature
3. **Run `mix precommit`** when done with all changes (compiles with warnings-as-errors, formats, runs tests)

### Code Conventions
- Follow all guidelines in `AGENTS.md` (Phoenix 1.8, LiveView, Ecto, HEEx conventions)
- Use `Req` for all HTTP requests
- Use LiveView streams for collections
- Always use `to_form/2` for forms
- Never nest multiple modules in the same file
- Use `mix ecto.gen.migration migration_name` for migrations
- Run `mix precommit` before considering any work complete

### Ethereum/ENS Specifics
- ENS contracts live on Ethereum mainnet
- The ENS BaseRegistrar contract tracks `.eth` domain expiration via `nameExpires(tokenId)` 
- The tokenId is derived from the label hash: `keccak256(label)` where label is the name without `.eth`
- Chainstack provides both HTTPS (for JSON-RPC requests) and WSS (for subscriptions/real-time) endpoints
- The user's Chainstack credentials will be added to the config file — never commit them to git

### Database
- PostgreSQL running locally on port 5432
- Username: `postgres` (superuser, no password)
- Dev database: `periodicmonitor_dev`
- User will verify migrations via PGAdmin

## Project Structure

```
periodicmonitor/
├── config/          # App configuration (dev, test, prod, runtime)
├── lib/
│   ├── periodicmonitor/          # Business logic (contexts, schemas)
│   └── periodicmonitor_web/      # Web layer (controllers, live views, components)
├── priv/
│   ├── repo/migrations/          # Ecto migrations
│   └── static/                   # Static assets
├── test/                         # Tests
├── assets/                       # JS/CSS source
├── AGENTS.md                     # Phoenix coding guidelines (READ THIS)
├── TODO.md                       # Original task list
└── CLAUDE.md                     # This file
```

## How to Run

```bash
mix setup          # Install deps, create DB, run migrations, setup assets
mix phx.server     # Start server at localhost:4000
mix test           # Run tests
mix precommit      # Full check: compile (warnings-as-errors), format, test
```

## Next Immediate Task

**Phase 3**: Create configuration files for Chainstack endpoints (HTTPS + WSS) and ENS name list, then build diagnostic tools to verify the Ethereum connection is working.
