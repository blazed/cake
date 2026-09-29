---
name: shortcut-debt
description: Find shortcut comments that record deliberate shortcuts and deferred upgrades.
disable-model-invocation: true
---

# Debt

Find comments containing `ponytail:` or `shortcut-debt:` in the relevant codebase.

Produce a compact debt ledger containing:
- file and line;
- the recorded limitation;
- the stated upgrade condition or path.

Do not modify files.

If no `ponytail:` or `shortcut-debt:` comments exist, say so.
