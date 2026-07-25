export async function fetchTransactions(limit = 100) {
  const transactions = [
    {
      transactionId: "tx-001",
      sender: "0xA123",
      receiver: "0xB456",
      amount: 150,
      currency: "USDC",
      timestamp: new Date().toISOString(),
      type: "TRANSFER",
    },
    {
      transactionId: "tx-002",
      sender: "0xC789",
      receiver: "0xD012",
      amount: 12_500,
      currency: "USDC",
      timestamp: new Date().toISOString(),
      type: "TRANSFER",
    },
    {
      transactionId: "tx-003",
      sender: "0xA123",
      receiver: "0xE345",
      amount: 9_950,
      currency: "USDC",
      timestamp: new Date().toISOString(),
      type: "TRANSFER",
    },
  ];

  return transactions.slice(0, limit);
}

export async function closeClickHouse(params) {
    console.log("closing mock clickhouse")
    return;
}