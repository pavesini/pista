export async function getFraudDetectionResponse() {
  return {
    results: [
      {
        transaction_ids: ["tx-002"],
        level: "medium",
        explanation: "Large transfer",
        attestation: "potential_money_laundering",
      },
    ],
    tee_verified: true,
  };
}
