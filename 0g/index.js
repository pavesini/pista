import "dotenv/config";
import OpenAI from "openai";
import { closeClickHouse, fetchTransactions } from "./clickhouse/clickhouse.js";

async function main() {
  try {
    const transactions = await fetchTransactions();

    if (transactions.length === 0) {
      console.log("No transactions found");
      return;
    }

    const prompt = `
      Act as an AML agent.

      Analyze the following batch of transactions and identify potential fraud,
      money laundering patterns, or other suspicious activity.

      Return:
      1. A risk level: low, medium, or high.
      2. The suspicious transaction IDs.
      3. A concise explanation.
      4. Recommended follow-up actions.

      Transactions:
      ${JSON.stringify(transactions, null, 2)}
      `;

    const client = new OpenAI({
      baseURL: process.env.ZG_SERVICE_URL,
      apiKey: process.env.ZG_API_SECRET,
    });

    const response = await client.chat.completions.create({
      model: process.env.ZG_MODEL,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
    });
    
    console.log(response.choices[0]?.message?.content);
  } catch (error) {
    console.error("Pipeline failed:", error);
    process.exitCode = 1;
  } finally {
    await closeClickHouse();
  }
}

main();
