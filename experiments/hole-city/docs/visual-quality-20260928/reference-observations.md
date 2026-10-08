# Reference provenance and rendering evidence — September 28, 2026

This bounded review identifies the user's installed reference games and what
can actually be established about their rendering. It does not certify visual
parity, guess quality settings from artwork, or treat our offline previews as
reference screenshots. No application was launched or modified.

## Installed references: directly verified

Only top-level names in `/Applications`, `/Users/dotafs/Applications` and
`/Users/dotafs/Downloads` were checked for the requested game terms. Four
matching applications exist. Afterward, inspection was limited to their known
wrapped `Info.plist`, Unity framework metadata, `Data/boot.config`,
`Data/ScriptingAssemblies.json`, and the first 1,024 bytes of standard Unity
serialized-file/bundle metadata.

| Installed game | App version / build | Engine version in serialized header | Render-related build evidence |
| --- | --- | --- | --- |
| Hole.io | 2.53.5 / 23736 | Unity 6000.3.2f1 | Universal Render Pipeline, ShaderGraph and GPUDriven assembly names are packaged |
| Hole Em All | 2.15.1 / 421 | Unity 2022.3.67f2 | Universal Render Pipeline and ShaderGraph assembly names are packaged |
| Black Hole Attack Games | 1.0.14 / 14 | Unity 2022.3.13f1 | Universal Render Pipeline and ShaderGraph assembly names are packaged |
| Eat Em All Black Hole | 1.0.0 / 0 | Unity 2020.3.48f1 | No render-pipeline-named assembly appears in the inspected assembly-name list |

All four report `iphoneos` and include `UnityFramework.framework`. This is
positive evidence of the engine, not a deduction from how the artwork looks.
Bundled URP assemblies establish available build components; they do **not**
prove which pipeline asset, quality tier, camera renderer or per-camera options
are selected at runtime. An absent matching assembly name likewise does not
prove a particular visual feature is absent.

All four `boot.config` files contain `hdr-display-enabled=0`. Hole.io additionally
contains `gfx-threading-mode=4`. These are retained as literal build metadata.
The HDR-display flag does not establish whether internal lighting buffers,
tonemapping, material highlights or bloom are enabled. No interpretation of the
threading value is used as visual-quality evidence.

The two older games expose `Data/globalgamemanagers`; the two principal targets
package `Data/data.unity3d`. Existing bundled Python has neither UnityPy nor
unitypack. No parser was installed, no archive was unpacked, and no serialized
quality values were guessed. Exact MSAA sample count, render scale, FXAA/TAA,
shadow filtering/resolution, SSAO, tonemapping and runtime quality selection
therefore remain **unproven**. Even a future readable build-default setting
must be distinguished from the settings selected on a particular device.

Exact bundle paths, package IDs, metadata hashes, version headers and relevant
assembly names are in [installed-reference-metadata.json](installed-reference-metadata.json).
No user saves, executable decryption or asset extraction were involved.

## Screenshots and visual provenance

The historical [Poki ledger](../../fidelity/REFERENCE.md) records an actual
September 24 observation of Hole.io: a blue opening, asphalt court, city props,
sidewalk buildings and people, a four-minute round and the library/store
hierarchy. This is historical observation text. Its documented retained image
folder, `private/hole-city-reference`, is absent beneath both the current game
and workspace roots. The historical sibling `hole-city-local` is also absent
at the documented nearby locations. The current `artifacts/reference-audit-*`
files are probes; our `layouts` and `video-showcase-*` images are reconstructions
or offline previews. None is a replacement for the missing original captures.

The following external reference sources were resolved in this review:

- [Hole.io official Google Play listing](https://play.google.com/store/apps/details?id=io.voodoo.holeio&hl=en).
- [Hole Em All official Google Play listing](https://play.google.com/store/apps/details?id=and.brainworks.holeemall&hl=en).
- [Hole Em All official Apple listing](https://apps.apple.com/gb/app/hole-em-all-black-hole-games/id6739246483).
- [Previously cited Hole.io collection artwork, Apple CDN](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/12/dc/cd/12dccd53-ff1d-57e7-4455-755d76212e5b/4_skins_30.jpg/471x1024.jpeg).
- [Hole Them All food-stack artwork, Apple CDN](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/3f/f7/35/3ff735d4-31ec-d1e0-3c68-2dec2488ad37/1.jpg/471x1024.jpeg), located through the historical [MWM reference page](https://mwm.ai/apps/hole-them-all/6746115965).

These are store/promotional references, not measured pixels from the user's
installed builds. MWM explicitly identifies itself as an independent editorial
page, so it is not evidence of the game's developer or engine implementation.
Hole Them All is a separate title from the installed Hole Em All; similar names
must not be collapsed into one reference build.

This session's web interface returned image links and search descriptions,
not inspectable pixel images. Search descriptions associate the food artwork
with dense, brightly separated food stacks and geometric arrangements; those
are discovery leads, not a new pixel-level visual verdict. No current reference
highlight shape, shadow softness or edge-quality measurement is claimed here.
The Mac remains locked and authorized computer use is unavailable; the user
has already allowed playtesting. No alternate foreground or browser route was
used to bypass that access limitation.

## What the comparison can guide now

The observed Hole.io city and the food-stack references serve different purposes:
Hole.io establishes the city context and swallowable street-scale categories;
food references establish the requested composition direction. Neither proves
that a particular antialiasing switch supplies round geometry, glossy food and
soft grounding shadows together.

For the next rendered comparison, inspect these as separate visible outcomes:

1. **Silhouette:** curved body outlines and bevel transitions must survive at
   the actual phone camera distance. A smooth edge cannot establish polygon
   count or a bevel algorithm from a store image.
2. **Highlights:** compare the size, brightness and movement of reflection
   areas on icing, fruit and metal separately from their base colors. A bright
   painted patch or promotional image does not prove a particular PBR shader.
3. **Ground contact:** compare the darkening immediately beneath food and the
   direction/softness of cast shadows. Do not label either SSAO or contact
   shadows without implementation evidence.
4. **Image stability:** inspect slow camera movement and falling thin objects
   for stair-stepping, sparkle and shimmering. A resized still cannot identify
   MSAA/FXAA/TAA, native resolution or stable temporal quality.
5. **Color hierarchy:** compare edible subjects against roads, ground and HUD
   at matched exposure and framing. Bright base colors alone do not establish
   an appetizing material response or readable depth.

These are proposed acceptance observations for our implementation, not claims
that the installed games were measured in this session. The confirmed Unity
and packaged-URP evidence is useful context; it does not establish that changing
our engine is necessary, or that a specific competitor setting can be copied.
A matched-view in-game reference capture is still required to judge the desired
clean, rounded, highlighted and softly grounded appearance.
