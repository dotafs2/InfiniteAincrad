# Gate Siege

A standalone portrait Godot shooter combining the supplied multiplier-gate reference with the second clip's additive recruitment lane and whole-squad upgrades. Version0.3.1 adds an authored eight-wave campaign, articulated creatures and five weapon modes. Original commercial assets, narration and platform watermarks are not included.

**Local play:** <http://127.0.0.1:8810/>. Click **DEPLOY**, then drag sideways or use **A / D** or the arrow keys. Shooting is automatic. Move your formation into the right-hand **+1** lane to recruit real soldiers, up to36. Shoot the numbered statue to upgrade the entire formation when its airborne hero lands. The cyan ring ahead of the formation marks the shared shield; steer it out of red attack warnings.

**Weapons:** select the bottom buttons or keys1–5. RAPID is available immediately; SCATTER, RAIL, ROCKET and ARC unlock in waves2–5. Their effects are individual rapid fire, five-pellet spread, six-target piercing, area damage and five-link lightning. **P / Escape** pauses, **R** restarts, and **SFX** toggles sound. **QUALITY** on the start/pause panel selects AUTO / LOW / HIGH.

## Campaign and presentation

- Eight waves: First Contact, Iron Wall, Skitter Rush, Emerald Wings, Storm Battery, Twin Talons, Crimson Siege and The Sky Tyrant.
- 36 persistent soldiers with independent firing contributions and muzzle positions. Class upgrades preserve the roster; newly recruited allies inherit the active class and weapon.
- A raised city runway, opposed ×5/armored ×999 gates, a fixed ×2 gate, scrolling +1 cards and the original asymmetric boss/statue layout.
- Brutes, armored golems, six-legged skitters, dragons and smaller flying drakes. Wings, tails, arms and legs animate during gameplay; pause freezes them, and deaths settle before transition.
- Per-member ground silhouettes/contact shadows, luminous projectile trails, whole-formation gold upgrade rings, detailed original costumes and batched city scenery.
- Troop/elite HP, delayed area coverage, depth ordering, piercing limits, grouped rocket/arc effects and spatial multiplier crossings. Later siege bosses hold behind the final multiplier and attack the shield with visible warnings; troops and elites continue advancing.

The eight-wave structure,36-person cap, completed upgrade tiers, additional creatures and weapon selection are authored extensions. The supplied clips do not establish these rules. This combines their observed mechanics and rendering cues; it is not a certified pixel-identical reconstruction.

## Cosmetic bullets, deterministic damage

At the user's request, displayed streaks are cosmetic. Combat merges the squad's firing energy into32 lateral cells and advances coverage fronts at10Hz. Partial overlap determines damage and gate multiplication; no individual bullet collision exists. The GPU animates bounded decorative streaks from their birth time, so the CPU does not move every visible bullet. Recruitment, class changes, weapon differences and enemy HP remain gameplay state. See [the coverage contract](docs/expansion/coverage-combat.md).

## Verification and mobile target

Two agents audit reference requirements, rendered output, mechanics and exported play. Current evidence and acceptance status live in [the expansion runtime review](docs/expansion-runtime-review.md), [visual review](docs/expansion-reference-visual-audit.md) and [continuation](docs/CONTINUE.md). Earlier0.2.x tests and videos remain historical and are not counted as current coverage-combat acceptance.

AUTO/LOW target30FPS, retaining a1280px portrait3D long axis and full-resolution UI. Geometry batches, reusable squad buffers, bounded GPU cosmetic pools, sparse coverage queries and crowd LODs control workload without removing logical enemies or soldiers. AUTO can lower cosmetic budgets; it does not reduce damage, roster size or the current1280px resolution floor.

The provisional audience/device floor is casual short-session players using Snapdragon665/HelioG80-class Android phones with3–4GB RAM, with older iPhones a secondary group. This is a product target, not measured demographics. Desktop GPU results are not evidence of sustained phone30FPS or thermal stability; physical-device acceptance remains open. See [the device target](docs/mobile-performance-target.md).

## Run and reproduce

Double-click `Launch.command`, or open `project.godot` in Godot4.7.2 and press F5. This project is isolated from Hole Feast and resident worlds, using its own Gate Siege user-data directory.

```sh
.build/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/expansion_review.gd
.build/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/coverage_review.gd
python3 tools/serve_review.py --port 8810 --directory build/web --pid-file artifacts/preview-server.pid
```

The standard non-.NET editor is bundled locally in `.build/Godot.app`. The export preset references the existing matching Web template in the sibling project's `.build` directory without modifying that project. On another computer, point the preset at a matching installed Web template.

## Sources

The original template search examined the [official Godot TPS demo](https://github.com/godotengine/tps-demo), [Chafmere third-person template](https://chafmere.itch.io/third-person-shooter-template) and [Kenney FPS starter](https://github.com/KenneyNL/Starter-Kit-FPS). None matched the camera/loop, and none of their code or art is incorporated.

Character/creature GLBs and sound cues are original project assets; Blender sources are in `art_source/`. Barlow ExtraBold comes from the [official Google Fonts directory](https://github.com/google/fonts/tree/main/ofl/barlow), under SIL OFL in `assets/fonts/Barlow-OFL.txt`. Godot is MIT licensed. The reference videos remain outside the playable package. No Git publication or public hosting is performed for this iteration.
