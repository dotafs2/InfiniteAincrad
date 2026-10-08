# Independent review: continuous traffic

Status: PASS for continuous route geometry and traffic motion. Reviewer: expand_skin_catalog; implementation author: fix_city_motion.

The former straight-line boundary reset is replaced by distance along two rounded avenue loops. Modulo applies to route arc length; the position and tangent agree at the seam. The opposite loop reverses both sampled progress and travel direction. Cars use their actual forward tangent for rotation, retain route progress while stopped, and leave scripted traffic once claimed or released to physics.

The four-axis oriented-footprint test is a conventional separating-axis rectangle test. It includes both vehicles' longitudinal/lateral axes and both extents, avoiding the previous world-axis-box false overlap on bends. The reviewer inspected this separately from the test metrics.

The reviewer independently ran the complete 22-assert city motion suite. During its 180-second 60 Hz traffic trace, all eight vehicles travel 432–504 metres and cross two or three route seams. No jumps, heading failures, off-road center samples or footprint overlap samples occur; the largest frame displacement is 0.04667 metres. The same run retains successful pedestrian heading, crowded-edge separation and gravity-release checks.

An additional reviewer-authored geometry probe checked all four footprint corners of every actual vehicle at 1,000 evenly spaced positions along its loop: all 32,000 corners remain on the rendered avenue geometry. The two-sided seam check is 0.000198 metres apart when sampled 0.0001 metres either side of the seam. This supplements the author's center-only road check.

This review certifies route continuity and the tested actor footprints, not naturalistic traffic behavior at every possible player obstruction, browser appearance or phone frame rate. City-layout work is continuing in the same source file. The retained evidence records both full source snapshots and individual traffic-method hashes, so later layout changes cannot be mistaken for the exact reviewed snapshot.

Evidence: artifacts/fixes-20260928/reviews/city-motion.json, layout-traffic-probe.gd and reviewed-source-hashes.json. No user save or foreground window was used.
