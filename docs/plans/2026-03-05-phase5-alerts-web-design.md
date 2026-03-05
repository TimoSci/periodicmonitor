# Phase 5: Alerts & Web Interface — Design

## Overview

Replace the default Phoenix home page with a LiveView dashboard that displays monitored ENS domains with color-coded status and a refresh button.

## Route

- Replace `/` with a LiveView (`DomainsLive`)
- Remove `PageController` and its route

## LiveView: DomainsLive

### Layout
- Title: "ENS Domain Monitor"
- Refresh button: queries Ethereum, updates DB and UI
- Table with columns: Name, Owner, Expires, Status
- Loading indicator during refresh

### Status Levels & Colors
- **Green** (`active`) — more than 30 days to expiration
- **Yellow** (`expiring`) — 7 to 30 days
- **Red** (`critical`) — less than 7 days
- **Red pulsing** (`expired`) — already expired, continuous blink animation

### Animation
- `expired` rows have a CSS pulse animation (continuous red blink)
- All other statuses are static colored

### Data Flow
- `mount/3`: loads domains from DB via `Domains.list_domains/0`
- Refresh button: triggers async `Domains.check_all_domains/0`, then reloads from DB
- Uses assigns (not streams) since we have a small fixed list (~3 domains)

## Status Update

Update `Domains.compute_status/1` to support 4 levels:
- `active` — >30 days
- `expiring` — 7-30 days
- `critical` — <7 days
- `expired` — past expiration

Update migration default and existing tests accordingly.

## Tests

- LiveView test: page renders domains from DB
- LiveView test: refresh button updates data
- Unit test: `compute_status/1` with new `critical` level
