# H111: Aincrad governance, fixed navigation and GM/NPC preparation

The active world stays `shared:restart-20260918-01`, seq43. No paid request, native
GM turn, new resident decision or live adoption occurred in this delivery.
The complete world remains byte-identical and passes production cold restore.

## Implemented behavior

The [world charter](../design/aincrad-world-charter.md) distinguishes Aincrad source
material, original persistent residents and developer GMs, and future mechanics.
Production policies must pin that charter plus the reusable action standard.
Each proposed scope declares its setting basis, rationale and six preserved
invariants. The main review explicitly assesses setting compatibility against the
same contract. Missing/stale pins, editing protected documents, missing review or
post-review document tampering prevent release. These structural gates preserve
review provenance; they cannot automatically prove that every new mechanic fits
the fiction. Concrete semantic review and behavior tests remain necessary.

The three GM phases and resident model instructions carry the setting constraint.
Historical labelled offline fixtures can retain their old contract; an explicit
design pin makes the new gates apply to them too. Existing production policies
must be consciously updated to the current pins before further paid dispatch.

Navigation already used Godot's existing system. The change reuses its A* corridor
cache, instead of querying a complete path every physics frame. RVO still supplies
safe velocities; CharacterBody3D collision still executes motion. Known goals,
doorway legs, fixed walking speed and world-owned arrival checks remain authoritative.
Changed commands/targets, map revisions and a repositioned body invalidate the route.
The existing road-graph fallback remains necessary across measured bake gaps.

This follows the [Godot NavigationAgent documentation](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html):
navigation supplies a route while application physics moves the body. RVO does
not understand all world collision or guarantee freedom from crowd deadlocks.
Fixed algorithms do not imply identical floating-point trajectories on every machine.

## Actual verification

| Scope | Result | Limit |
| --- | --- | --- |
| Design, autonomy, fresh-world binding and stable GM identity/resume | 169 focused + 62 production-bridge Python checks passed | Local fake provider for runner tests; no real GM inference |
| Stock navigation and real wall collision | 12 checks; 12.1596 m travelled; 136 frames, one path update | 4x simulation clock; original 1.35 m/s speed; map remove/restore and unreachable goals covered |
| Two-person physical journey | 24 checks; 72.6146/77.3850 m; both arrive once after cold scene restart | Explicit fixture invitation and consent, not spontaneous resident choice |
| Ten-resident/ten-GM offline chain | 118 normal-stage engine checks; expected unreviewed-release refusal | Scripted choices and existing finite-material installation; no invented GM code or real models |
| C# build / local HTTP provider | Zero warnings/errors; four cases passed | Action groups, success/repeat refusal and town projection; local loopback only |
| Active seq43 checkpoint | Every nested saved value survives cold restore | Source hash remains `a0228906f6b417db2e9b3faae335fae6cc81d2a11810f109efd93f53a55ccd2a` |
| Fresh-world GM bootstrap | Ten bound identities; all ten planned by no-dispatch preflight | No native sessions or GM opinions yet |

Safe machine evidence is in [checks.json](aincrad-gm-navigation-2026-09-18/checks.json).
The complete empty GM bootstrap is under
[world GM checkpoint](../../worlds/restart-20260918-01/gm/bootstrap.gm-state.json).
Original seq450 and its later GM history remain separate; this does not migrate them.

## Gaps against the intended outcome

1. **Latest GM accounting continuity:** a September 14 local reference exists,
   but explicitly carries unresolved GM costs and missing other-machine history.
   It cannot establish the latest September 18 baseline. No unknown fee was
   reset, settled or repeated. The current Kimi ledger is a separate existing stream.
2. **Fresh-world production release:** the older host supports bounded existing
   installations. A concrete deployment manifest, candidate tests and runtime
   verification for arbitrary new H110 action modules still need preparation.
   A policy hash and successful offline example alone do not provide that adapter.
3. **Autonomy and adoption:** a real GM/NPC iteration with the new setting contract,
   original-GM feedback and voluntary new capability use remains unobserved.
   Renewable professions, stronger social memory, navigation overlaps and crowd
   limits also remain open. This delivery does not claim an infinitely running world.

The next paid cycle must retain this same save and GM identities, carry verified
accounting, pin a concrete release target, then observe genuine need, develop in an
isolated candidate, review, continue the same world and ask the original GM to
evaluate actual effects. A no-change or unused result remains valid evidence.

## Failures and process ownership

Two broad Python suite attempts timed out at 120 and 90 seconds while creating
large candidate checkouts. They are not passing suites. Owned Windows job trees
exited; three exact test worktrees under the owned temporary prefix were removed.
The focused replacement passed 169 checks in 50.44 seconds.

The first joint test invocation omitted the required town-save flag. Initial map
tests incorrectly assumed a fixed frame count established asynchronous map/bake
completion. A new Python test initially had a misplaced assertion. These were
corrected and rerun; failed logs remain under `private/aincrad-20260918/`.
No user process was stopped. The offline candidate remains as inspectable evidence.
