# Independent review: 44 original skin forms

Reviewer: city-motion subagent, independent of the skin implementation author.
Date: September 28, 2026. Verdict: **PASS for catalog, geometry and state scope**.

Read the definitions, motif construction, shared visual lifecycle and accretion
shader. Ran the author's final actual geometry suite independently: 991 assertions
passed for 27 Classic and 17 Special forms. It checks IDs, original ownership
migration, thumbnail vertex projection, mesh/triangle budgets and the default
blue shader parameter.

Additionally authored and ran `tests/city_review_skin_catalog.gd`: 212 assertions
passed. Each of the 44 player visuals was built twice on the same node to test
cleanup, checked for unwanted physics or a display-only mouth in gameplay,
advanced through its actual material clock, and inspected triangle by triangle
for obstruction of the central 70 percent of the swallowing disk. All passed.
After the author detected and repaired reversed extruded motif cap winding,
the reviewer added separate signed-volume and closed-edge manifold checks.
All 18 affected forms now have outward clockwise closed surfaces with exactly
two triangles per geometric boundary edge. Both suites were rerun after that
repair; this verdict supersedes the earlier 913/176-check pass.
Complete exact hashes and per-form metrics are recorded in
`artifacts/audit-fixes-20260928/skin-catalog-independent.json`.

New Special entries explicitly identify themselves as cosmetic; the five
existing ability kinds and original ten migration thresholds remain intact.
The new original silhouettes are not assertions of licensed reference artwork.

Limitations: primitive geometry, material inputs and projections were checked
headlessly. Browser screenshots, shader-deformed pixels, subjective likeness
and iPhone GPU cost require rendered/device evidence. The root task separately
tests catalog paging, purchase/equip persistence and actual UI input routing.
