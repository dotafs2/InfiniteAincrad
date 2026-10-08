# Music, food growth, original skins and movement boost

This revision addresses four reported problems: crowded music, a food map with
few usable intermediate targets, flat-looking skins, and a BOOST button that
did not increase movement speed. Existing player ownership and balances remain
compatible. No Git commit or publication is part of this local iteration.

## What changed

Both original music loops were recomposed. Four sparse parts replace the dense
accompaniment, high bells, countermelody and multiple percussion types. The new
tracks use 104/108 BPM, ordinary major/minor triads, a lower melodic register and
approximately 55% written melody rests. Their decoded loudness is about
6–7 LU lower than before. Existing independent Music/SFX preferences, gesture
unlock, pause/focus handling and the single streamed voice remain unchanged.
The full Ogg files total 294,922 bytes. The 12-second MP3 excerpts are previews
of the new assets, not recordings of the game's bus mix.

- [Sunny City excerpt](../../artifacts/feel-20260930/audio/sunny_city_loop-12s-preview.mp3)
- [Snack Garden excerpt](../../artifacts/feel-20260930/audio/snack_garden_loop-12s-preview.mp3)
- [Independent composition, signal and lifecycle review](music-independent-review.md)

Snack Garden previously had 1,377 directly available first-level foods but only
19 second-level targets; the starting area had 145 versus one. The revised map
redistributes 182 existing snacks into real level-two, three and four sizes,
with mesh and collision dimensions changing together. Every inner district
gets all three intermediate classes. Seven actual physical admission bands
remain available across the map. Three existing heaps now stand on broad
level-six cookie platters, each worth ten points. Eating a platter releases
58 separate upper foods. The city retains 2,930 total edible bodies, including
the train, 160 buildings and the same 34 shared food meshes.

The non-author test grows from zero using real touch input, with rain disabled
and rivals retired to isolate progression, then walks to all three platters.
All 177 heap pieces finish their own descent and generate
exactly one receipt each. Neither the natural route nor gameplay uses a direct
score/radius override. Optimized scripted route times are not a human retention
measurement. [Layout and before/after distribution](food-growth.md) and
[independent physical review](food-growth-review.md) give the exact scope.

Six existing cosmetic IDs receive original sculpted forms: Pizza Party,
Frosted Cake, Fox Den, Bunny Burrow, Rocket Port and Dragon Roost. Rounded
profiles, layered ingredients and lit materials replace their unshaded pieces.
The other 38 forms, rarity/ownership rules and active abilities remain intact.
Independent review also found that the real collection-card worlds had no
lights. Each card now receives one shadow-free directional light and a shared
ambient environment; only the selected card continues rendering/animating.
Existing card size, antialiasing and touch pass-through remain unchanged.

[The contact sheet](../../artifacts/skin-polish-20260930/before-after.png) uses
actual exported meshes rendered in Blender with approximated materials and
lighting. It is an asset comparison, **not a browser/game screenshot**.
[Original designs and geometry budgets](../skin-polish-20260930/README.md)
describe the six models; the [independent card and lighting review](../skin-polish-20260930/independent-review.md)
records the actual missing-light reproduction and fix. An initially suspected clearcoat restriction was
retracted after the full official documentation and GLES3 source disproved
it; [the correction](../skin-polish-20260930/clearcoat-source-check.md) is retained.
No competitor model, texture or character asset was imported for these forms.

BOOST previously spent its charge on an object pull while measured movement
remained 7.482 units/s before and after the tap. It now grants **2.5 seconds
of 55% faster movement**, retaining the existing bounded pull and seven-second
cooldown. The button distinguishes charge, ready, active and cooldown states.
Beacon Step has its own lifetime; simultaneous abilities do not multiply their
speeds or shorten one another. [Implementation](boost.md) and
[independent real-touch review](boost-review.md) cover two maps, different
sizes, partial joystick input, pause, expiry and fresh rounds.

## Review and fixture maintenance

