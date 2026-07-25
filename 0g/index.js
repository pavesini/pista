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

    console.log(`Found ${transactions.length} transactions!`);

    const prompt = `
      Act as an AML and fraud detection agent.

      Analyze the following transactions and identify only those that may involve:
      - fraud;
      - money laundering;
      - other suspicious activity.

      Return ONLY valid JSON. Do not include Markdown, comments, or additional text.

      Use exactly this structure:

      {
        "results": [
          {
            "transaction_ids": ["string"],
            "level": "low",
            "explanation": "two or three words",
          }
        ]
      }

      Rules:
      - "transaction_ids" must contain the suspicious transaction IDs.
      - "level" must be exactly one of: "low", "medium", "high".
      - "explanation" must contain exactly two or three words.
      - "attestation" must be exactly one of:
        "potential_fraud",
        "potential_money_laundering",
        "other_suspicious_activity".
      - Group transactions together when they share the same suspicious pattern.
      - If no suspicious activity is detected, return:
        { "results": [] }

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
    const suspiciousTransactions = parseFraudDetectionResponse(response);

    if (!suspiciousTransactions.length)
      console.log("No possible frauds detected")
    else {
      console.log(JSON.stringify(results, null, 2));
    }
  } catch (error) {
    console.error("Pipeline failed:", error);
    process.exitCode = 1;
  } finally {
    await closeClickHouse();
  }

  function parseFraudDetectionResponse(response) {
    const content = response.choices[0].message.content;

    const cleanedContent = content
      .trim()
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    const parsed = JSON.parse(cleanedContent);

    if (!parsed || !Array.isArray(parsed.results)) {
      throw new Error("Invalid fraud detection response format");
    }

    return parsed.results;
  }
}

main();
