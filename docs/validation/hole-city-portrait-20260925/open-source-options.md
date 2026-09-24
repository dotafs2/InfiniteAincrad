# Open-source character options reviewed

These official pages were checked while choosing the character source:

- [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) — CC0, six game-ready base characters.
- [Kenney Blocky Characters](https://www.kenney.nl/assets/blocky-characters) — CC0, animated character asset pack.
- [Kenney support / license guidance](https://kenney.nl/support) — Kenney states that assets on its asset pages are public domain / CC0.
- [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) — royalty-free commercial use is allowed, but Mixamo is a hosted service rather than an open-source library.

This milestone does not ship those external meshes. The current 16 role models
are authored locally in Blender so they share the same low-poly silhouette,
vertex-color materials and Godot physics footprint as the existing city. That
keeps the package independent of a hosted account and avoids mixing a realistic
retargeted rig into the deliberately stylized stick-figure cast. Quaternius and
Kenney remain suitable CC0 sources for a future optional character expansion;
Mixamo remains a possible animation source if a later milestone explicitly
accepts a hosted, non-open workflow.
