# Independent review: inherited NPC motion and separation

Reviewer: food-city fix agent, independently from the city-motion implementation author.

**Pass for the exercised controller behavior.** A separate Snack Garden probe runs actual city motion at 30, 60 and 120 Hz, including panic near the player, curved sidewalk boundaries, a deliberately coincident eight-person group, and transfer to physical falling. It does not repeat the author's straight-city dense-pocket coordinates.

17 assertions passed. Moving samples: 23,286 / 46,474 / 92,727 respectively. All three rates had zero heading deviations beyond 15.05 degrees, zero capsule overlap samples below 0.46 m, and zero sidewalk escapes. Minimum natural center spacing was at least 0.480000 m. The dense group resolved to 0.480019 m. A person above the mouth released before the separation solver and received no scripted horizontal displacement afterward.

Inspection confirms orientation uses actual post-separation velocity rather than a frame-dependent displacement threshold. The solver considers only frozen unclaimed people and clamps corrections with the map-specific sidewalk function. The review hashes the three relevant functions independently because the city author is editing unrelated vehicle logic in the same file.

Evidence: `tests/food_crowd_review.gd`, `artifacts/fixes-20260928/food/crowd-review.log`, and `crowd-source-hashes.json` in the same directory.

Command: `.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script res://tests/food_crowd_review.gd --log-file /tmp/hole-food-crowd-review.log -- --test`.

Limits: headless controller evidence, not a rendered gait/animation assessment or phone performance measurement. The probe covers 20 simulated seconds per rate and does not establish arbitrary-density crowd solvability.
