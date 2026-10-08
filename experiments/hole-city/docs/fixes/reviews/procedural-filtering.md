# Independent ground and facade filtering review

Reviewer: city agent; author: food agent. Date: 2026-09-28. Result: **PASS for the bounded source/resource/mathematical scope**.

I reran `tests/procedural_filtering_math.py`. It compiles the shipped shader helper text as C++ float arithmetic and compares with physical interval-overlap enumeration. All 616 asphalt periodic cases, 616 asphalt finite intervals and 616 facade periodic cases passed. Maximum periodic coverage error is 0.000549376; maximum complete-period duty-cycle error is 0.000000763. The cases include negative coordinates, seams, subpixel lines and footprints spanning multiple periods.

I independently executed `tests/procedural_filtering_acceptance.gd -- --test` after root's serialized import. All 27 resource checks passed, with no unexpected engine error. The real imported texture contains all 11 mip levels after the 2048 × 2048 base. Its base RGB SHA-256 remains `192f9dc835738e4a888a3b894e19cfe2753dbd1f65678cd3e1dc33c1bdf05247`, and inspected RGB storage is 16,777,215 bytes. The only diagnostic was the existing macOS CA-certificate warning. Evidence: `artifacts/visual-quality-20260928/filtering/independent-resource.log` and the refreshed `mask-math.json`.

Static equation review confirms derivatives are taken from continuous coordinates, before fract/floor, and that interval filtering retains the nominal lane/paving/window dimensions. Atlas sampling requests clamped trilinear filtering with the now-present complete mip chain. Physical ground cuts remain in the same mesh; there is no surface overlay over the hole.

I checked the facade pane and crossbar equations against the archived prior shader in `artifacts/video-showcase-20260928/city/hero/city-ground.frag`. The original shade then highlight blend expands to `1 - .36*shade + .10*top + .144*shade*top`. The vertical crossbar lies completely inside the shaded half, while its horizontal bar lies below the top highlight; `.244*cross_top` correctly combines the two top terms. The new area expressions preserve these intersections instead of multiplying unrelated filtered masks. Frame/opening bounds, palette and roughness endpoints remain unchanged. Fading the cell-specific hash variation to its mean is an intentional distant-detail filter, not a new world color theme.

No blocking issue found. This validates resources and bounded numerical behavior; it does not certify GLSL pixels, temporal shimmer, GPU memory allocation, browser performance or mobile frame time. Root owns separate shader compilation and release verification. Device motion comparison remains necessary.

Exact reviewed source hashes:

- `fidelity/asphalt.gdshader`: `d889999e0ed468fcab4bc2f2678b2ced8a79ef99a4e89d29fa08dd029e70beff`
- `fidelity/facade.gdshader`: `8690435464f5b43d8bf55c611f2973a12a8991d7d17a7b3e5266c22df07f6084`
- `assets/food_city/streets.png.import`: `996eeb37acf3820402c56b79ed7deb9e4b500cf8ec10518037c5f37514f833db`
- `tests/procedural_filtering_acceptance.gd`: `665dd1e8b776f1c19390b47320f81155c6e761c35f5840a54571ad0ddf7ca14d`
- `tests/procedural_filtering_math.py`: `c928364a40424d4fea1138b8980e21b74a8c2b7f8e2cfdc50fb1578252826d38`
