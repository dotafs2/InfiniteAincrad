# Food-city street hierarchy — September 28, 2026

Version 0.5.3 addresses the user's report that orthogonal, equal-spaced food
models still looked like a display grid. The map now uses authored frontage
along walking streets, a central market court and a varied skyline.

- Twelve neighborhoods have curved walking streets; two diagonal connectors
  link Crescent Market to the main street network. The four established vehicle
  avenues retain their tested lanes and intersection handling.
- 132 buildings include 41 low shops and nine taller landmarks. Their measured
  heights span 2.04–13.46 m; 123 facades have non-axis-aligned bearings. Each
  facade faces the nearest point of its own street rather than a random angle.
- A ring promenade surrounds the starting market square. Rear courts contain
  twelve large food heaps; three smaller starter heaps remain nearby. The scene
  has 2,547 initial edible bodies and 1,072 independently supported upper pieces.
- Loose food has irregular spacing and orientation with footprint separation.
  Global grid-line paving is replaced by one authored street atlas: cream and
  peach walks, pink curbs, a market court and mint planting pockets.
- All 48 citizens now inhabit the neighborhood walking paths. Their normal and
  panic destinations project onto the same paths painted by the atlas. Frozen
  route movement still relinquishes control before physical swallowing.

`tools/build_food_neighborhoods.py` produces the plan JSON and 2048-pixel atlas.
They are authored from code, not downloaded game art. The runtime caches route
vectors once and uses one atlas lookup for the ground image. Initial food mesh
population is 4,358,120 triangles before culling, below the 4.5M acceptance cap.

QA found and corrected a heap blocking the market's west connector. The new
165-check suite verifies actual facade bearings, varied heights, painted-path
agreement, plot envelopes and every sampled citizen position during a minute
of normal/panic movement. The dense-map suite passes 1,165 checks, including
the 59-piece pyramid, four tower shapes, a starter cascade and unsupported
oversized food. The source automated contested and solo rounds both complete
normally at 420 and 425 points respectively. All gates also run on the exported
PCK; exact final counts and hashes are in `artifacts/food-neighborhoods/release.json`.

The delivered source and PCK each pass **4,474 checks**. Final isolated headless
Mac traces contain 600 frames per scenario: opening P50/P95/worst is
3.973/4.659/5.141 ms; grown is 6.303/7.697/8.844 ms. Neither trace contains a
frame above 16.67 ms. These exclude GPU work and are not iPhone FPS evidence.
Regenerating the plan and atlas in a temporary directory produces identical
JSON content and PNG bytes.

The broader map test initially failed because it enlarged a level-one mouth
without changing its score/level. A nearby pedestrian receipt restored the
level-one radius before the donut drop (8.0 to 0.85, score 3). The fixture now
sets a coherent level-eight score/radius; production growth rules are unchanged.

The preview files render real food meshes, actual transforms, the authored
street atlas and the shipped food-reflection equations in a windowless OpenGL
harness. Final lighting is approximate; characters, UI and contact shadows are
omitted. They are not Godot/browser screenshots. Browser visual acceptance and
physical iPhone 14 GPU/thermal performance remain unverified.
