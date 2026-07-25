# PISTA
Preventive Investigation System for Transaction Auditing

---

PISTA is an off-chain intelligence layer that monitors smart contract activity and takes on-chain action when risk is detected. It solves the problem that smart contracts operate in isolation without broader context about user behavior, market conditions, or coordinated attacks.  

## The problem

Smart contracts operate in a vacuum. They can enforce rules about who calls them and when, but they have no awareness of broader context: a user's history across protocols, unusual market conditions, coordinated exploitation patterns, or slow-drain attacks that only become visible when looking at aggregate behavior over time. Encoding complex, evolving detection logic directly in Solidity is prohibitively expensive and rigid  by the time you update the contract, the attack has already moved on.

## How PISTA works

PISTA subscribes to smart contract events across any number of protocols, feeds them into an AI/rule engine that evaluates behavior against baselines and adaptive policies, and when conditions warrant takes direct on-chain action: pausing a contract, blacklisting an address, triggering a fund transfer, or any other state change the contract supports.

## Why this matters

- **Works on contracts you don't own.** PISTA doesn't require protocol teams to integrate or deploy anything. It acts as an independent safety layer that any user, DAO, or protocol can run.
- **Adaptive, not static.** Rules are not hardcoded. The system learns what "normal" looks like for a user or a population of users, and adapts as conditions change  a bull market behaves differently from a bear market, and PISTA adjusts accordingly.
- **Catches novel attacks.** Because it flags deviation from baseline behavior rather than matching known signatures, PISTA can detect zero-day exploits, new fraud patterns, and emerging attack vectors that signature-based systems miss.
- **No on-chain cost for intelligence.** All computation happens off-chain. The EVM is only used for the final action, keeping gas costs minimal while enabling arbitrarily complex analysis.
- **Cross-protocol visibility.** A single PISTA instance can monitor activity across multiple contracts and protocols simultaneously, correlating signals that no individual contract could see on its own.
- **Near real-time response.** Events are processed as they land. Between detection and action, the window is narrow, not the days or weeks it takes for governance proposals or manual intervention.





---

## Further documentation

- **Demo Smart contract**: a dummy mast contract is used for the demo. It simply allows EOA users to increment a counter unless some external adminitrator stops the contract.
See [dedicated README.md](SmartContract/README.md)





# Preventive Investigation System for Transaction Auditing

## Repository layout

```
pista/
  stream/     Substreams package: filters Ethereum transactions where
              tx.from == a given address, against a local Firehose dev chain
  zg-sink/    Go sink: consumes the substream's output and batches it into
              0G Storage (decentralized storage network)
```

## End-to-end flow

```
docker-compose (local geth --dev + Firehose/Substreams tier1)
        │  Ethereum blocks
        ▼
substreams run  (stream/, module: map_transactions_from)
        │  jsonl, one line per block with matches
        ▼
zg-sink  (zg-sink/)
        │  batched KV writes (N records or T seconds, whichever first)
        ▼
0G Storage (Galileo testnet, KV store)
```

Full detail on each stage lives in `stream/README.md` and `zg-sink/README.md`.
What follows is the complete run sequence, start to finish.

### 1. Bring up the local dev chain

```bash
cd stream
docker compose up -d
docker compose ps   # wait until ethereum-dev-node shows "healthy"
```

`fund-address` runs automatically once the node is up, sending 10000 ETH from
the node's auto-unlocked dev account to 10 well-known Hardhat/Anvil addresses.

Get the dev account's address (this is the `from` you'll filter on):

```bash
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' \
  http://localhost:8545
```

### 2. Build the substream

```bash
# still in stream/
substreams build   # use v1.17.11 of the substreams CLI — see stream/README.md
```

### 3. Build the 0G sink

```bash
cd ../zg-sink
go build -o zg-sink .
cd ..
```

### 4. Get a funded 0G testnet account

