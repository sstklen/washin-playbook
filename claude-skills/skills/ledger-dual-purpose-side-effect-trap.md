---
name: ledger-dual-purpose-side-effect-trap
description: |
  Prevent double-counting bugs when a "logging/audit" function also updates balances as a side effect.
  Use when: (1) writeLedger/logTransaction-style function records transactions AND modifies account balances,
  (2) vault/escrow/pool transfers where balances are updated by separate dedicated functions,
  (3) fixing ledger amounts from 0 to actual values causes duplicate deductions/additions,
  (4) code review of financial/token systems with dual-purpose ledger functions.
  Applies to API Platform, any token economy, escrow systems, or multi-wallet architectures.
author: Claude Code
version: 1.0.0
date: 2026-02-17
---

# Ledger Dual-Purpose Side Effect Trap

## Problem

A `writeLedger()` function that **both records a transaction AND updates account balances** creates a
hidden trap: when used alongside dedicated balance-update functions (like `updateVaultBalance()`),
the same money movement gets applied twice — once by the dedicated function and once by writeLedger.

This is especially dangerous because:
- The bug is invisible in code review (writeLedger "looks like" an audit function)
- Amount=0 entries look like bugs ("why record zero?") and invite "fixes" that reintroduce the real bug
- The double-counting only manifests in production with real transactions

## Context / Trigger Conditions

- **Symptom**: Users lose/gain twice the expected amount during transfers
- **Code smell**: A function named `writeLedger`/`logTransaction`/`recordEntry` that also runs
  `UPDATE users SET balance = balance + ?`
- **Trigger scenario**: Someone changes `writeLedger(uid, type, 0, ...)` to
  `writeLedger(uid, type, -amount, ...)` thinking "the ledger should record actual amounts"
- **Architecture**: Multi-wallet system (personal wallet + vault/escrow/pool)

## Solution

### Rule: Identify the Balance Owner

For every `writeLedger()` call, ask: **"Who should this amount affect?"**

| Transfer Type | Balance Updated By | writeLedger Amount | Why |
|---------------|-------------------|-------------------|-----|
| Personal -> Personal | writeLedger itself | **actual amount** | writeLedger IS the balance updater |
| Personal -> Vault | writeLedger + updateVault | **actual amount** (writeLedger moves personal, updateVault moves vault) | Both sides need updating |
| Vault -> Vault | updateVault only | **0** | Personal wallets not involved |
| Vault -> Personal | writeLedger + updateVault | **actual amount** | Both sides need updating |
| Fee (embedded in transfer) | Already in amount spread | **0** | Fee = amount - received, auto-burned |

### Decision Flowchart

```
writeLedger(uid, type, amount, ...) is called:
  |
  Q: Does updateVaultBalance/updateEscrow/updatePool
     already handle this money movement?
  |
  YES --> amount = 0 (pure audit trail)
  NO  --> amount = actual value (writeLedger handles it)
```

### Anti-Pattern: "Fix the Zero"

```typescript
// DANGEROUS "fix" — looks correct but causes double-counting:
writeLedger(uid, 'transfer_vault_out', -amount, ...)  // <-- Also deducts from personal wallet!
updateAssocWalletBalance(uid, assocNum, amount, false) // <-- Already deducted from vault

// CORRECT — amount=0 for audit trail only:
writeLedger(uid, 'transfer_vault_out', 0,
  `Vault transfer: ${amount} WT`, ...)  // Description has the number, amount=0
updateAssocWalletBalance(uid, assocNum, amount, false)
```

### Fee Double-Charging Pattern

```typescript
// Transfer: sender pays 100, receiver gets 97.5, fee = 2.5
const received = amount - fee;  // 97.5

writeLedger(uid, 'transfer_out', -amount, ...)     // Sender -100
writeLedger(toUser, 'transfer_in', received, ...)  // Receiver +97.5
// Fee of 2.5 is auto-burned (100 - 97.5 = 2.5 exits the system)

// WRONG: Don't also record fee as additional deduction!
writeLedger(uid, 'fee_platform', -platformFee, ...)  // <-- Sender now loses 100 + 1 = 101!

// CORRECT: Record fee for audit but don't deduct again
writeLedger(uid, 'fee_platform', 0,
  `Platform fee: ${platformFee} WT (already embedded in transfer)`, ...)
```

## Verification

1. For every writeLedger call, trace the full money flow:
   - Sum all writeLedger amounts for sender = should equal total outflow
   - Sum all writeLedger amounts for receiver = should equal total inflow
   - Sum all updateVault/updateEscrow amounts = should equal vault changes
2. Verify: `sender_out + receiver_in + burned = 0` (conservation of tokens)
3. Write a unit test that checks `users.token_balance` before and after each transfer type

## Example

**Washin Village API Platform System (2026-02-17)**:

- `writeLedger()` in `token-engine.ts:201` reads user balance, adds amount, updates `users.token_balance`
- `updateAssocWalletBalance()` in `database.ts:1659` updates `association_wallets.balance`
- Vault-to-vault transfer called both, causing personal wallets to change when they shouldn't
- Fix: Changed vault transfer writeLedger amounts from `-amount`/`received` to `0`
- Cross-association fee_platform changed from `-platformFee` to `0` (fee already in spread)

## Notes

- **Comment the "why" for amount=0**: Future developers WILL try to "fix" zero amounts.
  Add comments like `// amount=0: vault transfer does not affect personal wallet`
- **Codex CLI caught this**: Dispatched as real `codex exec` security audit, it traced
  writeLedger's implementation and discovered the side effect
- **Gemini missed it**: Only verified surface-level correctness (amounts non-zero = good),
  didn't trace the actual function implementation
- **See also**: `bun-async-race-condition-pattern` (related concurrency concern),
  `pre-deduct-phantom-refund-prevention` (related billing pattern)
