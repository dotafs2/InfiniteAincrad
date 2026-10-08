# Round skill onboarding and exact coin shortages

Date: 2026-09-28

Equipped functional skins now explain their actual effect, the visible button name or automatic trigger, and their cooldown before movement and during the first six active seconds. The lesson is drawn without input controls, below either map’s objectives and above the swipe tutorial; pause hides it and the timer advances only with gameplay. Cosmetic skins in either collection have no ability lesson. No new save field or unlock rule was introduced.

An unaffordable random unlock reports the exact current price and missing coins, with a short “Need N more coins” toast. Home, Store and Holes retain an accessible earning rule that explicitly says score divided by ten, rounded down, plus twenty for a win; results also show this rule when the new-level caption is absent. Actual reward arithmetic is unchanged.

The existing gated skill suite passed 130 assertions, retaining ability physics checks and adding equipped identity, all five functional kinds, Classic and Special cosmetic exclusions, real viewport screen-touch routing through the lesson, lifetime, pause, measured text fit and both-map HUD clearance. The existing gated coin suite passed 403 assertions, retaining transaction, migration and cold-restore checks and adding exact deficits after real score settlement and a subsequent purchase. Both ran with `--test` and the release helper’s strict engine-error filter. The coin suite’s deliberate corrupt-save fixture remains the sole permitted fixture parse error.

Evidence: `artifacts/fixes-20260928/skill-onboarding/`. The source manifest freezes the two runtime files and two existing gated tests. This is author verification; the independent food-city reviewer receives the frozen files separately. Headless geometry, font metrics and input routing do not establish final rendered appearance or mobile GPU performance.
