# H108: Rich character dossiers and decision integration

The user approved proceeding after review with very rich SAO-inspired NPC characterization, including currently unused traits. The [design review](../design/character-depth-review-2026-09-18.md) approves that direction and separates original authorship, authoritative world facts and future mechanics. The [complete ten dossiers](../design/resident-dossiers.md) are available for inspection.

## Delivered behavior

- Ten original seed residents now have distinct temperaments, ideals, attachments, flaws, goals and voices; all eight situational facets differ between residents.
- Each dossier contains 21 detailed sections and 12 descriptive personality dimensions. Unimplemented progression, equipment and ability values remain explicitly unknown. Relationship and personal-knowledge records start empty, with future evidence fields and channels documented.
- New seeds attach profiles explicitly. Existing saves remain loadable without profiles and are never automatically rewritten or enriched by stable-ID lookup.
- The actual turn composer sends the deciding resident's six core fields plus bounded situational guidance. It selects context from current needs, machine action types and already observed proximity. Full stored details, private concerns, author notes and extensions stay outside the request.
- Selection uses action types: a skill-sharing option containing `wood_repair` is learning, and a resident ID containing `repair` does not falsely turn a social action into work.
- Complete profiles persist with the production JSON codec; traits never create skills, goods, friendships, episodes or mechanical effects. Existing skills and genesis allocations are unchanged.
- Current roadmap and standalone HTML/SVG/PNG were regenerated together, with 38 nodes and no browser script errors.

## Verification

Results and exact local evidence references are in [checks.json](character-depth-2026-09-18/checks.json).

| Check | Result |
| --- | --- |
| .NET build | Passed; zero warnings and errors |
| Python authoring, archive and workflow tests | 27 passed |
| Rich-profile runtime acceptance | 42 checks passed |
| Existing life, turns, English and context acceptance | 107 checks passed |
| Local HTTP adapter cases | Six cases passed; the two history phases were rerun after action-context review |
| Complete eight-stage offline workflow | 179 checks passed; zero engine errors or warnings |
| Complete dossier preservation through physical continuation | All ten profiles exactly equal to their genesis values |
| Paid model calls / subagents | Zero / zero |

The actual history-bearing HTTP requests carry self profiles of 1,017 bytes for the owner and 961 bytes for the distant smith. Prompt sizes are 12,782, 13,010 and 8,506 UTF-8 bytes, below the unchanged 24 KiB provider guard. The informed resident retains the exact four newest personal events, as in H107; its historical skill, place and material knowledge remains sourced. Full history and full character data remain in the world. Private/author/dormant sentinel fields are absent from every captured request.

The runtime checks cover a large unused extension, null unknowns, exact floating-point preservation, cold restore, projection copy isolation, missing or malformed schema/identity/sections, storage bounds and multi-byte projection limits. Legacy behavior regressions pass without installing profiles into old residents.

The ten-resident offline workflow passed with the new dossiers through proposal, review, release, use, physical travel, interrupted work and cold continuation. All eight stages passed 179 checks, with zero engine errors or warnings. All ten complete profiles are exactly preserved from genesis through final read-only cold restore. Resident and GM decisions are scripted; actual bodies, world rules, persistence and consequences are exercised.

## Failures retained during development

The first profile test reported two equality failures. Its fixture used Godot's generic JSON parser, which produced floating-point values for integers, while the production codec restored them as integers. An initial encoder-only correction did not remove the parser mismatch. Diagnostics isolated the difference to nested numeric design fields. The test now reads and writes with the same production codec as the world, and compares full values exactly. No tolerance or assertion relaxation was introduced; the high-precision dormant value also survives. The initial and diagnostic runs remain under `private/characters-20260918/profile*`.

Code review also found that searching entire action IDs for `repair` could misclassify a skill notice or a resident's name as work. The selector now uses the authoritative action type, with two regression checks for these cases.

## Remaining boundary

Original seq450, GM memory and ledgers are still on the other computer. This delivery enriches new seeds and establishes the runtime/storage mechanism; it does not claim that the original world's ten historical residents have already been migrated. Their continuity needs review against that actual save.

Independent conversation, voluntary personal disclosures, person-specific shared-memory retrieval, relationship reducers, daily schedules, appearance realization and trait growth remain future work. No paid language model was used to establish that these traits already produce believable long-term behavior. Existing navigation overlaps in the sixteen-house quarter and earlier renderer issues remain separate open items.
