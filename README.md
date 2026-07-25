# PISTA
_**P**reventive **I**nvestigation **S**ystem for **T**ransaction **A**uditing_

---

PISTA is an off-chain intelligence layer that monitors smart contract activity in near real time and takes on-chain action when risk is detected. It solves the problem that smart contracts operate in isolation without broader context about user behavior, market conditions, or coordinated attacks.  

## The problem

Smart contracts operate in a vacuum. They can enforce rules about who calls them and when, but they have no awareness of **broader context**: 
- a user's history across protocols,
- unusual market conditions,
- coordinated exploitation patterns, or 
- slow-drain attacks that only become visible when looking at aggregate behavior over time. 


The pain:
> Encoding complex, evolving detection logic directly in Solidity 
is prohibitively expensive and rigid  by the time you update the contract, the attack has already moved on.

## Possible applications

- Eforcing **AML** rules for exchanges
- Enforce compliance with regulations like **MICAr**
- Stop novel attacks on protocols and smart contract
- Outsource complex logic that might need to adapt o change over time to an off-chain trusted ruleset
- Leverage **AI monitoring** on contract/user behaveyour


## How PISTA works

PISTA subscribes to smart contract events across any number of protocols and/or general blockchain data.
A **substream** (developed via **substream-devs** skill) collects all blocks, parses them and stores relevant data into **Clickhouse** database.


The data is then fed to an AI agent that evaluates relevant updates against baselines and adaptive policies. Should a suspicious activity be detected, response actions are triggered. Those may include both on-chain and off-chain actions like:
- pausing a contract (or any other state change the contract supports) 
- blacklisting an address
- transfer funds
- trade funds on a DEX
- send an email/alert
- lock credit card transfers

etcetera.

![Diagram 1](Docs/Diagram_2.png)

## Why this matters

- **Works on contracts you don't own.** PISTA doesn't require protocol teams to integrate or deploy anything. It acts as an independent safety layer that any user, DAO, or protocol can run.
- **Adaptive, not static.** Rules are not hardcoded. The system learns what "normal" looks like for a user or a population of users, and adapts as conditions change  a bull market behaves differently from a bear market, and PISTA adjusts accordingly.
- **Catches novel attacks.** Because it flags deviation from baseline behavior rather than matching known signatures, PISTA can detect zero-day exploits, new fraud patterns, and emerging attack vectors that signature-based systems miss.
- **No on-chain cost for intelligence.** All computation happens off-chain. The EVM is only used for the final action, keeping gas costs minimal while enabling arbitrarily complex analysis.
- **Cross-protocol visibility.** A single PISTA instance can monitor activity across multiple contracts and protocols simultaneously, correlating signals that no individual contract could see on its own.
- **Near real-time response.** Events are processed as they land. Between detection and action, the window is narrow, not the days or weeks it takes for governance proposals or manual intervention.


- **Demo Smart contract**: a dummy mast contract is used for the demo. It simply allows EOA users to increment a counter unless some external adminitrator stops the contract.
See [dedicated README.md](SmartContract/README.md)




# Preventive Investigation System for Transaction Auditing

## Repository layout

```
pista/
  stream/     Substreams package: aggregates each Ethereum block into a
              FraudData row of fraud-relevant signals, against a local
              Firehose dev chain
```

## End-to-end flow

```
docker-compose (local geth --dev + Firehose/Substreams tier1 + ClickHouse)
        │  Ethereum blocks
        ▼
substreams-sink-sql from-proto  (stream/, module: extract_fraud_relevant_data)
        │  one FraudData row per block
        ▼
ClickHouse (fraud_data table)
```

Full detail on the module lives in `stream/README.md`. What follows is the
complete run sequence, start to finish.

### 1. Bring up the local dev chain and ClickHouse

```bash
cd stream
docker compose up -d
docker compose ps   # wait until ethereum-dev-node AND clickhouse show "healthy"
```

`fund-address` runs automatically once the node is up, sending 10000 ETH from
the node's auto-unlocked dev account to 10 well-known Hardhat/Anvil addresses
— useful for giving the smoke test some non-trivial transactions to see.

### 2. Build the substream

```bash
# still in stream/
substreams build   # use v1.17.11 of the substreams CLI — see stream/README.md
```

### 3. Get the `substreams-sink-sql` CLI

**Use v4.11.3, not latest** — same `s2` gRPC compression issue as the
`substreams` CLI note in `stream/README.md`; releases from v4.12.0 onward
don't work against this stack's local Firehose build.

```bash
# download the v4.11.3 release binary directly:
# https://github.com/streamingfast/substreams-sink-sql/releases/tag/v4.11.3
```

### 4. Run the full pipeline

```bash
# still in stream/
substreams-sink-sql from-proto \
  "clickhouse://default:dev@localhost:19000/default" \
  ./substreams.yaml extract_fraud_relevant_data \
  -e localhost:9000 --plaintext \
  -s 0
```

