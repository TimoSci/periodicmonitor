# Phase 4: Core ENS Monitoring — Design

## Overview

Create database schema for ENS domain data, build interface to query ENS contracts (BaseRegistrar + Registry) for expiration dates and owners, store results in PostgreSQL, expose via mix task.

## Schema: ens_domains

| Field | Type | Description |
|-------|------|-------------|
| id | bigserial | PK |
| name | string | Full name, e.g. "urs.eth" |
| label_hash | string | keccak256 of label (hex) |
| owner | string | Ethereum address of owner |
| expires_at | utc_datetime | Expiration date |
| status | string | "active", "expiring", "expired" |
| last_checked_at | utc_datetime | Last contract query time |
| inserted_at / updated_at | utc_datetime | Ecto timestamps |

Unique index on `name`.

## Module: Periodicmonitor.Ethereum.ENS

Interacts with ENS contracts via RPC:

- `name_expires(label)` — calls `nameExpires(tokenId)` on BaseRegistrar (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85)
- `owner(name)` — calls `owner(namehash)` on ENS Registry (0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
- Internal helpers: `label_hash/1` (keccak256 via :crypto), `namehash/1` (ENS namehash algorithm)

## Module: Periodicmonitor.Domains

Ecto context (business logic):

- `check_domain(name)` — queries ENS, computes status, upserts in DB
- `check_all_domains()` — reads names from config, calls check_domain for each
- `compute_status(expires_at)` — "active" (>30 days), "expiring" (<=30 days), "expired"

## RPC Extension

Add `eth_call/2` to existing `Periodicmonitor.Ethereum.RPC` module for contract calls.

## Mix Task: mix ens.check_expirations

Calls `Periodicmonitor.Domains.check_all_domains()`, prints results to terminal.

## Hashing

Uses `:crypto.hash(:keccak_256, data)` from OTP 27 — no extra dependencies.

## Tests

- `Periodicmonitor.Ethereum.ENS` — mock RPC calls, test response decoding
- `Periodicmonitor.Domains` — test status logic, DB upsert
- Mix task — test output
