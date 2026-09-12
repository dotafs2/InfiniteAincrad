extends RefCounted
## Explicit measured layout for the town expansion.
##
## Measured with game/tests/town_expansion_clearance.gd on a disposable save: the market strip
## spans x -27.5..27.5, z -80..36 and the plaza exit corridor x -4..12 is walkable from z 8 out
## past z 72. Task19's first numbers were *intended* widths and put two 8 m shells across the
## 6 m main street (walker stuck at z 22.85). House rows here start at |x| >= 9, and no prop sits
## on a road centreline, so the corridors measured below are the real clear widths.

## Surface heights. The original market floor at the junction measures y = 0.15 (clearance2.json,
## x0 z30/z34) against 0.10 paved and 0.06 bare earth here, so the join is a <= 9 cm lip that a
## 0.25 m capsule walks, and the short ramp below removes even that at the paved crossing.
const PAVING_TOP_Y := 0.10
const ROAD_THICKNESS := 0.10
const TERRAIN_TOP_Y := 0.06
const TERRAIN_THICKNESS := 0.2
## Junction ramp: 6 m gentle transition from the old market floor to the new paving.
const JUNCTION_RAMP := {"x": 0.0, "z_from": 33.4, "z_to": 39.6, "y_from": 0.152, "y_to": 0.10,
	"half_width": 3.0, "thickness": 0.16}
## Visible terrain footprint: the neighbourhood the player can actually see and stand on.
const TERRAIN := {"center": Vector2(0, 55), "size": Vector2(68, 84)}
## Surrounding ground: a wider, lower, duller plate so the walkable neighbourhood does not read
## as a slab floating against void. Collision stays on the main plate only; this is visible land.
const OUTSKIRTS := {"center": Vector2(0, 55), "size": Vector2(116, 132), "top_y": -0.06}

## Soft landscape edge: existing kit assets (no new art) ringing the walkable plate.
const PERIMETER := [
	{"id": "F1_cypress_column", "x": -28.0, "z": 13.0, "yaw": 0.0},
	{"id": "F1_cypress_column", "x": 28.0, "z": 13.0, "yaw": 0.0},
	{"id": "F1_stone_pine", "x": 33.0, "z": 30.0, "yaw": 20.0},
	{"id": "F1_stone_pine", "x": -33.0, "z": 30.0, "yaw": 200.0},
	{"id": "F1_cypress_column", "x": 33.0, "z": 60.0, "yaw": 40.0},
	{"id": "F1_cypress_column", "x": -33.0, "z": 60.0, "yaw": 220.0},
	{"id": "F1_mossy_boulder_cluster", "x": 33.0, "z": 84.0, "yaw": 0.0},
	{"id": "F1_mossy_boulder_cluster", "x": -33.0, "z": 84.0, "yaw": 90.0},
	{"id": "F1_mossy_fallen_log", "x": -30.0, "z": 96.0, "yaw": 10.0},
	{"id": "F1_mossy_boulder_cluster", "x": 30.0, "z": 96.0, "yaw": 300.0},
	{"id": "F1_timber_fence_vine", "x": -24.0, "z": 97.0, "yaw": 0.0},
	{"id": "F1_timber_fence_vine", "x": 24.0, "z": 97.0, "yaw": 0.0},
	{"id": "F1_birch_grove", "x": -36.0, "z": 46.0, "yaw": 30.0},
	{"id": "F1_birch_grove", "x": 36.0, "z": 46.0, "yaw": 210.0},
	{"id": "F1_young_maple", "x": -36.0, "z": 74.0, "yaw": 60.0},
	{"id": "F1_young_maple", "x": 36.0, "z": 74.0, "yaw": 240.0},
	{"id": "F1_flowering_shrub", "x": -34.0, "z": 20.0, "yaw": 0.0},
	{"id": "F1_flowering_shrub", "x": 34.0, "z": 20.0, "yaw": 0.0},
]

## Paving rectangles: {"center": Vector2(x, z), "size": Vector2(width_x, depth_z)}
const ROADS := [
	{"center": Vector2(0, 53), "size": Vector2(6, 76)},        # main street from the plaza gate
	{"center": Vector2(-13.5, 40), "size": Vector2(25, 6)},    # north cross street, west arm
	{"center": Vector2(13.5, 40), "size": Vector2(25, 6)},     # north cross street, east arm
	{"center": Vector2(-13.5, 66), "size": Vector2(25, 6)},    # south cross street, west arm
	{"center": Vector2(13.5, 66), "size": Vector2(25, 6)},     # south cross street, east arm
	{"center": Vector2(0, 53), "size": Vector2(14, 14)},       # commons crossing paving
	{"center": Vector2(0, 88), "size": Vector2(6, 7)},         # orchard edge track
]

