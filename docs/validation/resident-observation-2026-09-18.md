# H109 — Fresh resident world, decisions and complete transfer

The user explicitly chose to restart the villagers at seq0, observe continuously for ten minutes, retain subsequent sequences across machines, and receive a concise Chinese account of every decision. The user also clarified that the API key remains local and other needed work may be uploaded. This supersedes the earlier offline-only restriction for the new world; it does not imply recovery or replacement of the old seq450 world.

The active lineage is `shared:restart-20260918-01`. It starts with ten distinct complete dossiers, the current sixteen-house quarter, no invented personal relationships, one ration per resident and the original two actual repair skills. Role names do not grant production skills. The seed has no installed baking/material expansion. [Active lineage and transfer contract](../../worlds/README.md) · [Every decision in Chinese](../../worlds/restart-20260918-01/report.zh-CN.md) · [Structured run receipt](../../worlds/restart-20260918-01/run-summary.json).

## Actual observation and the early-stop defect

The existing local Kimi K2.6 configuration and cumulative city-validation ledger were recovered from the old UE project. Before sending a request, all 186 old rows were settled, no reservation was uncertain, and the ledger/guard were backed up. The existing ledger was continued, never initialized or reset. One-at-a-time dispatch, at most 32 new requests, a local ledger cap of CNY 3, and no automatic retry were configured. The new episode cap rejects a request before reservation when its full conservative reservation would exceed the remaining episode allowance.

The first process started at 08:26:35 UTC and exited at 08:31:18 UTC (282.664 wall seconds). It produced 32 actual model decisions and seq42, while the world advanced 269.7 seconds. All replies settled. One stale Wren/Reed option was rejected and retained as a recoverable wait. The old launcher returned `passed`, but that did **not** satisfy the requested ten minutes.

Inspection found that a paused live scene reused the three-second read-only capture timeout, causing immediate early shutdown once the scene was paused after that point. The capture's UI says “Life is paused”; the old evidence does not identify who or what caused the input, and this report does not assign that cause. The defect was the timeout and success classification after pausing.

The host now reserves the short capture for explicit read-only restores, records active and paused durations separately, and exits with an incomplete-duration status when a timed live episode spent insufficient time running. The launcher also rejects explicit incomplete-duration evidence even if the engine reports exit zero. Tests exercise paused live episodes, delayed replies, never-returning replies and the exact admission boundary. The first new test needed one deferred-frame wait in its fixture; its failed output remains local and the assertions were retained.

The original seq42 was then continued for a separate uninterrupted ten-minute headless observation. Model admission was zero because the announced 32-request allowance had already been used. Zero-admission mode creates no provider brains. This interval follows actual saved work and physiology; it does not fabricate another ten minutes of model dialogue or overwrite the first interrupted episode. Iris's pending rest completed as seq43. Exact duration, end state and zero-request evidence are in the run receipt.

## Findings and limits

- All ten residents participated. Decision counts: Ari 1, Wren 2, Flint 5, Rowan 5, Mara 5, Heath 3, Fern 3, Iris 5, Reed 2, Sage 1.
- Flint and Rowan independently met at the artisans' forecourt and discussed fixing Rowan's worn axe. They identified missing iron. Agreement to talk was not a contract, transfer, payment or completed repair.
- Mara and Iris independently met at the plaza and discussed finding weaving instruction. Their words proposed looking together, but no joint-goal controller or collective journey was created.
- Wren, Reed and Sage gathered rations. Heath rested and ate. Fern rested and then waited because plant-care actions were absent. Ari chose to observe the shared-water area by waiting. No plant, animal, textile or fishing capability was created by their intentions.
- Skill notices delivered their current fixed event text; the richer proposed speech remains archived separately. Other help/reply speech has real recipient-bound delivery events. Wren's rejected second choice did not produce delivered speech.
- The existing stale-option recovery cooldown is 1,800 simulation seconds; the 32-request episode cap also prevents a new decision in this observation. No paid reply was replayed to conceal the refusal.
- No GM agent was run. The [GM evidence export](../../worlds/restart-20260918-01/gm-evidence.json) contains observations for future work, not completed GM development. Independent free conversation, executable cooperation, relationship growth and sustainable professions remain incomplete.
- Four existing navigation edge-overlap warnings remain. This run does not close them or earlier renderer concerns.

The ledger added CNY **0.5280753** at its retained tariff: **3.7226209 → 4.2506962**, **186 → 218** settled requests, zero unknown/reserved requests. This is ledger accounting, not an independent account invoice. The complete original rows and guard are verified unchanged. The follow-up, tests and report generation add no provider calls.

## Verification and publication

- 50 Python checks cover cumulative-budget preservation, pre-reservation episode caps, gateway draining, duration classification, exact checkpoints and evidence-only reporting.
- 50 focused Godot shutdown checks and 11 read-only restore checks pass; the new seq0 world also passed production load/save/cold restore before the live call.
- A production cold restore checks every nested field of the final checkpoint against a separate saved copy; see [cold-restore.json](../../worlds/restart-20260918-01/cold-restore.json).
- The checkpoint manifest preserves the full event prefix, original replies, rejected replies and any appended replay evidence. Byte hashes identify multiple different states at the same event sequence. All ten original complete character profiles are retained.
- The English roadmap and HTML/SVG/PNG are regenerated together: 39 nodes, no browser script errors, owned renderer processes exited.
- The original live result and interrupted state remain evidence; final reporting records their limitations. API keys, private gateway tokens, ledger backups and raw tool/session logs are not published. The visible conversation archive is refreshed separately before upload and its actual cutoff is verified.

Local evidence directory: `C:/InfiniteAincrad/private/worlds/restart-20260918-01/`. Public world, decisions, GM observation projection, safe cost summary and transfer manifest: `C:/InfiniteAincrad/worlds/restart-20260918-01/`. The API configuration remains at `C:/InfiniteAincrad/Saved/ThreeHearths/api-config.json`; never copy its contents into a report or repository.
