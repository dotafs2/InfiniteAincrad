# Independent review: pedestrian heading

Status: PASS for the controller fix. Reviewer: expand_skin_catalog; author: fix_city_motion.

The controller now derives speed from the full frame displacement, including pedestrian separation, then uses a speed threshold rather than a per-frame distance cutoff. A walker at 0.58 m/s is therefore admitted at 30, 60 and 120 Hz. The angular lag is deliberately bounded to 15 degrees. The imported models face local +Z: their Blender shoe toes and face details point along -Y, which the GLTF Y-up export maps to +Z. No compensating rotation is applied when the model is attached, so atan2(x, z) agrees with the actual model direction.

The reviewer reran tests/city_motion_acceptance.gd independently: all six assertions passed. Moving samples at 30/60/120 Hz were 19,477 / 38,954 / 77,968, with no sample exceeding the 15.05-degree criterion. An additional independent five-direction probe at all three rates passed 31 assertions, including convergence within 0.001 radians after one second and retaining the resting direction at zero speed.

The review tests the real controller and authored orientation. It does not certify browser rendering, human visual preference, phone FPS, or the separate pedestrian overlap issue. The author is continuing other edits in the same source file; this hash identifies the exact reviewed snapshot.

- Reviewed catalog_city.gd SHA-256: `d5dd6023f918f635082f7edac3bdcd80f22fce941f33290f7721437334e7c469`
- Independent rerun: `/tmp/hole-city-independent-heading.json`
- Additional probe: `/tmp/hole-heading-review.gd`
- No user save or foreground app was touched.