## Planted beds: kept off the main street (x -3..3) by splitting the commons in two.
const COMMONS_BEDS := [
	{"center": Vector2(-9.2, 49.0), "size": Vector2(4.0, 3.0)},
	{"center": Vector2(9.2, 49.0), "size": Vector2(4.0, 3.0)},
	{"center": Vector2(-9.2, 57.0), "size": Vector2(4.0, 3.0)},
	{"center": Vector2(9.2, 57.0), "size": Vector2(4.0, 3.0)},
]

## Houses: variant 1..6, position (x, z), yaw in degrees. Doors face the adjacent street.
## North row faces the z=40 street (yaw 180 faces +z... the shell's front is -z, hence 180).
const HOUSES := [
	{"variant": 1, "x": -19.0, "z": 30.0, "yaw": 180.0},
	{"variant": 2, "x": -9.0, "z": 30.0, "yaw": 180.0},
	{"variant": 3, "x": 9.0, "z": 30.0, "yaw": 180.0},
	{"variant": 4, "x": 19.0, "z": 30.0, "yaw": 180.0},
	{"variant": 5, "x": -19.0, "z": 52.0, "yaw": 0.0},
	{"variant": 6, "x": -9.0, "z": 52.0, "yaw": 0.0},
	{"variant": 1, "x": 9.0, "z": 52.0, "yaw": 0.0},
	{"variant": 2, "x": 19.0, "z": 52.0, "yaw": 0.0},
	{"variant": 4, "x": -19.0, "z": 78.0, "yaw": 0.0},
	{"variant": 5, "x": -9.0, "z": 78.0, "yaw": 0.0},
	{"variant": 6, "x": 9.0, "z": 78.0, "yaw": 0.0},
	{"variant": 3, "x": 19.0, "z": 78.0, "yaw": 0.0},
	{"variant": 2, "x": -29.0, "z": 46.0, "yaw": 90.0},
	{"variant": 5, "x": 29.0, "z": 46.0, "yaw": 270.0},
]

## Environment v2 kit: {"id": "F1_<asset>", "x", "z", "yaw"}. Solids per SOLID_IDS below.
const SOLID_IDS := ["ancient_oak", "birch_grove", "cypress_column", "stone_pine",
	"orchard_apple", "young_maple", "mossy_boulder_cluster", "mossy_fallen_log",
	"herb_planter", "roadside_milestone", "timber_fence_vine", "stone_water_trough",
	"canvas_rest_shelter"]

