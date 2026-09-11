# One persistent world, one public collaboration path

Updated 2026-09-10 after the six-reviewer research and vote. This is the only execution roadmap. [Evidence and rationale](docs/research/2026-09-open-source/REPORT.md) · [Individual votes](docs/research/2026-09-open-source/vote-results.md).

## Goal

Build an enterable, consequential, persistent AI world in Godot. Residents retain their identities, experiences and commitments when their models change. **Latest user decision, 2026-09-10: continue art and gameplay; the well slice is an internal technical preview, not the first version.** The first town must reach the old project's actual repair/delivery/payment/tool-use/eat/rest/forage capabilities, then its intended 5–10 active-resident scope, with meaningful player intervention and cold-save continuity.

Verified reference: world `F4390752-4A07-7DE7-FACD-32BAC6F72C54`, 13 identities, three active residents (艾琳、拓真、柏木), life sequence 37. The local full source save dated 2026-09-10 08:30:40 has now been found, SHA256 `baaab67073a91b9db0b44691c05b4734f235898037074fc835d674d17ae63650`. This resolves source availability, not migration correctness or outstanding private billing. Preserve it read-only and validate separate migration outputs. Do not copy old UE movement/pending requests into a running Godot simulation.

Internal sequence now takes precedence over the earlier gate ordering below: (1) original state preservation and three-person life-rule port alongside visible character/prop improvements; (2) attributed communication, repair/work/exchange and player consequences; (3) a sustainable, accounted food/labor loop with 5–10 active residents across multiple game days; (4) actual model substitution and private-knowledge checks; (5) first-version art/readability review, independent testing and licensed distribution. Public authorization and external testers do not block steps 1–4. Art imports may be reconsidered for a specific visible gap; the earlier deferral vote is historical, not a veto on this new scope.

The public collaboration goal adds a requirement: strangers can obtain, run, modify and contribute to that slice. A public repository, a recording or a star count alone does not establish this outcome.

The selected route is **S1: a playable persistent-resident game, with a technical preview before the differentiated v0.1 release** (6/6 votes). Research evidence supports the game; a general-purpose agent platform is not the first deliverable.

## Current baseline

- Source baseline: `59bd52e`; two explicitly isolated fixture residents, authored market, pinned OpenGameAgent, authoritative world rules, existing knowledge/decision/save tests and recorded Kimi decisions.
- The market GLB and editable Blender source have been obtained and passed LFS integrity checks.
- No project-wide license has been applied. A Windows export preset, pinned manual/PR CI workflow and locally verified self-contained package now exist; independent external testers and an actual CI run remain pending.
- The original 13-person world has not been migrated. Its latest complete source save and private ledgers must be verified separately; public fixtures never count as that recovery.

## Sequential delivery gates

| Gate | One concrete result | Acceptance | Current state |
|---|---|---|---|
| P0 — Reproducible baseline and rights | A documented build baseline and precise code/art/third-party rights inventory | Official Godot 4.7.2 .NET/editor templates and SDK identified; existing assets verified; exact license proposal reviewable by the rights holder | Official binaries/checksums, source snapshot build and [rights proposal](docs/release/RIGHTS_REVIEW.md) delivered; license grant pending |
| P1 — Technical preview v0.0.x | A Windows package of the existing well event, with no editor, API key or maintainer-only path required | Existing core/save checks; independent package startup and cold restore; checksums and limitations; three new testers can launch and at least two complete/understand an intervention and restore within 15 minutes | Local v0.0.1 package passes headless and rendered event/restore; [evidence](docs/validation/windows_preview_2026-09-10.md); external tester gate pending |
| P2 — Nearby resident communication | A source-attributed inquiry/help request with a recipient choice that may reply, refuse or defer | Same street and writer; host-validated receiving range; private knowledge; unknown/out-of-range rejection; idempotent send/receive; saved response; cold restore without re-delivery | Next new world behavior |
| P3 — Differentiation | A three-person public demonstration and two different actual models continuing the same demonstration save with new decisions | Identities, old experiences, resources/commitments and event order preserved; private views respected; visible consequences; actual model provenance and honest error states | Not demonstrated |
| P4 — Collaborator release v0.1 | A licensed, reproducible slice with a short actual-play/restore recording and a complete first-contribution path | P1–P3 evidence; concise Chinese/English README; one runnable contribution example; 3–6 scoped tasks; source/asset notices; PR/Issue templates and release notes | Not delivered |
| P5 — Observed collaboration | Independent people run the project, contribute a bounded improvement and participate again | Suggested first 30-day observation target: five independent testers, three external contributors with accepted work, two returning participants | No external evidence collected |

Time and participant numbers above are proposed experiment targets, not industry standards, development deadlines, promised adoption or permission for automatic outreach.

P0 build preparation can proceed while a rights decision is pending. A public open-source release must wait for the corresponding permission and license scope. P1 gives potential collaborators a shared test object; it does not claim autonomous life, original-world migration or completion of P3. Failures block the affected claim and trigger diagnosis, not automatic replacement of the project.

## P2: smallest new world behavior

Start with Luna and Mira already in the isolated street. A message records its sender, recipient, unique event/command ID, time/turn and content. The host verifies the receiving range from authoritative positions; model-supplied coordinates or a prompt saying “you heard it” are not sufficient. The recipient receives only allowed information and may respond, refuse or defer. A received claim remains an attributed statement, not an automatic world fact.

