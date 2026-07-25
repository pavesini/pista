# pista_wallet_transactions

Aggregates each Ethereum block into a `FraudData` row of fraud-relevant signals
(gas utilization, failed/reverted-tx patterns, dust and stablecoin volume,
priority fees, contract-creation/delegation activity, etc.) and streams it into
ClickHouse.

## Overview

A single Substreams `map` module that scans every transaction in the block and
emits an agregate `pista.aggregate.v1.FraudData` row per block. Output is persisted to
ClickHouse via `substreams-sink-sql`'.

## Modules

| Module | Kind | Output | Description |
|---|---|---|---|
| `extract_fraud_relevant_data` | map | `pista.aggregate.v1.FraudData` | Emits one fraud-signal aggregate row per block |

## Prerequisites

- `substreams` CLI
- `substreams-sink-sql` 
- `buf`
- Rust with the `wasm32-unknown-unknown` target (`rustup target add wasm32-unknown-unknown`)
- The local dev chain **and** ClickHouse running: `docker compose up -d` (from this directory)

## Quick Start

```bash
substreams build

docker compose up -d
docker compose ps   # wait until ethereum-dev-node AND clickhouse show "healthy"

# One-time: create the fraud_data table (DDL is generated from proto/aggregate.proto's
# schema.table / clickhouse_table_options annotations).
substreams-sink-sql from-proto \
  "clickhouse://default:dev@localhost:19000/default" \
  ./substreams.yaml extract_fraud_relevant_data \
  -e localhost:9000 --plaintext \
  -s 11348562
```

## Deploy

```bash
 substreams publish pista-wallet-transactions-sepolia-v0.1.1.spkg
```
