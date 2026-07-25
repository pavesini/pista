#!/bin/bash

################################################################################
#
#   Pauser Script
#   This script is triggered to pause/unpause the Counter.sol contract
#
################################################################################


PAUSE="$1"

# 2. Convert input to lowercase for case-insensitive checking (requires Bash 4.0+)
PAUSE="${PAUSE,,}"

# 3. Check if the value is "true" or "false"
if [[ "$PAUSE" == "true" || "$PAUSE" == "false" ]]; then
    # Store the validated boolean string in a variable
    echo "Valid boolean"
else
    echo "Error: Provided parameter '$PAUSE' is not a boolean (true/false)."
    exit 1
fi


# --- Configuration ---
RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
CONTRACT_ADDRESS="0x6A1fa9938e2698EA4009E3821CbeF215620f2003"
PRIVATE_KEY="0xd7fc700d6a46c948728c3346a092925865a4710b63d9c13432b2ccc325e8e6fa"
SENDER_ADDRESS="0xBCC03A74ADfebD8383c232F786435661B1eD7eCA"


echo "Sender Address: $SENDER_ADDRESS"

## Extract the current nonce for the address from the blockchain
NONCE=$(cast nonce "$SENDER_ADDRESS" --rpc-url "$RPC_URL")
echo "Fetched Nonce:  $NONCE"

# Create and sign the raw transaction without broadcasting it
# Syntaxes: cast mktx <TO> <SIG> <ARGS...> [OPTIONS]
SIGNED_TX=$(cast mktx "$CONTRACT_ADDRESS" \
  "pause(bool)" $PAUSE \
  --nonce "$NONCE" \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC_URL")

echo -e "\nRaw Signed Tx Hex:"
echo "$SIGNED_TX"

SIGNED_TX=$(echo "$SIGNED_TX" | tr -d '\r\n ')

# 4. Broadcast the signed transaction to the RPC node via CURL
echo -e "\nSending via JSON-RPC..."
curl -X POST \
  -H "Content-Type: application/json" \
  --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"eth_sendRawTransaction\",
    \"params\": [\"$SIGNED_TX\"],
    \"id\": 1
  }" \
  "$RPC_URL"
