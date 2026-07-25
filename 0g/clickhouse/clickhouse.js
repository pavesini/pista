import "dotenv/config";
import { createClient } from "@clickhouse/client";

const clickhouse = createClient({
  url: process.env.CLICKHOUSE_URL,
  username: process.env.CLICKHOUSE_USERNAME,
  password: process.env.CLICKHOUSE_PASSWORD,
  database: process.env.CLICKHOUSE_DATABASE,
});

function getTableName() {
  const table = process.env.CLICKHOUSE_TABLE;

  if (!table) {
    throw new Error("CLICKHOUSE_TABLE is not configured");
  }

  return table;
}

export async function fetchTransactions(limit = 100) {
  const resultSet = await clickhouse.query({
    query: `
      SELECT *
      FROM ${getTableName()}
      ORDER BY block_timestamp DESC
      LIMIT ${process.env.TRANSACTION_LIMIT}
    `,
    query_params: { limit },
    format: "JSONEachRow",
  });

  return resultSet.json();
}

export async function closeClickHouse() {
  await clickhouse.close();
}
