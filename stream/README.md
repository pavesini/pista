# pista_wallet_transactions

Filters Ethereum transactions where `tx.from` matches a runtime-provided address.

## Overview

A single Substreams map module that scans each block's transactions and emits the
ones whose `from` field equals an address passed in at run time via a module
param. Built against the local Firehose/Substreams dev chain started by
`docker-compose.yml` in this repo (`geth --dev`, tier1 gRPC on `localhost:9000`).
No sink is wired up yet — output is written to a local file via `substreams run`.

## Modules

| Module | Kind | Output | Description |
|---|---|---|---|
| `map_transactions_from` | map | `pista.transactions.v1.Transactions` | Emits every transaction where `tx.from` == the address passed via `-p` |

## Prerequisites

- `substreams` CLI — **use v1.17.11, not latest.** CLI releases from Feb 2026 onward
  (v1.18+) hardcode `s2` gRPC compression on the client with no override flag; the
  `fh3.0` firehose/tier1 build bundled in this repo's `docker-compose.yml` only
  supports `zstd`/`gzip` and rejects the request outright
  (`rpc error: ... unknown compression "s2"`). v1.17.11 predates that change and
  works against this stack.
- `buf`
- Rust with the `wasm32-unknown-unknown` target (`rustup target add wasm32-unknown-unknown`)
- The local dev chain running: `docker compose up -d` (from this directory)

## Quick Start

```bash
substreams build

# Find the dev node's sender account (fund-address sends FROM this account):
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' \
  http://localhost:8545

substreams run substreams.yaml map_transactions_from \
  -e localhost:9000 --plaintext \
  -p map_transactions_from=<ADDRESS> \
  -s 0 -t +50 \
  -o jsonl > wallet_transactions.jsonl
```

## Running the smoke test end-to-end

These are the exact steps used to verify the module against the local dev chain.

1. **Bring up the local Firehose/Substreams stack** (from this directory):

   ```bash
   docker compose up -d
   docker compose ps   # wait until ethereum-dev-node shows "healthy"
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

3. **Get the dev node's sender address** — this is the `from` you filter on,
   *not* one of the 10 hardcoded recipients:

   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' \
     http://localhost:8545
   ```

4. **Build and run**, writing matches to a file:

   ```bash
   substreams build

   substreams run substreams.yaml map_transactions_from \
     -e localhost:9000 --plaintext \
     -p map_transactions_from=<ADDRESS_FROM_STEP_3> \
     -s 0 -t +400 \
     -o jsonl > wallet_transactions.jsonl
   ```

5. **Verify the output** — expect one JSON line per block containing a match,
   each with 10000 ETH (`10000000000000000000000` wei) transfers from the dev
   account to each of the 10 recipients:

   ```bash
   cat wallet_transactions.jsonl | jq .
   ```

   Sanity-check a specific recipient's on-chain balance matches what the file
   shows (30000 ETH after 3 `fund-address` runs, in this case):

   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","latest"],"id":1}' \
     http://localhost:8545
   ```

6. **Tear down** when done: `docker compose down` (add `-v` to also wipe the
   dev chain's state so the next `fund-address` run starts from a fresh
   funding round).
