---
name: usage-accounting
description: Developer usage ledger and per-world accounting rules (never reset totals; usage metadata is developer-only).
whenToUse: When recording, reporting, or reasoning about model/provider usage, fees, or billing ledgers.
---

# Usage accounting

## Per-world developer usage book
- Developer usage totals belong to each world and stable NPC/GM identity, starting at that world's genesis.
- Retain the active world's existing calls; never reset its totals on restart, model, or session changes.
- It does not reset the provider's cumulative billing ledger.

## Rules
- Only actual unresolved calls in the active run/world block new admission. Do not invent a dependency on unavailable older-world records.
- Older-world GM accounting is historical context, not a prerequisite for new-world observation or life.
- The verified cumulative Kimi ledger (found locally in the older UE project) must not be initialized or reset.
- Usage metadata is developer-only and must never enter NPC observations/prompts.
- Keep original billing ledgers local unless a concrete transfer requires them.
