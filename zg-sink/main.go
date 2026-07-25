// zg-sink reads newline-delimited JSON from stdin (the output of
// `substreams run ... -o jsonl`) and batches matched transactions into
// periodic 0G Storage KV writes.
package main

import (
	"bufio"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/0gfoundation/0g-storage-client/common/blockchain"
	"github.com/0gfoundation/0g-storage-client/indexer"
	"github.com/0gfoundation/0g-storage-client/kv"
	"github.com/0gfoundation/0g-storage-client/transfer"
	"github.com/ethereum/go-ethereum/common"
)

type config struct {
	privateKey    string
	streamID      common.Hash
	evmRPC        string
	indexerURL    string
	batchSize     int
	batchInterval time.Duration
}

func loadConfig() (config, error) {
	pk := os.Getenv("ZG_PRIVATE_KEY")
	if pk == "" {
		return config{}, fmt.Errorf("ZG_PRIVATE_KEY is required")
	}

	streamIDRaw := os.Getenv("ZG_STREAM_ID")
	if streamIDRaw == "" {
		return config{}, fmt.Errorf("ZG_STREAM_ID is required")
	}
	streamID, err := parseStreamID(streamIDRaw)
	if err != nil {
		return config{}, err
	}

	batchSize := 10
	if v := os.Getenv("ZG_BATCH_SIZE"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return config{}, fmt.Errorf("ZG_BATCH_SIZE must be a positive integer, got %q", v)
		}
		batchSize = n
	}

	batchInterval := 30 * time.Second
	if v := os.Getenv("ZG_BATCH_INTERVAL"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d <= 0 {
			return config{}, fmt.Errorf("ZG_BATCH_INTERVAL must be a positive duration (e.g. 30s), got %q", v)
		}
		batchInterval = d
	}

	return config{
		privateKey:    pk,
		streamID:      streamID,
		evmRPC:        getenvDefault("ZG_EVM_RPC", "https://evmrpc-testnet.0g.ai"),
		indexerURL:    getenvDefault("ZG_INDEXER", "https://indexer-storage-testnet-turbo.0g.ai"),
		batchSize:     batchSize,
		batchInterval: batchInterval,
	}, nil
}

func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// parseStreamID validates and decodes a 32-byte hex stream tag. Unlike
// common.HexToHash (which silently pads/truncates), this rejects the wrong
// length so a malformed ZG_STREAM_ID fails fast instead of silently tagging
// data under the wrong stream.
func parseStreamID(s string) (common.Hash, error) {
	trimmed := strings.TrimPrefix(strings.TrimPrefix(s, "0x"), "0X")
	if len(trimmed) != 64 {
		return common.Hash{}, fmt.Errorf("ZG_STREAM_ID must be 32 bytes (64 hex chars), got %d chars", len(trimmed))
	}
	if _, err := hex.DecodeString(trimmed); err != nil {
		return common.Hash{}, fmt.Errorf("ZG_STREAM_ID is not valid hex: %w", err)
	}
	return common.HexToHash(s), nil
}

// Transaction mirrors pista.transactions.v1.Transaction's proto3 JSON
// encoding: uint64 fields (block_number, block_timestamp, nonce) render as
// JSON strings, uint32 (index) renders as a number, and zero-valued fields
// are omitted entirely.
type Transaction struct {
	BlockNumber    string `json:"blockNumber"`
	BlockTimestamp string `json:"blockTimestamp"`
	TxHash         string `json:"txHash"`
	From           string `json:"from"`
	To             string `json:"to"`
	Value          string `json:"value"`
	Nonce          string `json:"nonce"`
	Index          uint32 `json:"index"`
}

type substreamOutput struct {
	Module string `json:"@module"`
	Block  uint64 `json:"@block"`
	Data   struct {
		Transactions []Transaction `json:"transactions"`
	} `json:"@data"`
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("config error: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	w3client := blockchain.MustNewWeb3(cfg.evmRPC, cfg.privateKey)
	defer w3client.Close()

	indexerClient, err := indexer.NewClient(cfg.indexerURL, indexer.IndexerClientOption{})
	if err != nil {
		log.Fatalf("failed to create indexer client: %v", err)
	}

	selectedNodes, err := indexerClient.SelectNodes(ctx, 1, []string{}, "random", false)
	if err != nil {
		log.Fatalf("failed to select storage nodes: %v", err)
	}
	log.Printf("selected %d trusted, %d discovered storage nodes", len(selectedNodes.Trusted), len(selectedNodes.Discovered))

	lines := make(chan string)
	go func() {
		defer close(lines)
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Buffer(make([]byte, 0, 64*1024), 10*1024*1024)
		for scanner.Scan() {
			lines <- scanner.Text()
		}
		if err := scanner.Err(); err != nil {
			log.Printf("stdin read error: %v", err)
		}
	}()

	ticker := time.NewTicker(cfg.batchInterval)
	defer ticker.Stop()

	var buffer []Transaction

	flush := func() {
		if len(buffer) == 0 {
			return
		}
		n := len(buffer)
		batcher := kv.NewBatcher(math.MaxUint64, selectedNodes, w3client)
		for _, tx := range buffer {
			payload, err := json.Marshal(tx)
			if err != nil {
				log.Printf("skip tx %s: marshal error: %v", tx.TxHash, err)
				continue
			}
			batcher.Set(cfg.streamID, []byte(tx.TxHash), payload)
		}

		txHash, err := batcher.Exec(ctx, transfer.UploadOption{
			ExpectedReplica: 1,
			Method:          "random",
		})
		if err != nil {
			log.Printf("flush failed, keeping %d transactions buffered for retry: %v", n, err)
			return
		}
		log.Printf("flushed %d transactions to 0G Storage, tx=%s", n, txHash.Hex())
		buffer = buffer[:0]
	}

	log.Printf("zg-sink started: stream=%s batch_size=%d batch_interval=%s", cfg.streamID.Hex(), cfg.batchSize, cfg.batchInterval)

	for {
		select {
		case <-ctx.Done():
			log.Println("shutting down, flushing remaining buffer")
			flush()
			return
		case line, ok := <-lines:
			if !ok {
				log.Println("stdin closed, flushing remaining buffer")
				flush()
				return
			}
			var out substreamOutput
			if err := json.Unmarshal([]byte(line), &out); err != nil {
				log.Printf("skip malformed line: %v", err)
				continue
			}
			buffer = append(buffer, out.Data.Transactions...)
			if len(buffer) >= cfg.batchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		}
	}
}
