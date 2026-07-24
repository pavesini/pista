# PISTA Contracts


----

## Counter.sol contract

`Counter.sol` is a proof-of-concept contract that demonstrates how PISTA can control on-chain activity based on off-chain decisions.

The contract is a simple counter with two state-mutating functions:

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