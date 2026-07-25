# PISTA
_**P**reventive **I**nvestigation **S**ystem for **T**ransaction **A**uditing_

---

PISTA is an off-chain intelligence layer that monitors smart contract activity in near real time and takes on-chain action when risk is detected. It solves the problem that smart contracts operate in isolation without broader context about user behavior, market conditions, or coordinated attacks.  

## The problem

Smart contracts operate in a vacuum. They can enforce rules about who calls them and when, but they have no awareness of **broader context**: 
- a user's history across protocols,
- unusual market conditions,
- coordinated exploitation patterns, or 
- slow-drain attacks that only become visible when looking at aggregate behavior over time. 


The pain:
> Encoding complex, evolving detection logic directly in Solidity 
is prohibitively expensive and rigid  by the time you update the contract, the attack has already moved on.

## Possible applications

- Eforcing **AML** rules for exchanges
- Enforce compliance with regulations like **MICAr**
- Stop novel attacks on protocols and smart contract
- Outsource complex logic that might need to adapt o change over time to an off-chain trusted ruleset
- Leverage **AI monitoring** on contract/user behaveyour


## How PISTA works

PISTA subscribes to smart contract events across any number of protocols and/or general blockchain data.
A **substream** (developed via **substream-devs** skill) collects all blocks, parses them and stores relevant data into **Clickhouse** database.


The data is then fed to an AI agent that evaluates relevant updates against baselines and adaptive policies. Should a suspicious activity be detected, response actions are triggered. Those may include both on-chain and off-chain actions like:
- pausing a contract (or any other state change the contract supports) 
- blacklisting an address
- transfer funds
- trade funds on a DEX
- send an email/alert
- lock credit card transfers

etcetera.

![Diagram 1](Docs/Diagram_2.png)

## Why this matters

- **Works on contracts you don't own.** PISTA doesn't require protocol teams to integrate or deploy anything. It acts as an independent safety layer that any user, DAO, or protocol can run.
- **Adaptive, not static.** Rules are not hardcoded. The system learns what "normal" looks like for a user or a population of users, and adapts as conditions change  a bull market behaves differently from a bear market, and PISTA adjusts accordingly.
- **Catches novel attacks.** Because it flags deviation from baseline behavior rather than matching known signatures, PISTA can detect zero-day exploits, new fraud patterns, and emerging attack vectors that signature-based systems miss.
- **No on-chain cost for intelligence.** All computation happens off-chain. The EVM is only used for the final action, keeping gas costs minimal while enabling arbitrarily complex analysis.
- **Cross-protocol visibility.** A single PISTA instance can monitor activity across multiple contracts and protocols simultaneously, correlating signals that no individual contract could see on its own.
- **Near real-time response.** Events are processed as they land. Between detection and action, the window is narrow, not the days or weeks it takes for governance proposals or manual intervention.




## Tools and componets used:


- **The Graph** is used to pull/query data from the blockchain providing:
    - high parallelism
    - high troutghtput
    - flexibility
    - reduced cost
    We pull data using a substream and then parsing/filtering the data

- **Clickhouse database** is an open-source database used to store the data coming from the substream. It's made for Agents/LLM and real time analytics and can be queried in plain SQL.

- A **Demo smart contract** is supplied to showcase the possibility of sending a reaction on-chain to a smart contract. See [dedicated README.md](SmartContract/README.md)


## AI / Models used during development

- **Opencode+Claude.ai**:
    - jot the README.md files
    - demo smart contract code comments
    - demo smart contract test coverage
    - protobuff definition
- The Graph's **substream-devs** skill
    - substream creation

## Setup

TBD



---


## Further/Future developemet

Due to time constraints the demo is done on a simple contract, but further developement might include:
- monitoring of complex contracts
- monitoring of stablecoin contracts (USDC, USDT EURC...)
- monitoring of all stablecoins pegged to the same fiat asset
- monitoring of assets across multiple chains
- monitoring cross-chain bridges
