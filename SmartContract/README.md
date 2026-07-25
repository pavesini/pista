# Dummy smart contract


## Counter.sol contract

The Counter.sol contract is a minimal proof-of-concept showing PISTA's core capability: controlling on-chain activity based on off-chain decisions.

Key demonstration points:


```
1. Simple state changes: increment() (public) and setNumber() (admin-only) both emit Fired events that PISTA can monitor
2. Pause mechanism: The Paused boolean allows PISTA to halt all non-admin functions when off-chain analysis detects risk
3. Admin governance: PISTA can manage admins via authorize() to control who can pause/unpause
4. Event-driven monitoring: All state changes emit events that PISTA subscribes to for analysis
```

 The demo flow:
```
- PISTA monitors Fired events from Counter.sol
- Off-chain AI/rule engine analyzes patterns (e.g., rate limits, unusual activity)
- When risk is detected, PISTA calls pause(true) on-chain to halt the contract
- When risk passes, PISTA calls pause(false) to resume
```

This shows PISTA's value proposition: complex detection logic (sliding time windows, address policies, cross-protocol correlation) happens off-chain, while only the final action (pause/unpause) incurs gas costs.


`Counter.sol` is a simple counter with two state-mutating functions:

- `increment()` — callable by anyone, increments the counter by 1.
- `setNumber(uint256)` — admin-only, sets the counter to an arbitrary value.

Both functions emit a `Fired` event with the caller and the new value.

### Pause mechanism

The core feature is a `Paused` boolean. When true, all non-admin functions revert. This allows an external system (PISTA) to halt the contract based on conditions that are too complex, expensive, or dynamic for the EVM — such as rate limits over sliding time windows, address-based access policies, or other off-chain risk signals.

### Admin governance

The contract supports multiple admins via an `authorize()` function. Admins can:

- Pause and unpause the contract (`pause(bool)`)
- Grant or revoke admin status for other addresses (`authorize(address, bool)`)
- Force-set the counter value (`setNumber(uint256)`)

The deployer is automatically set as the first admin. At least one admin must always exist.

### Events and errors

- `Fired(address sender, uint counter)` — emitted on counter changes.
- `Authorized(address who, bool status, address by)` — emitted when admin status changes.
- Reverts with `"Contract Paused"` when `increment()` is called while paused.
- Reverts with `"Not Admin"` when a non-admin calls a restricted function.
- Reverts with `"Need 1 admin"` when trying to remove the last admin.

### Test coverage

Tests cover admin setup, authorization, increment, fuzz-based setNumber, pause/unpause, and the key scenario: verifying that `increment()` reverts during a pause and resumes after unpause.


### Deploy

|Data | Value|
|----|-----|
|Network | Ethereum Sepolia |
|Deployer address |  0xd6d5e7b2c47399853f6c988eb60f862a6cb26f7d| 
|1st admin | 0xd6d5e7b2c47399853f6c988eb60f862a6cb26f7d |
|Deploy txh | 0xb2caf6a7f67b5232ed0abc5e0297154bd76c48ad6c188b599ed968fb7db99960|
|Contract address | 0x6A1fa9938e2698EA4009E3821CbeF215620f2003|
|Explorer 1 | https://repo.sourcify.dev/11155111/0x6A1fa9938e2698EA4009E3821CbeF215620f2003
|Explorer 2 | https://eth-sepolia.blockscout.com/address/0x6A1fa9938e2698EA4009E3821CbeF215620f2003?tab=contract|