Cover unknown actors, excessive/invalid content, unavailable targets, out-of-range delivery, repeated commands, duplicate delivery, cancellation, failed saves and cold restore. Keep provider error, world-rule rejection and the resident's voluntary `wait` separate. A timeout pauses/reports a system problem and retains the last valid decision; it does not invent a resident action.

Use a third explicitly labelled demonstration identity to test who did and did not receive information. Do not pretend that this identity restores a member of the original world. Do not refill the well, invent a new water source, infer Mira's structured `need` from prose, or force a successful request. Begin with the existing well path; only add the smallest native navigation example when an actual obstacle/new destination requires it.

## P3: model change and original-world continuity

A replay proves deterministic world submission and recovery within its test. A fixture provider proves adapter/rule boundaries. Running the same weights through two inference servers proves a runtime substitution. None of these alone proves the two-actual-model experiment.

For P3, use two different actual models to make new decisions in the same isolated save. Preserve previous state and provide the appropriate resident view. Record identity/model provenance, accepted command IDs, prior and resulting world facts, and cold recovery. The models may choose differently; identical wording is not required. A valid refusal is not a completed delivery.

Model/weight licensing, hardware and any paid-call scope, ledger, cooldowns and stop condition must be established before a live run. Missing evidence keeps the release at technical-preview status; it does not authorize fresh billing or repeated calls until a desired answer appears.

Separately preserve all 13 original identities and recover the three existing active residents when the complete source is available. Migrations write separate outputs, compare identity/history/ownership/resources/commitments/events and report unsupported data. Never overwrite or silently replace the maintained world with public demonstration state.

## Dependencies selected by vote

- **Keep (6/6):** Godot, the current pinned OpenGameAgent commit, world_kernel/JSON state, existing SceneTree tests, authored market and Blender sources.
- **Bounded build trial (6/6):** chickensoft-games/setup-godot. Pin an exact Action SHA and engine/templates. The Action installs tools; the project still needs export presets, .NET build, import, tests and independent package verification.
- **Native capability as needed (5/6, one defer):** NavigationAgent3D/NavigationRegion3D/AnimationTree, limited to a demonstrated movement/animation need. No whole-street rewrite as a communication prerequisite.
- **Optional after-preview trial (5/6, one defer):** one Ollama provider through the existing IModelProvider boundary, with a separately reviewed model. No local-model installation required for ordinary preview use. Reconsider llama.cpp only after a concrete deployment/hardware/performance gap appears.
- **Deferred:** Quaternius single-character trial (1 yes / 5 defer), Kenney UI/sounds (2 yes / 4 defer), Poly Haven first-release material work (0 yes / 5 no / 1 defer). Retain the candidates and license evidence; gather actual readability feedback before another scoped proposal. Do not import them now merely because they are available.
- **Do not add now (0/6 support):** Beehave/LimboAI as mandatory orchestration, wholesale migration to GUT/GdUnit4, or a new LiteLLM/agent/vector/GraphRAG/AI Town runtime stack. Reconsider only a measured gap, using one isolated example and a clear exit path.

The recommended rights proposal passed 5/6 with one defer: MIT for original code, CC BY 4.0 for original art and standalone documentation, third-party terms preserved by scope. This is a proposal to the rights holder, not a license grant. If mandatory openness of derivatives is desired, revisit the code-license choice before publication.

## First contribution paths

Open a small number of tasks tied to the current gate: startup documentation, independent export reproduction, one message-boundary regression, recipient/error display, one cold-restore counterexample, or a bilingual instruction fix. Each task needs relevant files, expected behavior, a verification command/result and an acceptance owner. World-authority changes receive maintainer review; they are not context-free beginner tasks.

Measure discovery → launch → understood consequence → first accepted contribution → return. Code, art, translation, documentation and testing can all count when accepted and verifiable. Automated agent PRs, stars and expressions of interest do not count as independent community adoption. If participation stalls, classify the obstacle and shrink tasks rather than expanding the world by default.

## Scope and historical authorization

Implementation authorized on 2026-09-10: continue this roadmap in visible batches and reassess direction after each batch. Additionally perform a formal direction review after every **100,000,000 raw development tokens** (input plus output, including cached input). This is a review interval, not a hard spending allowance or an API currency budget. Record root/worker deltas from actual session counters with `tools/record_agent_usage.py` in an ignored local ledger; repeated cumulative snapshots must not be counted again. A checkpoint is observed between batches, not enforced continuously by an automatic limiter. Reuse small task contexts when useful; do not assume a new conversation guarantees a cache hit. Prefer the user's requested Codex 5.3 family for simple bounded work when available; Kimi work still needs an available invocation path and applicable billing prerequisites. This batch used GPT-5.3-Codex-Spark for a bounded audit and reused that task for a static check; no Kimi coding or live resident call was started.

This review did not implement gameplay, import candidates, run paid models, publish a release or contact external people. It does not resume old heartbeats or reset previous development/API accounting. Current owned research workers have finished; later implementation must follow the applicable user-authorized scope, and live calls require their own verified prerequisites.

Earlier G0–G3 migration/budget records remain available in [the prior roadmap at 59bd52e](https://github.com/dotafs2/InfiniteAincrad/blob/59bd52e/ROADMAP.md) and the private transfer records. Those historical deadlines and automatic-run instructions are not fresh authorization. No original-world gate is marked complete by this public-preview plan.

Full geography, VR, multiplayer, combat, autonomous code installation, generic plugin marketplaces and a replacement engine/backend remain outside this first collaboration release.
