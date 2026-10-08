# Food street-network evidence — v0.5.4

`release.json` records matching source inputs and deployed Web package hashes.
Source and package each pass 4,584 checks. The `source-*` and `package-*`
JSON/log files are the individual engine acceptance results.

`reproducibility.json` verifies deterministic plan/atlas generation in a temporary
directory and rejects a simulated source change at the release gate.
`opening-cpu.json` and `grown-cpu.json` contain isolated 600-frame headless Mac
measurements. The final logs contain no GDScript exceptions; the opening log
retains one native contact-limit diagnostic. No GPU, browser or physical-phone
performance is inferred.

`districts.png` and `opening.png` render the actual food meshes, transforms and
street atlas through the shipped glaze equations. Final lighting is approximate;
NPCs, UI and contact shadows are absent. These are offline validation images,
not Godot/browser screenshots. Raw render fixtures and the renderer log remain
beside them for reproduction.

Owned processes: deterministic Python generator/check, headless Godot importer,
scene fixture exporter, acceptance runners, release runner, two CPU profiles,
Clang compiler, image conversion and windowless CGL renderer. All completed or
were explicitly interrupted before their final replacements ran. The pre-existing
preview server was retained. No foreground application or browser was controlled.
