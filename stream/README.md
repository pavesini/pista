# pista_wallet_transactions

Aggregates each Ethereum block into a `FraudData` row of fraud-relevant signals
(gas utilization, failed/reverted-tx patterns, dust and stablecoin volume,
priority fees, contract-creation/delegation activity, etc.) and streams it into
ClickHouse.

## Overview

A Substreams pipeline with two modules: a small `store` module that tracks the
previous block's timestamp (needed to compute the interval between blocks),
and a `map` module that scans every transaction in the block and emits one
`pista.aggregate.v1.FraudData` row per block. Built against the local
Firehose/Substreams dev chain started by `docker-compose.yml` in this repo
(`geth --dev`, tier1 gRPC on `localhost:9000`). Output is persisted to
ClickHouse via `substreams-sink-sql`'s `from-proto` mode — no `schema.sql` to
maintain, the table DDL is generated from the annotations in
`proto/aggregate.proto`.

## Modules

| Module | Kind | Output | Description |
|---|---|---|---|
| `store_block_interval` | store | `int64` | Tracks the current block's timestamp so the next block can compute the gap between them |
| `extract_fraud_relevant_data` | map | `pista.aggregate.v1.FraudData` | Emits one fraud-signal aggregate row per block |

## Prerequisites

- `substreams` CLI — **use v1.17.11, not latest.** CLI releases from Feb 2026 onward
  (v1.18+) hardcode `s2` gRPC compression on the client with no override flag; the
  `fh3.0` firehose/tier1 build bundled in this repo's `docker-compose.yml` only
  supports `zstd`/`gzip` and rejects the request outright
  (`rpc error: ... unknown compression "s2"`). v1.17.11 predates that change and
  works against this stack.
- `substreams-sink-sql` — **use v4.11.3, not v4.13.x/latest.** Same root
  cause as the CLI note above: `substreams-sink-sql` releases from
  v4.12.0/Feb 2026 onward hit the same `unknown compression "s2"` error
  against this stack's `fh3.0` firehose/tier1 build. v4.11.3
  (https://github.com/streamingfast/substreams-sink-sql/releases/tag/v4.11.3)
  predates that change and was used for this repo's smoke test; from-proto
  mode itself is unaffected by the version difference.
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
  -s 0 -t +50
```

## Running the smoke test end-to-end

These are the exact steps used to verify the pipeline against the local dev chain.

1. **Bring up the local Firehose/Substreams stack and ClickHouse** (from this directory):

   ```bash
   docker compose up -d
   docker compose ps   # wait until ethereum-dev-node and clickhouse show "healthy"
   ```

2. **Confirm `fund-address` ran.** It sends 10000 ETH from the dev node's
   auto-unlocked account to 10 well-known Hardhat/Anvil addresses, once per
   startup (`restart: on-failure`, so it may retry a couple of times before the
   node's IPC socket is ready — that's expected):

   ```bash
   docker compose logs fund-address
   docker inspect stream-fund-address-1 --format '{{.State.Status}} {{.State.ExitCode}}'
   # -> "exited 0" once it has succeeded
   ```

   Those funding transactions are what give the smoke test some non-trivial
   `total_transactions` / `total_value_wei` / `unique_receivers` to check.

3. **Build and run the sink**, against a short range so the test finishes fast:

   ```bash
   substreams build

   substreams-sink-sql from-proto \
     "clickhouse://default:dev@localhost:19000/default" \
     ./substreams.yaml extract_fraud_relevant_data \
     -e localhost:9000 --plaintext \
     -s 0 -t +50 \
     --block-batch-size=1
   ```

   `--block-batch-size=1` forces a flush after every block — the default (25)
   won't flush at all over a 50-block smoke range.

4. **Verify the output** — one row per block, e.g.:

   ```bash
   docker compose exec clickhouse clickhouse-client --password dev --query \
     "SELECT block_number, total_transactions, unique_receivers, total_value_wei, contract_creation_count FROM fraud_data ORDER BY block_number LIMIT 10 FORMAT PrettyCompact"
   ```

   Expect `total_transactions`/`unique_receivers` to jump on the block(s)
   containing the `fund-address` transfers (10 recipients, one `fund-address`
   run per `docker compose up`), and `block_interval_seconds` to read `0` on
   the very first row and ~1s afterward (the dev chain mines with
   `--dev.period=1`).

5. **Tear down** when done: `docker compose down` (add `-v` to also wipe the
   dev chain's state and the ClickHouse data volume, so the next run starts
   fresh).

## Notes on the aggregate fields

A few fields encode assumptions worth knowing about if the numbers look
surprising:

- **`dust_tx_count`** — non-zero transfers under `0.0001 ETH` (a hardcoded
  threshold in `src/lib.rs`).
- **`stablecoin_volume_usd`** — sums ERC-20 `Transfer` events from a small
  hardcoded allowlist of **Sepolia testnet** stablecoins (Circle's official
  Sepolia USDC and a common Sepolia faucet DAI), assuming 1 token ≈ 1 USD.
  Against the local dev chain (no such contracts deployed) this reads `0` —
  it's only meaningful once the pipeline runs against Sepolia itself (see
  the root README's "Running against a real testnet" section).
- **`top_reverting_contract`** / **`top_reverting_distinct_senders`** — among
  failed/reverted transactions in the block, the `to` address with the most
  *distinct* senders; ties go to whichever address appears first in the
  block's transaction order.
- **`duplicate_bytecode_creation_count`** — count of contract-creation
  transactions in the block whose init code matches at least one other
  creation transaction's init code in the same block.
- **`priority_fee_p50_gwei`** / **`priority_fee_max_gwei`** — derived from
  each transaction's effective `gas_price` minus the block's
  `base_fee_per_gas` (clamped at 0), which is how Firehose/Substreams reports
  the price actually paid regardless of transaction type — median and max
  across the block's transactions.
