# Floor 1 environment kit 01–20

These twenty assets are original project geometry generated from the editable Blender source and seeded Python builder in `Art/ReferenceScenes/Floor1EnvironmentKit20/`. They use the project's existing warm stone, dark timber, terracotta, vegetation and restrained system-blue palette. No anime frame was traced and no old-project restricted character, private save, marketplace pack or third-party mesh was imported.

The wood and stone micro-normal images are reused from the project's authored `Art/ReferenceScenes/MarketCraftV5/textures/` sources and are embedded by Blender during export. Each component is metre-scaled, ground-centred and exported as an individual GLB. `Floor1_EnvironmentKit20_Showcase.glb` is only a catalogue layout; use the twenty `F1_*.glb` files for scene placement.

Fifteen assets carry conservative `COL_` proxy meshes. Fern, grass, wildflower, ivy and reed components intentionally have no collision in this iteration so residents can pass through small foliage. Placement in the current demo is visual-only until route-specific collision review.

The fifteen plant/natural assets are classified as canopy trees, shrubs/cultivated plants, groundcovers, climbers, wetland plants, and deadwood/moss. Godot applies one restrained visual-root sway profile per living-plant category. Thirteen catalogue plants move; the fallen log and mixed herb-planter container stay static, as do all collision shapes and hard components.

The script and seed reproduce the authored forms and metrics, but Blender GLB serialization is not claimed to be byte-identical across repeated exports. The manifest pins the delivered files and hashes. Visual approval, LOD tiers, branch/leaf deformation, biome-scale variation and publication licensing remain open.
