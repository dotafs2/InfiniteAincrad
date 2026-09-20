# H125 material-route approach point

The H124 live checkpoint (`shared:restart-20260918-01`, seq250) recorded Carpenter at approximately 0.86 m from `street:iron-salvage-20260918`, with `turn:shared:carpenter:0:31` still pending and only 3.6167 of its required 60 work seconds. The source was already exhausted (`initial3`, `recovered3`, `stock0`), so retrying the command would have been invalid and would not answer the route failure.

The inspected runtime has two separate rules:

- the world completes material work when the body is within 0.45 m of the source;
- the scene steering helper previously attempted to sweep the capsule to the exact source center, and only then tried a bounded detour.

The helper now tries a collision-cleared point 0.40 m from the source when the exact center is blocked. The destination remains the source center for world accounting, and the world still owns the 0.45 m arrival gate, 60-second timer, finite stock and receipt. The change cannot create a unit or bypass a collider.

This checkout did not contain a valid Godot executable for a scene replay; the discovered `godot.exe` was a test fixture and Windows rejected it as incompatible. `git diff --check` and Python compile checks pass. The next owned scene run must verify that Carpenter reaches the work gate and either completes the truthful depleted receipt or remains visibly blocked before another paid window is considered.
