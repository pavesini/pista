# PISTA
Preventive Investigation System for Transaction Auditing

---

PISTA is an off-chain intelligence layer that monitors smart contract activity and takes on-chain action when risk is detected. It solves the problem that smart contracts operate in isolation without broader context about user behavior, market conditions, or coordinated attacks.  

## The problem

Smart contracts operate in a vacuum. They can enforce rules about who calls them and when, but they have no awareness of broader context: a user's history across protocols, unusual market conditions, coordinated exploitation patterns, or slow-drain attacks that only become visible when looking at aggregate behavior over time. Encoding complex, evolving detection logic directly in Solidity is prohibitively expensive and rigid  by the time you update the contract, the attack has already moved on.

## How PISTA works

PISTA subscribes to smart contract events across any number of protocols, feeds them into an AI/rule engine that evaluates behavior against baselines and adaptive policies, and when conditions warrant takes direct on-chain action: pausing a contract, blacklisting an address, triggering a fund transfer, or any other state change the contract supports.

## Why this matters

- **Works on contracts you don't own.** PISTA doesn't require protocol teams to integrate or deploy anything. It acts as an independent safety layer that any user, DAO, or protocol can run.
- **Adaptive, not static.** Rules are not hardcoded. The system learns what "normal" looks like for a user or a population of users, and adapts as conditions change  a bull market behaves differently from a bear market, and PISTA adjusts accordingly.
- **Catches novel attacks.** Because it flags deviation from baseline behavior rather than matching known signatures, PISTA can detect zero-day exploits, new fraud patterns, and emerging attack vectors that signature-based systems miss.
- **No on-chain cost for intelligence.** All computation happens off-chain. The EVM is only used for the final action, keeping gas costs minimal while enabling arbitrarily complex analysis.
- **Cross-protocol visibility.** A single PISTA instance can monitor activity across multiple contracts and protocols simultaneously, correlating signals that no individual contract could see on its own.
- **Near real-time response.** Events are processed as they land. Between detection and action, the window is narrow, not the days or weeks it takes for governance proposals or manual intervention.





---

## Further documentation

- **Demo Smart contract**: a dummy mast contract is used for the demo. It simply allows EOA users to increment a counter unless some external adminitrator stops the contract.
See [dedicated README.md](SmartContract/README.md)