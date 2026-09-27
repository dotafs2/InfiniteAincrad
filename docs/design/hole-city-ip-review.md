# Hole City release IP review

Review date: 2026-09-27. This is an engineering and release-risk review, not
legal advice or a jurisdiction-specific clearance opinion.

## Findings

The project uses a familiar game idea: a player-controlled hole moves around a
city and swallows objects. The United States Copyright Office says the idea of
a game and its methods of play are not protected by copyright, while expressive
art, text and audiovisual elements can be protected. That makes the mechanic
alone lower risk than copying a game's expression.

The pre-redesign project had **medium copycat / platform-review risk** because
the repository's reference ledger intentionally mirrored several recognizable
first-level presentation choices. The September 27 authored pass now uses a
210-second/420-sync round, blue-violet/orange signal contrast, sector/name/
progress labels, the RIFT COLLAPSED result, a framed home miniature, ENTER THE
RIFT, FOUNDATION/RESONANCE tabs, a live 3D form preview and original Rift Form
names. The models, meshes,
textures, audio, city kit, shaders and Godot implementation are authored here;
the ledger says no Hole.io proprietary assets or extracted commercial code were
copied. That reduces copyright-infringement risk, but it does not by itself
remove Apple's separate copycat-review risk.

Apple's App Review Guideline 4.1 says not to submit a popular app with only
minor changes to its name or UI, and Guideline 5.2 requires permission for
third-party protected material and prohibits misleading or copycat
representations. The store submission must therefore use an independent name,
icon, screenshots, metadata, UI hierarchy, result language, skin names and
marketing copy. Do not mention Hole.io, Poki or the publisher in the product
name, subtitle, keywords or screenshots.

The reused `Godot-Hole.io` controller/template code is recorded as MIT in
`THIRD_PARTY.md`, with its license and provenance retained. Keep that notice in
every distributed build. The game uses original replacement art, but the MIT
notice does not license any Hole.io brand or artwork.

The official Epic City Sample/Houdini files are a separate issue. The local
City Sample cache and HDA work is kept under `tmp/citysample-source` for
inspection and map generation; it is not included by the Godot export filters.
Epic's content terms identify some City Sample/Fab content as UE-Only Content.
Do not ship City Sample meshes, textures, cache files, HDA files or Matrix
branding in the iOS game unless the exact asset license permits that use. The
current runtime city uses the authored `assets/city_kit` GLBs instead.

## Release actions before Apple submission

1. Confirm the final product name, icon and trademark clearance for **Sink//Field**.
2. Keep the authored signal vocabulary in the store build: `RIFT FORMS`,
   `FOUNDATION`, `RESONANCE`, `RIFT COLLAPSED`, `COLLAPSE COMPLETE`, `WINDOW
   CLOSED`, and the original ten-form library names (Core Shell through Prism
   Vale). The cooldown skills and descriptions are product-specific authored
   behavior, not reference-derived copy.
3. Keep the 210-second/420-sync tuning, contour wallpaper, live form preview,
   per-form void/flame/wave/metal/gravity/beacon/prism shader profiles, visible
   particle motes, cut-corner buttons, signal HUD and authored collapse/revive
   flow together so the product has an independent visual and play identity.
   Do not reuse the reference's screenshots, exact card copy, branded labels or
   third-party art.
4. Keep only original models/audio/shaders in the mobile export and archive
   SPDX/MIT/engine notices with the release package.
5. Run a trademark search for the final product name and obtain a lawyer's
   clearance review in each intended storefront jurisdiction.

The current build should be treated as an internal reference-informed prototype,
not as the final App Store submission.
