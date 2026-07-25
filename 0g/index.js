import "dotenv/config";
import OpenAI from "openai";
import { execSync } from "child_process";
import { closeClickHouse, fetchTransactions } from "./clickhouse/clickhouse.js";
import { getFraudDetectionResponse } from "./ai/ai.js";

async function main() {
  try {
    const transactions = await fetchTransactions();

    if (transactions.length === 0) {
      console.log("No transactions found");
      return;
    }

    console.log(`Found ${transactions.length} transactions!`);

    const fraudDetectionResponse = await getFraudDetectionResponse(transactions);

    if (!fraudDetectionResponse.results.length) {
      console.log("✅ No possible frauds detected");
    } else {
      console.log("🚨 Possible fraud detected!");
      console.log(
        `🔐 TEE verified: ${fraudDetectionResponse.tee_verified ? "✅ Yes" : "❌ No"}`
      );

      fraudDetectionResponse.results.forEach((result, index) => {
        console.log(`\n🔎 Suspicious result #${index + 1}`);
        console.log(`   🆔 Transaction IDs: ${result.transaction_ids.join(", ")}`);
        console.log(`   ⚠️  Risk level: ${result.level.toUpperCase()}`);
        console.log(`   💬 Explanation: ${result.explanation}`);
        console.log(`   📌 Attestation: ${result.attestation}`);
      });
    }

    const shouldPause = suspiciousTransactions.results.length > 0 ? "true" : "false";
    execSync(`./pause_tx.sh ${shouldPause}`);
  } catch (error) {
    console.error("Pipeline failed:", error);
    process.exitCode = 1;
  } finally {
    await closeClickHouse();
  }
}

main();
