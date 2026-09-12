# First real ten-resident run and first real background-GM observation (2026-09-12)

Status: the **first real closed loop ran end to end** — real Kimi residents, a real DeepSeek
background GM that read evidence, wrote and tested code, an independently reviewed release,
and the same world continuing afterwards with a cold restore. The first bounded resident/GM repair-loop MVP passed; continuous service and the later M20
acceptances remain open. This is one phased bounded loop (ten residents, one supervisor-specified
investigation), not continuous 20-agent operation, not spontaneous GM discovery, and not
sustainable economy or autonomous life.

## Current result (2026-09-12)

* Second-run coverage (exact): the continuation produced **20 new live commands from nine resident
  identities** — baker 3, smith 3, carpenter 2, innkeeper 3, gardener 2, weaver 3, fisher 2,
  well-keeper 1, herder 1; the healer issued no new request inside this bounded second run. All ten
  identities had real choices in the first cycle, and all ten identities, bodies and histories
  persisted through the second. The innkeeper's `:3`, `:4`, `:5` are three real
  `ask:shared:smith` choices; no new movement event was recorded for the other residents. Totals are
  unchanged: 40 real Kimi requests, +0.6129836 CNY.

* Two bounded real Kimi runs on this same world: 20 + 20 requests, **+0.6129836 CNY** total
  (first +0.2291913, second +0.3837923); Kimi historical uncertain rows stayed **6 → 6**
  (no new unknown); the carried ledger, reserves and currency bounds were untouched.
* The maintained world `shared:aincrad-trial-1` advanced `seq 17 → 38`, sha256
  `7f2c91a4…` → `ea96edeaab1c77511dbf02815132b3bd8b7820241278a2c7d41399a4d2111c44`, with the
  ten identities, money, items and the old 17-event history unchanged.
* The original stuck command `turn:shared:innkeeper:0:2` (approach `shared:smith`) **completed
  exactly once** — one receipt, one `resident_moved` life event, same payload and target. The
  physical obstacle was the **carpenter at x≈1.5**; the smith was the resident being approached,
  not the obstruction. Afterwards the innkeeper itself chose three further `ask:shared:smith`
  turns (nobody forced a choice).
* Paused cold restore of a copy: byte-identical file, active 10, `life_seq 38`, `none_restore`,
  zero pending, the original receipt still exactly once.
* Fresh picture of that real run: [after-gm09.png](after-gm09.png).

## 1. What actually ran

One bounded foreground launch of the existing `tools/run_town_model_validation.py` against the
maintained trial world `tmp/chain-20260912/ten-world/trial-world.json`
(`world_id shared:aincrad-trial-1`, ten fixed residents, genesis `01ef0bf8…`, byte-exact BEFORE
snapshot `tmp/real-ten-20260912/trial-world.before.json`).

* engine exit 0, 303.078 s, all three owned members exit 0, no crash/SCRIPT ERROR.
* served model `kimi-k2.6`; `upstream_requests 20`, concurrency 1; `model_errors {}`.
* ledger: settled rows 1025→1045, settled_cny 15.6090885→15.8382798 (**+0.2291913 CNY**),
  reserved 10.265088 unchanged, **uncertain rows 6→6 (no new unknown)**, `halted ""`.
* all ten persistent actors were genuinely chosen: capture `resident_turns` = 10/10 `settled`.
* attributed life events: ask_help 6, eat_ration 3, skill_notice 3, resident_moved 2,
  reply_help 2, plus one host-side `foraging_work_spots_installed`.
* command stores are separate and must be read separately: `godot.commands` holds 11 entries,
  **all completed**; `godot.trade.commands` holds 20 entries, **19 completed and 1 pending**
  (`turn:shared:innkeeper:0:2`), so the run leaves **one unfinished commitment overall**.
  0 rejected, 0 provider errors. Food 10→7 (three meals), eaters' hunger 98 vs 58, energy 58,
  foraging stock 6 with `harvested_total 0` — finite resources untouched, nothing granted.
* maintained world advanced to sha256
  `7f2c91a4c387027ccff66a5a85e892f14e790498ff35aa1c4c060a9470ed3007`.

## 2. Root-review erratum on the task08 completion message (audit trail)

The task08 completion message claimed: *"pending [] — commitments settled, no dangles."*
**That claim was false and is preserved here unchanged.** It checked only `godot.pending` and
the capture's `pending_count`; the maintained save also holds
`godot.trade.jobs.shared:innkeeper = {action: approach, elapsed 0}` with command
`turn:shared:innkeeper:0:2`, target `shared:smith` at 1.1503 m. Two supervisor read-only
samples 93.5167 s apart show an identical innkeeper position and elapsed work 0. Cold
byte-equality preserved that commitment; it did not complete it. The freeze snapshot's
`source_revision.life_seq = 1` is its last content change (actual world `seq 17`), so it is a
frozen early projection, not a final full-world snapshot.

