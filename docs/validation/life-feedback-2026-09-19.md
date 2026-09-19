# Real failure feedback and GM effect review

H119 continues `shared:restart-20260918-01` from seq162 to seq174. The final checkpoint SHA-256 is `55dad1ad02bf20734bd71bf9c89583011a2f1787fd6fa12cd2ce9586de2bc7db`. All ten residents, all 160 archived attempts and all 174 world usage records survive. This is the same lineage; the original seq450 world remains separate.

## Actual resident behavior

Two serial windows ran for 180 and 480 seconds, with caps of four and twelve requests. All sixteen Kimi requests settled, costing CNY **0.3289711**, with no new unknown or reserved fee. The first four requests were consumed by earlier eligible residents, so that window alone did not establish an Iris response. The second reached her ordinary turn.

Iris explicitly recognized the previous `resources_unavailable` result, chose another harvest and obtained one ration at seq170. Her following attempt failed when stock was unavailable. Neither inventory nor her choice was forced. Heath and Fern exchanged delivered speech about animals; those words do not establish that animals exist in the scene. Wren completed a meal, Flint visited and rested at the artisans' forecourt, and other observed actions remain individually recorded in the [resident report](../../worlds/restart-20260918-01/observations/feedback-20260919/report.zh-CN.md). Sage did not make a new model decision in these two windows; full-roster continuous activity is not claimed.

Final public stock is one ration, resident holdings total ten, cumulative public production is fifteen and completed meals total twenty. Current total satiety is 801. The ideal code-level envelope is 7.5 rations per world hour of need versus eight of production, assuming ten residents, no clipped meals, available capacity and effective voluntary collection/allocation. The small surplus is not long-term sustainability evidence.

## One actual GM04 review

GM04 consumed a hash-bound coordinator receipt of the new physical effects and acknowledged it with decision `accept`. This was a genuinely new **epoch2** native conversation, retaining GM04's durable memory; it does not restore the missing old native session. The run was `feedback-20260919T033016Z-250094`, with receipt SHA-256 `faba5e301f7b0d77deb0e74f47b13ed3846692148d1773f40a0214519ac225d3`.

Measured usage was 47,012 input and 4,064 output tokens, including 896 cached input and 3,092 reasoning output tokens. The total is 51,076; subsets are not added again. Currency cost for this route is unavailable and is not included in the Kimi CNY figure. GM04's next work is to verify stock versus allocation constraints and the existence/ownership of a finite iron source. The subsequent [read-only factual answer](life-feedback-2026-09-19/gm04-requested-facts-prepared.json) confirms stock-zero arrival observations and a still-uncollected three-unit public iron heap, with no smith discovery record. This answer is prepared, not yet model-consumed. It did not invent or install a new capability in this turn. No issue was automatically closed, and no unknown task was retried.

The complete pinned design, retained GM memory and existing issue projections required a measured 91,165-byte feedback prompt. A local 64-KiB preflight refused before dispatch; compact factual references and an explicit 96-KiB cap admitted exactly one call. No history was deleted to fit. Receipt and world bytes remained unchanged during the call, and the owned Windows job exited completely.

## Integrated observation and accounting changes

The read-only GM projection now separates audited self-repair completion/failure, material handoff and current basic-life resource refusal from public speech. It cross-checks command, accepted turn and event journals, excludes private reasons and preserves movement/pending evidence priority. Current terminal failures precede a bounded newest window of historical facts; old repairs cannot permanently hide newer failures.

Root integration found and fixed a real receipt-shape mismatch: self-repair retains its **start** event ID and separately records `terminal_seq`. The final projection follows both fields correctly. Fixture setup errors in the first two runs and the third run's failed assertions were retained; they are not counted as passes. The final suite passed **37 assertions**. A read-only export from actual seq174 separately produced twelve valid GM evidence entries, including Rowan's real seq158 repair and Iris's current refusal, without changing the save. The paid GM04 review above used the earlier explicitly authored host receipt; this later projection export has not itself been model-consumed.

A proven local GM executable-start failure now records `not_sent`; actual unknown, partial and measured usage remain distinct. The focused root accounting regression passed. All old calls and the complete existing revision prefix remain identical. GM06's previous unknown and GM05's unresolved historical tail remain preserved.

## Recovery and limits

The production cold-restore check passed for all nested fields and ten residents at seq174. Both resident gateways drained, the GM job closed, and no canonical writer remains active. Read-only launch remains available through `OpenLatestWorld.cmd` in the entry workspace.

Live03 had no engine errors. Live04 logged eight null-particle renderer errors and six errors from one house resource load (`ERR_FILE_CORRUPT` / parse-Variant), while still saving and exiting normally. Subsequent isolated headless and Forward+ loads of that unchanged source/cache both instantiated the house with 21 children and no errors. This does not reproduce or resolve the full-scene startup failure; no source asset, cache or render setting was changed. The existing navigation overlap warnings also remain. Successful persistence does not establish renderer stability. Natural full material exchange/negotiated production, continuous ten-GM supervision and long-term resource balance remain unfinished.

The read-only [food envelope](life-feedback-2026-09-19/food-envelope.json) covers 18 exact checkpoints (17 selected time samples), with both inventory and foraging conservation intact. Five focused report tests passed. Sparse endpoint matches are not continuous empty/full durations, and the satiety residual is not labelled proven meal clipping. Reports require a fresh output path and cannot overwrite their input.

The full same-world observation and provider result summaries are [here](../../worlds/restart-20260918-01/observations/feedback-20260919/summary.json). Private ledgers, provider configurations and keys remain local. These continuation commits are local; this phase does not push to GitHub.
