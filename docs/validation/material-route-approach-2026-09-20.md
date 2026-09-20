# H125 material-route approach point

The H124 live checkpoint (`shared:restart-20260918-01`, seq250) recorded Carpenter at approximately 0.86 m from `street:iron-salvage-20260918`, with `turn:shared:carpenter:0:31` still pending and only 3.6167 of its required 60 work seconds. The source was already exhausted (`initial3`, `recovered3`, `stock0`), so retrying the command would have been invalid and would not answer the route failure.

The inspected runtime has two separate rules:

- the world completes material work when the body is within 0.45 m of the source;
- the scene steering helper previously attempted to sweep the capsule to the exact source center, and only then tried a bounded detour.

The helper now tries a collision-cleared point 0.40 m from the source when the exact center is blocked. The destination remains the source center for world accounting, and the world still owns the 0.45 m arrival gate, 60-second timer, finite stock and receipt. The change cannot create a unit or bypass a collider.

## Owned replay

The repository toolchain supplied `Godot_v4.7.2-stable_mono_win64.exe`. Using a disposable `fixture:town-trade-validation` save and no provider calls, `town_material_travel_probe.gd` completed with exit code 0 and `open_path_passed: true`:

- final distance: 0.2900 m (inside the world's 0.45 m work gate);
- full 60-second physical work completed;
- receipt: `material_recovered`, quantity 1;
- source stock: 3 → 2;
- worker iron: 1 → 2;
- no stderr errors and no paid calls.

The first compile attempt also exposed that the other steering subclasses inherit `ARRIVAL_RADIUS`. That compatibility constant is retained in the fix; the material helper uses its separate 0.45 m work gate. The live seq250 save was not rewritten by this fixture replay, and its exhausted source remains untouched. The next live observation can continue the existing Carpenter command only after the normal preflight; it must not retry the old command as a new request.