## 3. First-pass history: this world's first ten-GM observation (earlier fixture ten-GM history is separate)

This section records the **first pass as it happened**. Six contracts were valid and four were
measured `invalid_output`; all four were later resumed in their own saved sessions and became valid,
so the world now has **ten valid GM observation sessions in total** (see section 6 for the completion
batch). Nothing in this section should be read as "only six GMs are current".

`tools/gm_runner.py observe` (dry-run first, then the same command) against the frozen
producer snapshot `f8d241bd…` plus the supervisor investigation
`real-ten-01-social-approach`; state `tmp/real-ten-20260912/gm-state` (bound to
`shared:aincrad-trial-1`); summaries `gm-dry-run-01.json`, `gm-observe-01.json`.

* 10/10 dispatched, each in its own native session; dry-run confirmed 10 can_dispatch.
* 6 valid proposals (gm-01, 03, 07, 08, 09, 10) → 6 issues, all `origin gm_proposed`, all bound
  to the supervisor investigation; **gm-09 owns `issue-42d582f14294`** (claim accepted).
* 4 GMs (gm-02, 04, 05, 06) returned `invalid_output` with the same validator reason
  ("new_issues[0].summary must describe one hypothesis in 12..400 characters"). All four are
  **measured** failures with sessions kept for a later resume — no unknown cost, no global stop.
* measured usage, 10 sessions: input 3,010,535 (cached 2,827,392 ≈ 93.9%), output 52,614,
  reasoning 42,391. Token counts are not a currency bill; the runner derives no cost from them.
  These are **ten DeepSeek GM-observer tokens**, accounted separately from the **twenty Kimi
  resident calls** (CNY 0.2291913) in section 1; do not merge the two figures.
* guards unchanged: trial world `7f2c91a4…`, snapshot `f8d241bd…`, investigation `64d6bdd1…`,
  facts `13d4a687…`, git HEAD/status unchanged. The world was not advanced during observation.

**Important provenance limit.** The read-only native GM sessions are policy-restricted: their
benign file-reading shell commands were **rejected by policy**, so the GMs did **not**
independently open the companion facts file or the scene/trade sources. Their six valid
hypotheses rest on the supervisor-written investigation objective plus the sparse producer
projection, and one of them (gm-09) additionally proposed a resident-visible obstruction
signal. This is therefore a **supervisor-specified investigation**, not spontaneous and not
independently verified GM discovery; the same restriction is why several GMs explicitly noted
"facts file unreadable"/"shell blocked".

Truthful history of those refusals: at least one observer (gm-01) did go on to try alternate
shells and GitHub connector reads after its first rejections; **every local attempt was denied
and no alternate route produced any file access**, and the connector path returned no repository
content. No sandbox, policy or approval setting was relaxed, and no successful bypass exists.
The second pass avoided further rejected reads by carrying the needed facts inline in the
investigation objective, which is why those hypotheses are described as supervisor-supplied.

**Top supported implementable problem** (six valid GMs converged from the same supervisor-supplied
facts): the
GM-visible projection carries no pending/in-flight action progress, so a resident whose command
stalls at zero progress cannot surface as a GM issue; and the visible counts under-report
(`godot.pending` empty while `godot.trade.jobs` holds an unfinished job, capture
`pending_count 0`). Suggested scope: `game/core/town_runtime.gd` GM projection plus the
save-side projection input that feeds it, with a probe asserting the innkeeper's pending
approach appears with progress/elapsed and that pending counts include trade jobs.

**Coverage gap (source-confirmed by the supervisor)**: the producer export covers blocked
`recover_material` recovery and accepted needs only, so an `approach` job that never accrues
work has no channel into it at all; `capture.pending_count` counts only `godot.pending`, which
is why it reported 0 while `godot.trade.jobs` held the unfinished approach.

**Strongest counterexample**: the frozen snapshot's `source_revision.life_seq = 1` versus actual
`seq 17` is the declared content-signature update policy (the snapshot is rewritten only when
its content changes), so the zero counts are **not** claimed to be a staleness/rewrite bug. No
collision or unreachability cause is established either: the innkeeper may be blocked by a body
or by an unavailable target, and the physical cause needs a dedicated test. The 20-decision cap
limits new model decisions for this cycle; it does not stop an already-accepted physical task
from advancing, and the engine kept running physics to the 300 s bound precisely because the
pending approach prevented `stop-on-idle` from ending the run. This is a hypothesis list, not a
diagnosed defect.