const KIT_PROPS := [
	# commons: canopy and seating, all clear of the main street and both cross streets
	{"id": "F1_ancient_oak", "x": -12.5, "z": 47.0, "yaw": 12.0},
	{"id": "F1_ancient_oak", "x": 12.5, "z": 59.5, "yaw": 208.0},
	{"id": "F1_birch_grove", "x": -11.0, "z": 59.0, "yaw": 40.0},
	{"id": "F1_young_maple", "x": 11.5, "z": 47.5, "yaw": 300.0},
	{"id": "F1_stone_water_trough", "x": 10.5, "z": 50.0, "yaw": 90.0},
	{"id": "F1_canvas_rest_shelter", "x": -9.5, "z": 61.0, "yaw": 180.0},
	{"id": "F1_canvas_rest_shelter", "x": 9.5, "z": 55.5, "yaw": 0.0},
	{"id": "F1_mossy_boulder_cluster", "x": -14.5, "z": 60.5, "yaw": 25.0},
	{"id": "F1_mossy_fallen_log", "x": 15.0, "z": 47.0, "yaw": 70.0},
	{"id": "F1_roadside_milestone", "x": -4.6, "z": 34.5, "yaw": 180.0},
	{"id": "F1_roadside_milestone", "x": 4.6, "z": 70.5, "yaw": 0.0},
	{"id": "F1_herb_planter", "x": -9.2, "z": 49.0, "yaw": 0.0},
	{"id": "F1_herb_planter", "x": 9.2, "z": 49.0, "yaw": 0.0},
	{"id": "F1_herb_planter", "x": -9.2, "z": 57.0, "yaw": 0.0},
	{"id": "F1_herb_planter", "x": 9.2, "z": 57.0, "yaw": 0.0},
	{"id": "F1_flowering_shrub", "x": -16.5, "z": 44.0, "yaw": 0.0},
	{"id": "F1_flowering_shrub", "x": 16.5, "z": 44.0, "yaw": 90.0},
	{"id": "F1_flowering_shrub", "x": -16.5, "z": 62.0, "yaw": 200.0},
	{"id": "F1_flowering_shrub", "x": 16.5, "z": 62.0, "yaw": 15.0},
	{"id": "F1_timber_fence_vine", "x": -31.0, "z": 33.0, "yaw": 90.0},
	{"id": "F1_timber_fence_vine", "x": 31.0, "z": 33.0, "yaw": 90.0},
	{"id": "F1_timber_fence_vine", "x": -31.0, "z": 73.0, "yaw": 90.0},
	{"id": "F1_timber_fence_vine", "x": 31.0, "z": 73.0, "yaw": 90.0},
	{"id": "F1_ivy_wall_panel", "x": -32.0, "z": 24.0, "yaw": 90.0},
	{"id": "F1_ivy_wall_panel", "x": 32.0, "z": 24.0, "yaw": 90.0},
	{"id": "F1_cypress_column", "x": -31.5, "z": 52.0, "yaw": 0.0},
	{"id": "F1_cypress_column", "x": 31.5, "z": 52.0, "yaw": 0.0},
	{"id": "F1_stone_pine", "x": -30.0, "z": 62.5, "yaw": 30.0},
	{"id": "F1_stone_pine", "x": 30.0, "z": 62.5, "yaw": 200.0},
	{"id": "F1_meadow_grass", "x": -10.0, "z": 45.2, "yaw": 0.0},
	{"id": "F1_meadow_grass", "x": 10.0, "z": 45.2, "yaw": 45.0},
	{"id": "F1_meadow_grass", "x": -10.0, "z": 60.8, "yaw": 90.0},
	{"id": "F1_meadow_grass", "x": 10.0, "z": 60.8, "yaw": 135.0},
	{"id": "F1_wildflower_patch", "x": -4.0, "z": 74.0, "yaw": 0.0},
	{"id": "F1_wildflower_patch", "x": 4.0, "z": 74.0, "yaw": 60.0},
	{"id": "F1_wildflower_patch", "x": -24.0, "z": 36.5, "yaw": 120.0},
	{"id": "F1_wildflower_patch", "x": 24.0, "z": 36.5, "yaw": 240.0},
	{"id": "F1_fern_patch", "x": -13.0, "z": 44.5, "yaw": 30.0},
	{"id": "F1_fern_patch", "x": 13.0, "z": 61.5, "yaw": 210.0},
	{"id": "F1_reed_cluster", "x": -14.0, "z": 57.5, "yaw": 0.0},
	{"id": "F1_reed_cluster", "x": 14.0, "z": 49.5, "yaw": 90.0},
	{"id": "F1_berry_bush", "x": -17.5, "z": 47.5, "yaw": 0.0},
	{"id": "F1_berry_bush", "x": 17.5, "z": 58.5, "yaw": 45.0},
	# orchard / garden edge south of the last row
	{"id": "F1_orchard_apple", "x": -16.0, "z": 86.0, "yaw": 0.0},
	{"id": "F1_orchard_apple", "x": -8.0, "z": 86.0, "yaw": 90.0},
	{"id": "F1_orchard_apple", "x": 8.0, "z": 86.0, "yaw": 180.0},
	{"id": "F1_orchard_apple", "x": 16.0, "z": 86.0, "yaw": 270.0},
	{"id": "F1_meadow_grass", "x": -11.0, "z": 84.0, "yaw": 0.0},
	{"id": "F1_meadow_grass", "x": 11.0, "z": 84.0, "yaw": 0.0},
	{"id": "F1_flowering_shrub", "x": 5.0, "z": 91.0, "yaw": 0.0},
]

## New 2026-09-12 shopfront set, attached to the street-facing facade of a house.
## "house" indexes HOUSES; "z_off" is the metres in front of the facade plane; "y" is height.
const SHOPFRONT_DIR := "res://assets/generated/shopfront_details_20260912/"
const SHOPFRONTS := [
	{"file": "SF09_Scalloped_Cloth_Canopy.glb", "house": 1, "z_off": 0.42, "y": 2.62},
	{"file": "SF13_Bakery_Pretzel_Emblem.glb", "house": 1, "z_off": 0.30, "y": 3.32},
	{"file": "SF01_Mercer_Display_Window.glb", "house": 2, "z_off": 0.28, "y": 1.22},
	{"file": "SF15_Tailor_Shears_Emblem.glb", "house": 2, "z_off": 0.30, "y": 3.30},
	{"file": "SF11_Glazed_Shop_Door.glb", "house": 4, "z_off": 0.26, "y": 1.24},
	{"file": "SF16_Barber_Spiral_Emblem.glb", "house": 4, "z_off": 0.30, "y": 3.34},
	{"file": "SF03_Diamond_Lead_Casement.glb", "house": 5, "z_off": 0.28, "y": 3.44},
	{"file": "SF14_Apothecary_Mortar_Emblem.glb", "house": 5, "z_off": 0.30, "y": 2.72},
	{"file": "SF07_Clay_Tile_Rain_Eave.glb", "house": 6, "z_off": 0.34, "y": 5.45},
	{"file": "SF08_Carved_Timber_Corbel.glb", "house": 6, "z_off": 0.30, "y": 4.30},
	{"file": "SF05_Tiled_Gable_Dormer.glb", "house": 8, "z_off": 0.32, "y": 6.10},
	{"file": "SF02_Folding_Service_Hatch.glb", "house": 8, "z_off": 0.28, "y": 2.10},
	{"file": "SF10_Stone_Double_Portal.glb", "house": 11, "z_off": 0.30, "y": 1.55},
	{"file": "SF06_Open_Flue_Chimney.glb", "house": 11, "z_off": 0.34, "y": 5.20},
	{"file": "SF12_Herbal_Stone_Niche.glb", "house": 13, "z_off": 0.30, "y": 2.40},
	{"file": "SF04_Radial_Attic_Oculus.glb", "house": 13, "z_off": 0.32, "y": 5.60},
]

