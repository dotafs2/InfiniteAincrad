# Growth after level 12

The original controller stopped at the last entry in its twelve-level table. Its last progress badge also divided by one. The controller now preserves every original threshold and radius and computes later levels from an increasing-cost rule.

For level `12 + n`, the starting score is `1250 + 25*n*(n + 13)`. The next levels begin at 1600, 2000, 2450 and 2950 points. Advancing from level 12 costs 350 points, and each subsequent level costs 50 more points than the previous one. The real badge displays points earned within the current level and its actual next-level cost. A square-root estimate followed by exact integer comparisons handles large awards without iterating through every skipped level.

The radius after level 12 is `14 + 34*n/(n + 17)`: level 13 reaches approximately 15.89, level 20 reaches 24.88, and level 212 reaches 45.34. Levels continue beyond the original table. Physical size smoothly approaches a 48-unit safety limit appropriate to the 160-unit map, rather than eventually becoming larger than the entire world. This is a deliberate geometric bound; it is not another nearby level cap. At extraordinary scores, finite precision also limits distinguishable size increments.

Scores use signed 64-bit integers. Rewards saturate at their storage boundary instead of wrapping negative. The largest representable score resolves to level 607400105 with a finite radius of approximately 47.999999. This numerical boundary is not intended gameplay. The first twelve table entries remain available for existing fixtures. `level_start_for`, `level_for_score`, `radius_for_level`, `level_for_radius` and `growth_progress` provide the extended runtime queries. An unreachable radius requirement returns level zero so the gameplay hint can use a non-level fallback.

Rivals move with a base speed of 3.5 instead of 4.6, and receive 70% of collection points. Exact integer tenths carry across rewards: fifteen one-point foods yield ten points plus five tenths, so low-value food still grows a rival. The accounting divides before multiplying to avoid overflowing on extreme receipts. A new rival begins with no remainder. Player points, pulse charging, base speed of 7.8, and the existing movement-skill multiplier retain their rules.

Camera framing, far distance, large-footprint hints and rival combat are integrated separately in `game.gd`. The 500-point city completion rule is unchanged. No persistent save schema changes are required because hole score, level and fractional rival rewards belong to a round. Multiple large holes can theoretically cover all ground together, so ground-empty handling needs its own scene-level validation; bounding one hole is not proof against every arrangement.

## Author validation

`tests/growth_extension_acceptance.gd` passed 1978 checks through the strict release harness. It instantiates real hole controllers with isolated game callbacks and does not load or write player progress. It checks every original boundary, 200 additional level transitions through actual awards and badges, geometric scale updates, increasing score costs, first-fitting growth hints, large receipts up to the signed 64-bit limit, exact rival fractional accounting, new-rival state, and actual player/rival movement velocities. Extreme expected values were independently calculated with integer arithmetic.

Receipts and source hashes are in `artifacts/growth-extension-20260928/author/`. These checks establish numeric and controller behavior under headless Godot. Full map geometry, camera framing, collision behavior and independent review are separate integration checks. They do not establish browser rendering quality or iPhone frame rate.