This tails continuously (no `-t` stop-block): every block substreams
processes gets mapped to a `FraudData` row and inserted into ClickHouse's
`fraud_data` table, batched (25 blocks by default — pass
`--block-batch-size=1` on a short smoke-test range so rows appear
immediately).

### 5. Verify

```bash
docker compose exec clickhouse clickhouse-client --password dev --query \
  "SELECT block_number, total_transactions, contract_creation_count, block_interval_seconds FROM fraud_data ORDER BY block_number DESC LIMIT 10 FORMAT PrettyCompact"
```

### Tear down

```bash
cd stream
docker compose down   # add -v to also wipe dev-chain state and ClickHouse data
```

## Status

- Substreams module: computes the full `FraudData` aggregate (gas
  utilization, failed/reverted-tx and dust/stablecoin signals, priority
  fees, contract-creation/delegation activity) per block and has been
  smoke-tested against the local dev chain (see `stream/README.md`).
- ClickHouse sink: wired up via `substreams-sink-sql`'s `from-proto` mode —
  table DDL is generated straight from the `schema.table` /
  `clickhouse_table_options` annotations in `stream/proto/aggregate.proto`,
  no hand-written `schema.sql`.

## Running against a real testnet (Sepolia) instead of the local dev chain

Everything above runs against the local `docker-compose` Firehose stack. This
section covers the alternative: pointing the same substream + ClickHouse
sink at real Ethereum **Sepolia** via a hosted Substreams endpoint. You do
**not** need `docker compose`'s `ethereum-dev-node` for this flow (you can
still use its `clickhouse` service, or run ClickHouse separately) — a hosted
endpoint replaces the local Firehose node entirely.

This is also the network the aggregate's `stablecoin_volume_usd` field is
tuned for — `stream/src/lib.rs`'s stablecoin allowlist uses Sepolia
contract addresses (Circle's official Sepolia USDC and a Sepolia faucet
DAI), so that field only ever reads non-zero data when running against
Sepolia, not the local dev chain.

### Why a hosted endpoint, not your own Firehose node

`docker-compose.yml`'s local stack works because `--dev` mode gives you a tiny,
instantly-synced chain. Running your own Firehose reader-node for Sepolia
means syncing a real chain's full history — a much bigger undertaking. The
practical path is to use a Substreams endpoint hosted by The Graph, which
already has Sepolia fully indexed.

### Prerequisites

1. **A Substreams API key** — https://thegraph.market, then either:
   ```bash
   substreams auth   # interactive login, stores the token locally
   ```
   or `export SUBSTREAMS_API_KEY=<key>`.
2. **A Sepolia RPC endpoint**, if you want to generate your own traffic to
   watch — e.g. from Infura, Alchemy, or a public Sepolia RPC.
3. **Sepolia testnet ETH** for that account — e.g. from
   https://sepoliafaucet.com or your RPC provider's own faucet.
4. **A running ClickHouse instance** — either `docker compose up -d
   clickhouse` from `stream/` (no need for `ethereum-dev-node` in this flow),
   or your own.

### 1. Run the substream against Sepolia

```bash
cd stream

substreams-sink-sql from-proto \
  "clickhouse://default:dev@localhost:19000/default" \
  ./substreams.yaml extract_fraud_relevant_data \
  -e sepolia --network sepolia \
  -s <RECENT_BLOCK_NUMBER>
```

Notes:
- `-e sepolia --network sepolia` resolves to The Graph's hosted Sepolia
  endpoint (requires the auth from step 1 above).
- **Set `-s` to a recent block**, not `0` — Sepolia is a real chain with
  millions of blocks; starting from genesis forces a full historical scan.
- If you hit `rpc error: ... unknown compression "s2"` (the same issue
  documented in `stream/README.md` for the local dev chain), it's specific to
  that old local Firehose build and shouldn't occur against The Graph's
  hosted endpoints — but if it does, swap to the `substreams-1.20.2` binary
  installed alongside the pinned `v1.17.11` one.

### Summary of what's different vs. the local dev flow

| | Local dev | Sepolia |
|---|---|---|
| Chain source | `docker compose` local Firehose | The Graph hosted Substreams endpoint |
| Auth | none (`--plaintext`, local) | `SUBSTREAMS_API_KEY` / `substreams auth` |
| Endpoint flag | `-e localhost:9000 --plaintext` | `-e sepolia --network sepolia` |
| Start block | `0` (tiny dev chain) | a recent block, not genesis |
| `stablecoin_volume_usd` | always `0` (no stablecoins deployed) | non-zero when the allowlisted contracts see `Transfer` activity |
| ClickHouse sink | identical | identical |

## Further/Future developemet

Due to time constraints the demo is done on a simple contract, but further developement might include:
- monitoring of complex contracts
- monitoring of stablecoin contracts (USDC, USDT EURC...)
- monitoring of all stablecoins pegged to the same fiat asset
- monitoring of assets across multiple chains
- monitoring cross-chain bridges

