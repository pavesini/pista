import "dotenv/config";
import OpenAI from "openai";

export async function getFraudDetectionResponse(transactions) {
    const demoFraudProbability = parseFloat(process.env.DEMO_FRAUD_PROBABILITY) || 0.3;
    const simulatedFraudDetected = Math.random() < demoFraudProbability;

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
                    "attestation": "potential_fraud"
                }
            ]
        }

        Rules:
        - if simulatedFraudDetcted is true, return at least one suspicious transaction; otherwise, return the correct result
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

        simulatedFraudDetected: ${simulatedFraudDetected}
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
        verify_tee: true,
    });

    if(!response) {
        throw new Error("Error while retrieving ai client response");
    }


    const parsedResponse = parseResponse(response, transactions); 
    return parsedResponse;
}


function parseResponse(response, transactions) {
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

  const lastBlockNumber = transactions[0]?.block_number ?? null;

  return {
    results: parsed.results,
    tee_verified: response.x_0g_trace?.tee_verified ?? false,
    last_block_number: lastBlockNumber,
  };
}