## New 2026-09-12 artisan set, grouped into three working corners on real ground.
const WORKSHOP_DIR := "res://assets/generated/artisan_workshops_20260912/"
const WORKSHOPS := [
	# bakery corner beside the north-west bakery frontage
	{"file": "bakers_oven_peel_rack.glb", "x": -24.5, "z": 35.4, "yaw": 0.0},
	{"file": "grain_hand_quern.glb", "x": -22.6, "z": 35.0, "yaw": 30.0},
	{"file": "honey_basket_press.glb", "x": -20.8, "z": 35.6, "yaw": 300.0},
	# smith corner beside the north-east frontage
	{"file": "forge_with_bellows.glb", "x": 24.4, "z": 35.2, "yaw": 180.0},
	{"file": "horn_anvil_stump.glb", "x": 22.3, "z": 35.6, "yaw": 150.0},
	{"file": "smith_tong_rack.glb", "x": 20.4, "z": 35.0, "yaw": 210.0},
	# carpentry / rope corner beside the south-west frontage
	{"file": "coopers_stave_jig.glb", "x": -24.6, "z": 61.2, "yaw": 0.0},
	{"file": "treadle_shaving_horse.glb", "x": -22.5, "z": 61.6, "yaw": 20.0},
	{"file": "rope_winding_winch.glb", "x": -20.7, "z": 61.0, "yaw": 340.0},
	# pottery corner beside the south-east frontage
	{"file": "treadle_potters_wheel.glb", "x": 24.5, "z": 61.4, "yaw": 180.0},
	{"file": "clay_drying_shelves.glb", "x": 22.4, "z": 61.0, "yaw": 160.0},
	{"file": "arched_pottery_kiln.glb", "x": 20.5, "z": 61.8, "yaw": 200.0},
]

## New 2026-09-12 travel/cargo set: one caravan rest and cargo yard by the orchard track.
const CARGO_DIR := "res://assets/generated/travel_cargo_20260912/"
const CARAVAN := [
	## Caravan rest yard at the east end of the south-east arm, clear of every road rect.
	## Yard sits east of the arm end (x >= 29) so the x 26 approach line stays walkable.
	{"file": "covered_caravan_wagon.glb", "x": 32.0, "z": 70.5, "yaw": 15.0},
	{"file": "open_traveller_tent.glb", "x": 35.0, "z": 75.0, "yaw": 200.0},
	{"file": "water_delivery_cart.glb", "x": 29.5, "z": 75.5, "yaw": 95.0},
	{"file": "porters_luggage_trolley.glb", "x": 32.5, "z": 79.0, "yaw": 265.0},
	{"file": "stacked_timber_pallets.glb", "x": 35.5, "z": 68.0, "yaw": 0.0},
	{"file": "partitioned_ceramic_crate.glb", "x": 30.0, "z": 67.5, "yaw": 30.0},
	{"file": "coiled_hemp_rope.glb", "x": 35.5, "z": 79.5, "yaw": 0.0},
	{"file": "carved_route_waystone.glb", "x": 29.0, "z": 71.5, "yaw": 180.0},
	{"file": "timber_pack_saddle.glb", "x": 35.0, "z": 71.0, "yaw": 75.0},
	{"file": "folding_route_map_table.glb", "x": 32.5, "z": 66.0, "yaw": 300.0},
]


static func house_footprint(variant: int) -> Vector2:
	## Footprint (x, z) per shell, from the residence manifests' collision extents.
	match variant:
		1: return Vector2(8.2, 6.5)
		2: return Vector2(5.6, 6.6)
		3: return Vector2(7.4, 6.6)
		4: return Vector2(6.6, 6.4)
		5: return Vector2(7.0, 7.2)
		6: return Vector2(7.7, 6.7)
	return Vector2(6.0, 6.0)
