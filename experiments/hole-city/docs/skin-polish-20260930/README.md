# Six original sculpted skins

Six existing cosmetic skins now have actual rounded volume, readable parts and per-pixel lighting. Stable IDs, ownership, rarity, draw odds, legacy migration, movement and swallowing are unchanged. Common and Uncommon keep their intentionally simple finishes. All other 38 forms retain their geometry and materials.

## Local visual audit and original design

The old motif builder used unshaded materials throughout. Its thin extruded ears/wings and disconnected primitive ingredients could not receive a light highlight. Merely increasing thumbnail resolution could not fix that missing material response. The six new designs use closed lathed contours or beveled outlines, with outward smooth normals, opaque roughness-controlled StandardMaterial3D finishes and no textures, particles or physics. The shared black opening and animated boost feedback remain intact.

| Existing ID | Original treatment in this change | Gameplay triangles including hidden feedback | Meshes | Smallest 36-yaw card margin |
| --- | --- | ---: | ---: | ---: |
| pizza_party | Rounded toasted dough, raised melted cheese, pepperoni and flat basil leaves | 3,044 | 12 | 20.62 px |
| frosted_cake | Sponge, berry filling, scalloped icing and three strawberries | 3,132 | 11 | 11.65 px |
| fox_den | Glazed fox mask, thick beveled ears, cream cheeks and dark nose | 2,668 | 12 | 4.74 px |
| bunny_burrow | Porcelain ring, two uneven rounded ears and pink cheek accents | 2,768 | 12 | 4.40 px |
| rocket_port | Rounded enamel rocket, swept fins, glass porthole and recessed nozzle | 2,928 | 12 | 5.15 px |
| dragon_roost | Purple coil, raised beveled wings, ivory horns and slit eyes | 2,880 | 13 | 6.60 px |

These are deliberately distinct food, ceramic animal and toy-object designs. No competitor character, mesh, texture, name or logo was copied. Roughness ranges from 0.17 for the glass porthole to 0.48 for sponge; the baked surfaces stay softer than the enamel. The scene's existing lights provide the highlight. Skin shadows remain disabled so decoration does not darken the swallow opening.

The [official Hole.io Google Play listing](https://play.google.com/store/apps/details?id=io.voodoo.holeio&hl=en-US) and [Apple listing](https://apps.apple.com/us/app/hole-io/id1389111413) were resolved as reference sources. The web interface returned image URLs and captions, not inspectable pixels. Consequently this report makes no new pixel-level comparison or claim of matching Hole.io. The quality decisions above are grounded in the inspectable local geometry/material defects and the original rendered assets.

## Evidence and checks

[Before/after contact sheet](../../artifacts/skin-polish-20260930/before-after.png) contains actual exported before/after meshes rendered offline in Blender CPU. Colors and Standard material roughness/specular are mapped to Blender; its lighting is an approximation of the game. The thin procedural base ring is represented by its base color. These images are **not Godot/browser screenshots**. Individual images and complete exported vertices, normals, indices and material values are retained under the before/author folders. Both versions use the same camera and lights; the enlarged and small views are labeled.

[Manifest](../../artifacts/skin-polish-20260930/manifest.json) binds runtime/test source hashes, original source copies, rendered outputs and the exact catalog field diff. Only six `skill_desc` strings changed in the catalog. No new rarity was assigned. The original files remain under `artifacts/skin-polish-20260930/before/`.

Strict targeted author results:

- `skin_polish_acceptance`: 486 checks. Actual topology, material finish, finite/unit normals, clear opening, every vertex through 36 camera-relative yaws, feedback and rebuild lifecycle.
- Unchanged `skin_catalog_acceptance`: 897; `city_review_skin_catalog`: 206; `skin_rarity_acceptance`: 556; `skin_fx_acceptance`: 414.
- All rendered forms remain below the existing 18-mesh/4,500-triangle limit. The narrowest actual unobstructed opening radius is 0.782, exceeding the previous 0.70 requirement.

The first geometry run found the rocket top outside the four-pixel collection margin; its actual body height was reduced before final acceptance. A test naming assumption was corrected to explicit Left/Right node names. The prior rarity review's exact old counts for these six high-tier forms intentionally conflict with the requested replacement geometry; root assigned that limited expectation maintenance to the independent reviewer. Its remaining forms and economy checks must stay intact.

No browser, foreground application, saved player data, GPU frame timing or phone was exercised. An isolated asset preview and headless projection test do not establish in-game appearance or iPhone frame rate. Independent review and the full source/package release gate are separate from these author receipts.

A subsequent [primary-source clearcoat check](clearcoat-source-check.md) corrected a mistaken compatibility concern. Godot's GLES3 shader does implement clearcoat, so the original material and previews were retained; the withdrawn no-coat attempt is preserved separately and is not a final input.
