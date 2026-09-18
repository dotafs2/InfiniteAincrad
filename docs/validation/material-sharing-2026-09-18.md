# H116 — Attributed material routes and local recovery

Continued from local `12fbf60` on `codex/continuation-20260918-self-repair`, containing the latest received online delivery `d2c0227`. H115 let a resident read the installed iron route; H116 lets that resident explicitly tell someone nearby. This is coordinating-agent implementation, not autonomous GM invention.

## Behavior

The versioned `knowledge.share_material_location` action raises the registry to 35 capabilities. It requires the speaker's real personal source evidence and an active recipient within the existing three-metre hearing range. It emits an attributed route statement with directions and work requirements, explicitly declaring stock unknown. Only actual participants receive the event; arbitrary speech is not promoted into verified knowledge.

A new listener receives the location and the immediate speaker's identity. Previously observed stock, including depletion, is preserved. Neither the offered menu nor the result reveals the listener's private prior knowledge. Cooldown and the speaker's own disclosure history prevent repeated disclosure to the same recipient. The listener may relay, collect, wait or choose another action. No goods, skill, contract or job are granted by conversation.

Command replay, rollback, earlier source evidence, exact spoken text, recipient range and the complete disclosure chain are validated on restore. Actual utterances reach the resident reply archive and GM public-life evidence; the model's reason and private source history do not become public speech.

Setting classification: a compatible original extension under the existing Aincrad charter. Ordinary conversation, physical travel, finite salvage and labor retain their established rules. The three-metre hearing gate, route phrasing and original residents are prototype content, not exact novel mechanics or geography. No new lore claim or cross-floor landmark is introduced.

## Final verification

| Suite | Passed checks |
| --- | ---: |
| Disclosure, privacy, attribution, relay, replay, rollback, corruption and depletion | 50 |
| Rich seq148 input and actual resident controller | 12 |
| Real town disclosure, movement, collection and mid-trip restart | 32 |
| Existing material rules | 58 |
| Existing notice rules | 34 |
| GM public-life evidence | 51 |
| Common capability contracts and lifecycle | 166 |
| Read-only restoration input controls | 11 |
| **Total** | **414** |

Zero paid calls. Ari's actual-controller input measured 12,435 UTF-16 units and Wren's 11,378, within the unchanged cap. The fixture selected sharing, then the recipient selected wait, proving that knowledge does not force collection. Additional earlier regressions covered own-tool repair, crowded capability turns and the original notice's physical path. [Machine-readable results](material-sharing-2026-09-18/checks.json).

The physical test copied the complete seq148 world without changing starting positions. Ari was 3.61 metres from the notice; Wren was 6.05 metres away and 2.64 metres from Ari. Actual visibility and reading preceded an explicit fixture sharing choice. Wren learned the route without reading the notice, then an explicit fixture collection choice walked **44.72992 metres**, at at most **1.35000 m/s**, with a largest sampled step of **0.09003 m**. A fresh scene resumed the identical complete state mid-trip. Direct arrival sight replaced unknown stock; sorting consumed one of three iron units and gave Wren exactly one. The disposable copy ended at seq157. These choices are controlled test input, not live model adoption.

The successful physical run retained the existing four-overlapping-edge navigation warning on each scene load. No script errors occurred in final runs. Early development failures included an incorrect event subject, a fixture indexing error and selecting a listener just outside hearing range; they were corrected without widening hearing range. Privacy review removed recipient-knowledge acknowledgement from both menu filtering and action feedback. Failed-attempt logs remain private.

## Restored state and current blocker

The active world `shared:restart-20260918-01` is now restored under `private/worlds/restart-20260918-01/`, still at seq148 with all 131 lifetime resident replies. The world-scoped developer-usage book was restored from the complete published snapshot, preserving all revisions, 20 actors and 144 calls; exact export equality was checked. The GM checkpoint is byte-identical to its published source. Native GM sessions are not in Git and have not been recovered here.

This recovery did not initialize a provider billing ledger. The prior live window used `kimi-city-validation-2026-09-07.sqlite3` and its matching `.guard.json`. Exact-name searches in the relevant local project and user folders did not locate them. A different available older provider ledger fails preflight because it contains an active reservation and uncertain requests; it was not substituted, reset or reconciled to force startup. The requested live observation is therefore still pending the correct existing ledger. No new provider or GM calls occurred.

Preserved world hashes:

- Active published and restored seq148: `cdfe0136856980281f671c14721815ac1bf5484cb77e930485edb9c435dc380a`.
- Separate original seq450: `a06a43ed7c5ca5e55aef3e7b2e51ecf54faf8d5cc2133c15c789ccbe754f600c`.
- Existing original-lineage local seq452: `e04c86112ac7afcf405d5832e1860340d00b19f997e97b31babeee951b24f4c1`.

The local entry folder has `OpenLatestWorld.cmd` for the restored seq148 in read-only observation mode. It supplies the current save and toolchain explicitly, uses no paid provider and does not inherit the older lineage's launcher profile. It shows saved positions and history, not a new live AI episode. Existing old-world launch entries remain intact.

Next: locate the original provider ledger and guard, then observe a bounded continuation for voluntary discovery, sharing, collection and self-repair. Natural adoption, renewable resources, sustained daily life and arbitrary module deployment remain unproven. GM06's unknown result and the older GM05 tail remain recorded; monitoring stays paused.

Reproduction: run `town_material_sharing_acceptance.gd` and `town_material_sharing_input_acceptance.gd` headlessly. For `town_material_sharing_scene_acceptance.gd`, pass `--source=<immutable seq148> --town-save=<new disposable world path> --out=<new result JSON path>` after `--`. The physical suite refuses an existing destination save. All these tests are offline.
