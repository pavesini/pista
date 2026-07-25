export async function getFraudDetectionResponse() {
  return {
    results: [
      {
        transaction_ids: ["tx-002"],
        level: "medium",
        explanation: "Large transfer",
      },
    ],
    tee_verified: true,
  };
}