1. Generate or reuse an EVM-compatible private key.
2. Fund it at https://faucet.0g.ai (0.1 0G/day per wallet).
3. Pick any 32-byte hex value as your `ZG_STREAM_ID` tag (no on-chain
   registration needed — it's just a label used to group/replay KV entries).

### 5. Run the full pipeline

```bash
export ZG_PRIVATE_KEY=<your testnet private key>
export ZG_STREAM_ID=<your chosen 32-byte hex tag>

cd stream
substreams run substreams.yaml map_transactions_from \
  -e localhost:9000 --plaintext \
  -p map_transactions_from=<ADDRESS_FROM_STEP_1> \
  -s 0 \
  -o jsonl | ../zg-sink/zg-sink
```

This tails continuously (no `-t` stop-block): every matched transaction
substreams emits gets buffered by `zg-sink` and flushed to 0G Storage once
`ZG_BATCH_SIZE` records accumulate (default 10) or `ZG_BATCH_INTERVAL` elapses
(default 30s), whichever comes first — see "Why batched, not one write per
transaction" in `zg-sink/README.md` for why a literal one-write-per-tx model
isn't viable on 0G.

### 6. Verify

- `zg-sink` logs each successful flush with the 0G transaction hash:
  `flushed 10 transactions to 0G Storage, tx=0x...`
- Check it on the Storage Explorer: https://storagescan-galileo.0g.ai
- Read a specific record back with the `0g-storage-client` CLI's `kv-read`
  against the same `ZG_STREAM_ID` and a known tx hash as the key.

### Tear down

```bash
cd stream
docker compose down   # add -v to also wipe dev-chain state
```

## Status

- Substreams module: built and smoke-tested against the local dev chain
  (see `stream/README.md`).
- 0G sink: built and verified against the real 0G testnet indexer/RPC up to
  the transaction-submission step (confirmed with an unfunded key — reached
  "insufficient funds", proving everything upstream of signing works).
  End-to-end write-and-read-back with a funded key is the one remaining step.

## Running against a real testnet (Sepolia) instead of the local dev chain

Everything above runs against the local `docker-compose` Firehose stack. This
section covers the alternative: deploying your own contract to **Ethereum
Sepolia** and pointing the same substream + 0G sink at it via a hosted
Substreams endpoint. You do **not** need `docker compose` for this flow — it
replaces the local Firehose node entirely.

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
2. **A Sepolia RPC endpoint** for deploying your contract — e.g. from
   Infura, Alchemy, or a public Sepolia RPC.
3. **Sepolia testnet ETH** for the deployer account — e.g. from
   https://sepoliafaucet.com or your RPC provider's own faucet.
4. **Foundry** (for the example deployment) — https://getfoundry.sh:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
   Any other deployment tool (Hardhat, Remix) works the same way — you just
   need the deployer's address at the end.

### 1. Deploy an example contract to Sepolia

```bash
forge init example-contract
cd example-contract

forge create --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast src/Counter.sol:Counter
```

(`forge init` scaffolds a trivial `Counter.sol` by default — fine for this
purpose, since we're tracking the *deployer's* transactions, not the
contract's logic.)

Note the output: **deployer address**, **deployed contract address**, and
**block number** of the deployment transaction.

**Important caveat carried over from earlier design decisions:** our
`map_transactions_from` module filters on `tx.from` — the transaction
*sender*. A contract address can never be a `from` (only an EOA signs
transactions), so track the **deployer's EOA address**, not the contract
address, to see the deployment transaction and anything else that account
sends. Tracking activity *into* the contract, or the contract's own internal
calls, would need a different filter (`to` matching, or trace decoding) —
not what's built here.

### 2. Run the substream against Sepolia

```bash
cd stream

substreams run substreams.yaml map_transactions_from \
  -e sepolia --network sepolia \
  -p map_transactions_from=<DEPLOYER_EOA_ADDRESS> \
  -s <BLOCK_NUMBER_FROM_STEP_1> \
  -o jsonl | ../zg-sink/zg-sink
```

Notes:
- `-e sepolia --network sepolia` resolves to The Graph's hosted Sepolia
  endpoint and uses Sepolia's `initialBlock`/param resolution — no edits to
  `substreams.yaml` needed (it still says `network: mainnet`, which is only a
  placeholder; `--network` overrides it at run time).
- **Set `-s` at or just before the deployment block**, not `0` — Sepolia is a
  real chain with millions of blocks; starting from genesis forces a full
  historical scan instead of picking up from where your contract exists.
- If you hit `rpc error: ... unknown compression "s2"` (the same issue
  documented in `stream/README.md` for the local dev chain), it's specific to
  that old local Firehose build and shouldn't occur against The Graph's
  hosted endpoints — but if it does, swap to the `substreams-1.20.2` binary
  installed alongside the pinned `v1.17.11` one.

### 3. 0G sink side — unchanged

`zg-sink` doesn't care whether the jsonl came from the local dev chain or
Sepolia — same `ZG_PRIVATE_KEY`/`ZG_STREAM_ID` setup as above.

### Summary of what's different vs. the local dev flow

| | Local dev | Sepolia |
|---|---|---|
| Chain source | `docker compose` local Firehose | The Graph hosted Substreams endpoint |
| Auth | none (`--plaintext`, local) | `SUBSTREAMS_API_KEY` / `substreams auth` |
| Endpoint flag | `-e localhost:9000 --plaintext` | `-e sepolia --network sepolia` |
| Start block | `0` (tiny dev chain) | at/near your deployment block |
| Tracked address | one of the 10 `fund-address` recipients, or the dev account | your own deployer EOA |
| 0G sink | identical | identical |