## 4. Continuity

A paused cold reopen on a **copy** of the post-run world (ordinary Forward+ scene, no provider
request, exit 0, 6.1 s) reproduced world `shared:aincrad-trial-1`, active 10, `life_seq 17`,
`none_restore`, with identities, needs, history, commands, `trade.jobs` and foraging identical
to the maintained save and the copy's hash unchanged — no mutation, no replayed model choice.

## 5. Renderer note

These runs used the project's existing Forward+ default. The limited comparison against the
explicit `gl_compatibility` override (60 s bound faulting at 45.657 s with offset `0x141377d`
versus 92.9 s completed on the default) is recorded in the
[H34 report](../h34_deepseek_diagnosis_2026-09-12.md); the two runs were **not literally
identical CLI invocations** and their durations differ by design. That comparison is a bounded
preflight observation, not a stability certification, and H34 remains open.

## 6. Ten valid GM observations (first batch + same-session completion)

The first observation batch had six valid contracts (gm-01, 03, 07, 08, 09, 10) and four
measured `invalid_output` responses (gm-02, 04, 05, 06) whose only validator reason was the
hypothesis-length bound (summary > 400 chars). Those four were acknowledged after supervisor
review and **resumed in their own saved sessions** with supervisor-supplied inline facts; all
four then returned valid contracts, so **all ten GM observation sessions are now valid**.
Both batches stay in history: the four failures, their preserved usage, and their retries are
not erased. GM output remains hypotheses from a supervisor-specified investigation.

## 7. GM09: block → timeout → corrective candidate → reviewed release → real continuation

1. First coding attempt: `worker_blocked` — the launcher requested `-s workspace-write` but the
   native sandbox stayed read-only, so the GM could neither read files nor execute anything and
   refused to ship un-executed code. Measured usage retained.
2. Launcher fix: the host's configured `windows.sandbox` backend is now carried into the
   invocation (whitelisted single-field parse; other config values are never forwarded or
   output), and an absent/invalid/unsupported backend fails before any paid call. Independently
   probed with the official restricted sandbox: candidate read exit 0, candidate tmp write exit 0,
   task-owned outside sentinel write **denied** with unchanged bytes.
3. Second coding attempt genuinely worked inside the candidate (native `turn_context`:
   `workspace-write`, `network_access: false`, managed profile with write only to the candidate)
   but exceeded the 900 s bound; that turn is a preserved **unknown** usage tail, separate from
   its 45 measured completed responses (input 8,369,695 / cached 8,259,840 / output 97,766).
4. Corrective run (`--timeout 1800`) under the supervisor review scope: same session
   `01a094e5-3f4d-7501-b0d9-6033637c3063`, status `ok`, all three declared scope tests exit 0,
   social checks 42/42 with five engine stages exit 0, trade 63/63, foraging 66/66 (the last is
   a state test, not a new physics proof), zero out-of-scope files.
5. Accepted release: exactly the **eight** reviewed paths were installed into main with
   source/main-before/installed hashes all verified (`gm09-release-manifest.json`); the launcher
   fix is a separate runtime change and is not part of the game release.
6. Disclosure kept: a path bug in the GM's own fixture tooling deleted 68 candidate `.uid`
   files, which were restored byte-identically (the supervisor independently verified all 68
   original `.uid` SHAs, not a sample); the final candidate tree contains only the eight allowed
   files. No claim is made that no other file was ever touched.

## 8. Accounting corrections

* The native CLI reported 25,883,971 input / 149,877 output for the corrective task, which
  **includes** the interrupted task's completed responses. The deduplicated increment for that
  task is **17,514,276 input (17,300,096 cached, ≈98.8%) and 52,111 output**; it must not be
  added to the 45 earlier responses again.
* Raw token counters are not a currency bill: no DeepSeek CNY is estimated from tokens, and the
  unknown interrupted tail is **not** treated as settled, zero or fully measured.
* Kimi currency and the six historical uncertain rows are accounted separately from all DeepSeek
  development tokens.

![ten residents, real Kimi run](town.png)

*Real Kimi run (`tmp/real-ten-20260912/residents-01/capture/town.png`), ten actor nameplates,
`local_rule_policy` off, `controller_records` on. Captured at the end of the 300 s bound; the
unfinished innkeeper approach is present as state, not visibly marked in the HUD.*