Every implementation has a non-author review. Food progression and BOOST are
tested through actual viewport input, body physics and collection receipts;
the skin review visits the real collection cards at phone-sized viewports.
The old card implementation is retained as a missing-light counterexample.
Music is inspected through the complete score and decoded audio, alongside
the existing playback-state tests. It was not auditioned on phone speakers.

Four historical expectations intentionally changed and received separate
review: exact duration of the newly composed music, old mesh counts for only
the six replaced skins, and two opening-view geometry budgets affected by
repositioned food, plus the distinction between rain admission and later
physical reactivation. All other world, mesh, material and outer-view limits remain.
The food scene's total geometry falls by 384 triangles; conservative opening
batch submission increases by 3.19% and 0.48% for the two measured views.
Fixed caps and one-triangle/one-batch rejection cases replace the two old
layout-specific values. These geometry bounds do not establish phone FPS.

The first complete gate stopped at the old rain test's all-time limit of 24
airborne bodies. Per-frame traces showed a different event: one wave admitted
six bodies into 14 existing airborne bodies, then previously landed food woke
or lost support 51 frames later, without another spawn. The old map reached
22 bodies marked `not rain_landed`; the revised arrangement reached 29. That
conservative classification also includes some sliding or side-supported food.
The limit of 24 is
an admission capacity, not a physics clamp on food that falls again. The
initial accounting-only checkpoint leaves contact, sleeping and swallowing
physics unchanged. Bounded synchronous admission
snapshots let tests independently inspect actual body IDs and available space;
new drops stop when the capacity is full. The maintained test keeps sustained
rain, batching and invisible-only retirement requirements and adds explicit
rejection of an extra spawn or a false landed count. A separate physical review
exercises reawakening, support removal and subsequent ordinary consumption.
[The admission diagnosis](rain-admission.md) preserves the exact old/new traces.

That physical review also found an actual support-loss defect: sleeping rain
could remain suspended after its supporting collider disappeared. Native
contact wake-up was insufficient even in an attempted contact-slop revision,
so that broader physics prototype was withdrawn. The focused correction
remembers the actual support collider through a weak reference and checks its
continued presence, transform and collision layer in the rain body's existing
callback. If support changes, the original food wakes and leaves its cached
rendering batch. Gravity and the normal full-descent receipt path do the rest.
This adds no per-frame ray queries and does not disable sleep or force a pose.
The [final independent rain review](rain-admission-review.md) passes 392 checks
across five suites, including all ten recipes. Its long-run observations retain
the actual per-frame classification peaks of 30 and 21, rather than hiding
natural reactivation to meet a global count.

All early failed probes and corrections are retained, including the route
helper that stopped steering too early and fixed-fps audio cleanup races in
test fixtures. The exact previously delivered v0.10.0 PCK is preserved under
`artifacts/feel-20260930/baseline/` for reproducible comparisons.

## Delivery verification

The complete **76-suite source and isolated-package gates pass**
**53,788 source checks and 53,788 package checks**, with all **785 input hashes unchanged**.
The existing local preview is updated to **v0.11.0**. All ten actual HTTP files
match the tested export, including PCK SHA-256:
`dd34dfe38ff87f63170deac423242315de5258617d30f28b926b0eff6d92557f`.

- [Frozen release manifest](../../artifacts/feel-20260930/release/release.json)
- [Strict reports and served-file verification](../../artifacts/feel-20260930/verification.json)
- [Preserved first failure](../../artifacts/feel-20260930/release-first/source-food_rain_continuity.json)

An intermediate complete gate was explicitly interrupted after the reviewer
found a new fixture's missing local variable type; that failure and the
interrupted run remain preserved. The corrected fixture changed no product
behavior or assertion. The final runs use fresh evidence and stable inputs.

Current browser pixels, subjective musical preference, sustained iPhone 14
60 FPS and measured player retention are not established by these headless
checks or offline asset renders. No browser/native capture, player-save reset,
external account change or Git publication was performed.
