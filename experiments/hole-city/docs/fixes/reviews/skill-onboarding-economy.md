# Independent review: first-use skills and coin shortfalls

Reviewer: food-city implementation agent, separate from the skin agent who
implemented these corrections. Status: **PASS for the tested UI, input and
persistence scope**. The reviewer did not modify runtime code.

The final scope audit found two unfinished details from UI-02 and UI-06:
collection descriptions did not provide an in-round first-use prompt, and an
unaffordable unlock did not state the exact coin deficit. Both are now covered
by an independently authored `tests/food_review_skill_economy.gd` with **183
passing assertions**. The strict release runner found no unexpected engine
errors. The earlier independent collection touch suite was also rerun with
156 passing assertions, and the portrait movement/animation/input regression
with 30 passing assertions. Source hashes remained unchanged across these runs.

The lesson uses the actual equipped player's definition rather than a stale
collection preview. All five existing ability kinds were checked on both map
layouts for effect text, actual repeated cooldown, and either the visible
manual button name or automatic trigger. All 39 cosmetic forms, including
the 34 newly authored skins, return no fictional gameplay-skill lesson. The
lesson remains throughout intro and the first six active seconds, then clears;
it is absent while paused and on home or result screens.

Source inspection verifies `draw_round_skill_lesson()` is called on the actual
intro/playing drawing path, after the intro shade. Its drawn panel introduces
no input-catching control. The 540 × 960 layout clears food objectives,
notices, movement instructions, skill and boost targets. Actual Fredoka font
measurements use the shipped 25-pixel title, 17-pixel trigger and 17-pixel body:
all effects wrap to at most two lines, leaving the movement reminder clear.
The earning explanation fits both the navigation footer and result card.

The independent probe sends real screen-touch and drag events through the
viewport. A touch inside the lesson begins the round and subsequent dragging
steers the hole. A second finger triggers the actual speed effect and its
nine-second cooldown without releasing the first joystick finger. Tapping the
automatic Bloom control does not pretend to manually activate it; the real
automatic gameplay path applies its documented twelve-second repeat cooldown.
The effect descriptions were compared to the actual five runtime skill paths.

Coin assertions follow real transaction and settlement calls with explicitly
identified fixture scores. Starting with 49 coins reports a one-coin deficit
against a 50-coin unlock, preserving saved bytes, equipment and ownership.
A 37-point timeout awards three coins; a successful initial unlock leaves two
coins and correctly reports 68 missing against the next 70-coin price. A
500-point win contributes 50 score coins plus 20 completion coins; the second
unlock leaves two coins and reports 88 missing against the next 90-coin price.
Real collection touch presents the current shortfall. Cold restore retains
these results; a forced save failure rolls back purchase and equipment; a
completed collection does not invent another coin deficit.

Evidence is under `artifacts/fixes-20260928/food/`:

- `skill-onboarding-economy.{log,json}` and `skill-onboarding-economy-hashes.json`.
- `skill-regression-ui_collection_review.{log,json}`.
- `skill-regression-portrait.{log,json}`.

Every process used `--test`. The fixture's PID-specific temporary save and
temporary replacement were removed, and all owned processes exited. No real
player save, live preview or foreground application was changed.

After the final 33-suite release passed, the reviewer ran this separate
183-assertion suite again against the actual published `build/web/index.pck`.
The real strict `acceptance()` runner used an in-memory marker mapping, an
absolute external test script and the package directory as its working
directory. All **183 package assertions passed**, with no unexpected engine
errors. Source and package lesson metrics are identical. The original review
test/runtime hashes still match, and the package/runtime hashes match the
final release manifest. Reviewed PCK SHA-256:
`70d5ae6efbc6520a9b910e61ed4855c2bcc42287c6cb9da1e31cac55cfa29323`.

Final package evidence: `skill-onboarding-economy-package.{log,json}` and
`skill-onboarding-economy-package-summary.json` in the same evidence directory.
This additional source/package pair is reported separately from the release
gate's 33 suites; it does not inflate that gate's assertion count. No package
or runtime file changed during the standalone review, and its process exited
before the parent's final isolated CPU measurement.

These are source, native headless input, font geometry and persistence checks.
They do not establish browser pixels, physical-phone touch latency, human
first/second earned-unlock pacing, reference economy parity or iPhone FPS.
