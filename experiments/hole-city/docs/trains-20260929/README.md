# Sushi Express and City Tram — v0.10.0

Snack Garden gains an eight-car Sushi Express: a gunkan engine followed by
salmon, tuna, shrimp, glazed eel, tamago, salmon roe and mackerel. Sunny City
gains a four-car light rail. Both use the same edible-car controller and actual
Blender-authored models. The original eight moving vehicles in each map remain.

## Play rules

Each section has its own rigid body, collider, size requirement and score.
A normal hole scan or pull admits one section through the existing gravity
and ownership rules. Cutting the middle parks every downstream section at its
current position; those sections remain edible. The head and still-attached
cars keep following the recorded head path. Eating the head parks the whole
remaining train; eating the final car leaves all earlier cars running.

Detached sections never respawn, rejoin or teleport. Score is awarded only
after the complete car falls below the normal collection depth, once, to its
legal owner. Sushi cars are worth 10 points and light-rail cars 15 points.
The existing four-minute timer and skin/economy rules are unchanged.

The Sushi Express follows the curved outer food boulevard at 6.4 m/s, and the
City Tram follows the outer avenue at 7.2 m/s. Loops measure approximately
609 m and 668 m respectively. A distance/direction pill points to the nearest
remaining car while it is more than 18 m away. Routing stops outside active
play and continues during the player's brief respawn.

A severed tail becomes a real obstacle on subsequent laps. The controller
plans a bounded, collision-checked passing branch, and trailing cars follow
the head's actual trajectory. Unexpected food or fragments may also require
a branch. If the whole corridor is blocked, the train waits for clearance;
it does not push through objects. Visible branch markings follow the exact
planned curve.

## Assets, terrain and budgets

Ten original GLBs and their editable `.blend` source were generated in real
Blender 3.6.23 LTS. Each model has one vertex-color material surface, rounded
edges and moderate gloss; no image textures are required. Imported vertex
colors are explicitly enabled by the asset adapter. The whole GLB set totals
581,572 bytes and 9,844 triangles. The installed food train uses 8,084 model
triangles; the four-car tram uses 3,672, plus tiny shared coupler meshes.

Rails and sleepers are painted through one mipmapped 1024² R8 mask on the
existing cut-ground shader. They add no rigid body, supporting floor or mesh
that could bridge a hole. The CPU retains two 1 MiB buffers, and the texture
uses approximately 1.33 MiB including mipmaps. It uploads at initial build and
when a planned branch changes, never on ordinary movement frames. Returning
home and switching maps release the controller and texture.

- [Original Blender source, manifest and model render](assets.md)
- [Independent route clearance](route-review.md)
- [Controller rules and focused acceptance](runtime.md)
- [Independent gameplay and asset review](independent-review.md)
- [Independent ground/UI/lifetime review](surface-review.md)

## Verification scope

Independent review found and corrected three concrete integration defects:
Godot retained the GLB color buffers but disabled their material flag; a
temporarily falling middle car could reject the first bypass plan permanently;
and returning home retained the controller and track buffers. The adapter now
enables the real palette, unresolved plans retry at a bounded half-second
interval while respecting collisions, and home teardown clears both runtime
references. The original failed cases remain recorded and pass after repair.

The focused suites pass 220 author controller checks, 161 author ground/UI
checks, 388 independent gameplay/model checks and 1,121 independent
ground/input/lifetime checks. Raw exported-buffer/source validation passes
246 additional checks. The independent reviews and final reruns retain exact
input hashes and earlier rejected evidence.

The first complete gate also caught a stale-owner bug in the unchanged rival
combat fixture: after replacing its city, the controller tried to hide a freed
coupler. Ownership checks now require the original city to remain valid and
current; link access also tolerates individual visual removal. The original
58-check combat test passes unchanged, alongside independent destruction and
replacement cases. The rejected gate remains under
`artifacts/trains-20260929/release-rejected-city-lifecycle/`.

Two old geometry fixtures required explicit maintenance. Food count assertions
now retain the exact original 2,922 bodies and separately require eight train
cars. A unit-scale assertion keeps every body in scope but allows a fixed
1e-6 vector tolerance: four new oblique train poses had a measured component
error of only 5.96e-8. No map geometry was rescaled. The
[independent fixture review](fixture-maintenance.md) records the measurements,
unchanged collision requirements and rejection counterexamples.

An initial isolated native Mac sample records 2,400 calls to the added `train.step`:
P95 is 1.239 ms for an intact city tram and 0.732 ms for an intact sushi train.
Middle-cut samples include planning and the track-update callback; their
largest calls are 10.960 ms and 8.758 ms respectively. Those one-time peaks
are retained in the report. These timings exclude the rest of the game and
all rendering, so they do not certify an iPhone frame budget. This initial
sample precedes the final owner-lifetime guard; its exact source hashes remain
recorded separately.
[Raw samples and scope](../../artifacts/trains-20260929/cpu/summary.json).

The author's mask fixture also needed a physics synchronization point after
manually advancing 60 route steps. Its unchanged bypass assertions now run
against current native collider transforms. Independent surface review confirms
that correction. Its separate real-touch fixture stops and drains its test
audio playback before process exit, matching the existing audio-test cleanup.

The acceptance suites exercise actual scenes, imported resources, physical
falls, score receipts, collision geometry, route continuity, ground openings,
UI draw calls and lifetime. The Blender contact sheet is an asset render, not
a gameplay screenshot. Headless results do not establish browser appearance
or sustained iPhone 14 GPU performance. No browser capture, real purchase,
save migration, Git commit or publication is part of this change.

## Final local delivery

The guarded release completes **67 source suites and 67 isolated-package
suites, with 48,255 checks in each phase**, plus 246 direct asset checks.
All **775 tested input hashes** remain unchanged. The local preview at
`http://127.0.0.1:8768/` was switched to v0.10.0 only after both phases passed.
Static HTTP verification matches **all ten served artifacts** to that export.
Reload the page and start either map to load the new train content.

- [Full source/package manifest](../../artifacts/trains-20260929/release/release.json)
- [Actual served-file verification](../../artifacts/trains-20260929/verification.json)
- [Packaged controller acceptance](../../artifacts/trains-20260929/release/package-train.json)
- [Packaged independent gameplay review](../../artifacts/trains-20260929/release/package-train_review.json)
- [Packaged independent track/touch review](../../artifacts/trains-20260929/release/package-train_surface_review.json)

PCK SHA-256:

```text
f62eecd2a3f5deb45afca81b948086a5c853048fd40b08e057e35df9b45f364f
```

Earlier rejected runs remain in the train evidence directory. All owned
authoring/test helpers have exited; the existing local server and user saves
remain in place. This is a local deployment, with no Git publication.
