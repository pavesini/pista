# zg-sink

Reads newline-delimited JSON from stdin — the output of `substreams run ... -o
jsonl` for the `map_transactions_from` module — and batches matched
transactions into periodic writes to 0G Storage's KV store.

## Why batched, not one write per transaction

Every 0G Storage write (file or KV) is an on-chain transaction on 0G's EVM
chain: it costs gas and takes several seconds to confirm. One write per
matched Ethereum transaction isn't practical. This sink instead buffers
records in memory and flushes as a single `kv-write`-equivalent transaction
when either `ZG_BATCH_SIZE` records have accumulated or `ZG_BATCH_INTERVAL`
has elapsed, whichever comes first. On a failed flush (e.g. network hiccup),
the batch stays buffered and is retried on the next trigger rather than
being dropped.

## Configuration (environment variables)

| Variable | Required | Default | Notes |
|---|---|---|---|
| `ZG_PRIVATE_KEY` | yes | — | EVM private key (with or without `0x` prefix) for a funded 0G testnet account. Never commit this. |
| `ZG_STREAM_ID` | yes | — | Any 32-byte hex value (64 hex chars, `0x` prefix optional) you choose to tag this KV stream. No on-chain registration needed. |
| `ZG_EVM_RPC` | no | `https://evmrpc-testnet.0g.ai` | 0G Galileo testnet EVM RPC (dev-only endpoint per 0G's docs). |
| `ZG_INDEXER` | no | `https://indexer-storage-testnet-turbo.0g.ai` | Turbo indexer (faster, pricier). Use `https://indexer-storage-testnet-standard.0g.ai` for the standard (slower, cheaper) network. |
| `ZG_BATCH_SIZE` | no | `10` | Flush after this many buffered records. |
| `ZG_BATCH_INTERVAL` | no | `30s` | Flush after this much time regardless of count (Go duration syntax). |

## One-time setup

1. Generate or reuse an EVM-compatible private key for a throwaway testnet account.
2. Fund it at the faucet: https://faucet.0g.ai (0.1 0G/day per wallet).
3. Pick any 32-byte hex value for `ZG_STREAM_ID` (e.g. derived from the wallet
   address you're tracking).

## Build and run

```bash
cd zg-sink
go build -o zg-sink .
cd ..

export ZG_PRIVATE_KEY=<your testnet private key>
export ZG_STREAM_ID=<your chosen 32-byte hex tag>

# substreams.yaml lives in stream/, zg-sink is a sibling directory, so run
# from stream/ and reference the sink binary by relative path (no -t
# stop-block, so it tails continuously):
cd stream
substreams run substreams.yaml map_transactions_from \
  -e localhost:9000 --plaintext \
  -p map_transactions_from=<ADDRESS> \
  -s 0 \
  -o jsonl | ../zg-sink/zg-sink
```

## Verifying writes landed

Each successful flush logs the 0G transaction hash:
```
2026/01/01 00:00:00 flushed 10 transactions to 0G Storage, tx=0x...
```

Check it on the Storage Explorer: https://storagescan-galileo.0g.ai

To read a specific record back, use the `0g-storage-client` CLI's `kv-read`
against the same `ZG_STREAM_ID` and a known transaction hash as the key.

## Known limitations (first version)

- Storage node selection happens once at startup via the indexer, not
  per-flush. If the initially selected nodes go down mid-run, restart the
  sink to reselect.
- No persistent buffer — an unflushed batch is lost if the process is killed
  (not just SIGINT/SIGTERM, which flush gracefully).
- No de-duplication against previous runs — restarting the upstream
  `substreams run` from an earlier block will re-flush already-seen
  transactions as new KV writes (harmless, just redundant).
