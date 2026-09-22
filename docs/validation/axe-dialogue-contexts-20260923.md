# Axe dialogue contexts — 2026-09-23

The exporter emits at most three fixture-only formal-resident `town_turns` projections to an explicit new output path. The validator consumes raw local candidate strings and calls only `DialogueReceipt.parse`; it records structural acceptance/rejection and never executes a decision or claims semantic truth.

The projection retains the resident's existing life account, wallet, contracts, skills, owned items and unavailable actions, but removes only `known_rules.decision_format`: that field describes the older resident action/reason reply contract and would conflict with the dialogue envelope under test. The disposable axe has edge 20 and handle 100, so this is specifically an edge-repair context. Target IDs name the two in-range formal participants; the existing menu can still accurately list other current options.

The exporter verifies the skill notice and proposal results, the exact 2 Col offer, acceptance with iron and refusal without iron before writing. Source SHA-256 is checked before and after. The temporary resident-turn error record is removed only inside the disposable copy so each captured case gets a fresh projection. No candidate is executed. Successful Mono evidence is under `private/iteration-20260923/dialogue-contexts/export-gated/`; the final contexts are copied into `local-npc-dialogue-20260923/contexts.json`.

The parent also exercised the output-open failure path: expected exit 2, all owned processes exited, and no new `axe-context-*.json` files remained in the existing Godot user directory. Evidence is `private/iteration-20260923/exporter-cleanup/`. This addresses cleanup on that failure path, not a claim of exhaustive fault injection.
