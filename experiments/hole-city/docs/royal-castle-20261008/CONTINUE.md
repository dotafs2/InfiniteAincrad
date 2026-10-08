# Royal castle quality rebuild — 2026-10-08

## Current state

The actual third map has been rebuilt with five original Blender architectural
assets, revised palace grounds and sixteen edible garden props. Independent
art and runtime reviewers accept the focused geometry, actual GPU scenes,
ordinary gameplay, installed map cards and staged swallowing evidence.
The full 98-suite source and exact-package phases pass 176,870 and 176,860
checks. Browser startup, ordinary input/collection and return HOME are verified.
The local deliverables are ready; see the delivery closure below.

Scope is local development only. Preserve all real saves, the score economy,
other maps, native submitted 0.13.0/build34 and previous preview servers. No
phone, account, native upload, App Review submission or Git publication occurred.

## Design and ownership

The user rejected architectural simplicity and requested official Disney castle
research plus joint subagent review. Inspect the official
[Paris castle reference](https://news.disneylandparis.com/en/chateau-renovation/)
and [Cinderella Castle presentation](https://disneyworld.disney.go.com/attractions/magic-kingdom/cinderella-castle/).
Translate their low-base / middle-wing / tall-keep hierarchy, varied tower
heights, projecting window/entry surrounds and gardens into original toy
architecture. No reference image, third-party model, character, branding or
exact site arrangement is shipped.

Root owns integration, grounds, test/capture jobs and delivery.
`glacier_play_review` owns the Blender builder/assets and separately reviews
Frost isolation. `music_art_review` independently judges visual evidence;
`music_runtime_review` authors Frost isolation and independently audits root
integration and exact-package evidence. Their owned reports are
[MODELS.md](MODELS.md), [ART_REVIEW.md](ART_REVIEW.md) and
[RUNTIME_REVIEW.md](RUNTIME_REVIEW.md). One reduced-priority heavy engine/export
job runs at a time. All gameplay captures use isolated, unwritten test saves.

## Final assets and world behavior

- `tools/build_fairytale_castles.py` exports five closed, opaque mesh families:
  toy castle, grand castle, turret, gateway and townhouse. Layered blue roofs,
  gold tips, asymmetric towers, real entry recesses, balcony and grouped windows
  replace the broad roof/plain-box silhouette. Modular toy joints remain.
- Accepted generation is `models-03`: 32,184 triangles total; each castle uses
  11,756 of its unchanged 12,000 budget, with at most seven compound masses.
  Source Blender SHA-256:
  `f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766`.
  Asset manifest SHA-256:
  `f8dba47056b5b233a25c927ad7b907af16798d238e2c267ed7e99d7741180784`.
- Darker lawns, pale bordered paths and two palace forecourts use the existing
  cuttable ground slab. No overlay hides the hole. Eight topiary and eight
  planted beds are independent edible owners with actual hull containment,
  building/road/court/actor clearance and four points each.
- World capacity changes from 4,169 to 4,233 available points. Score-to-coin
  conversion, prices, wallet and saved progress are unchanged. Existing 55
  kind/size classes keep counts, support counts and minimum swallow levels;
  actual admission-radius deltas are at most 1.8491%, with no level crossing.
- Final scene: 815 bodies, 471 static bodies, 87 shape-cache entries,
  1,077 collision parts and 876 mesh instances, within unchanged budgets.
- Frost extends Toy internally, so its former five-family physics are frozen
  in a separate provider rather than inheriting new castle geometry. Preserve
  exact float32 horizontal vertices, original compact hulls, rim ordering,
  mass and support geometry. Frozen JSON SHA-256:
  `e8896a669b60ce8258fe7387ec305a6ec8840b665abd67505d0b626d0cbc7c84`.
  Tests inspect all 180 actual Frost architectural owners, including 24 supported
  bodies. The temporary visual proxy is replaced before rendering; no castle
  catalog is loaded for Frost. Other map art and thumbnails remain unchanged.

## Evidence

All paths below are relative to `artifacts/royal-castle-20261008/`.

- `before/` and `after-02/`: same-camera actual Mac GPU images. Six accepted
  after views cover front/rear crown, neighborhoods, townhouses, gardens and
  overview. Scene actors are not rearranged for static captures.
- `focused-05/`: eight focused suites, 6,527 checks, strict-clean logs. Includes
  actual garden sinking/completion once for each kind, hull bounds and Frost
  parity. Independent root/model-worker review covers the isolation code.
- `play-01/` and `play-02/`: two separate isolated ordinary GPU rounds reproduce
  one deterministic automatic route: 0→326 points, level 1→7, 77 collected
  objects including three small castles. Timeout is 90.0167 simulated seconds.
  No growth/position grant occurs in that ordinary phase. This demonstrates
  reproducibility, not different seeds or human-play coverage. Later whole-map
  cameras are explicitly staged. Strict-clean logs; measured desktop steady
  p95 frame intervals 14.37/14.481 ms, occasional maxima 140.954/143.284 ms.
  These values are not iPhone frame-rate claims.
- `swallow-04/royal.mp4`: final muted 540×960, 437-frame, 30 fps, 14.566667-second
  GPU clip. A clearly labeled level-12 fixture makes a six-metre sweep using
  normal game scans and physical sinking. Seven unique receipts total 120:
  grand castle 96, four topiary 16, two beds 8. The grand castle awards once.
  No ordinary growth/pacing claim is inferred from this staged demonstration.
  Movie SHA-256:
  `5620ab71689952df04754dcff468fdceb8bdb65e897862d718bf69f3f8191f61`.
- `thumbnail-04/`: accepted inward-facing palace composition, with neighboring
  streets and guards. Installed 880×620 `assets/map_thumbnails/toys.png` SHA:
  `f92a4dcc9937d7db4e66e853cb8812e1c983b559af43ab59c030cdd9ac8e19ec`.
  `ui-gpu-01/` passes 574 checks and shows actual short/tall, locked and safe-area
  cards. No world logic was changed to take a thumbnail.
- `index.html`: before/after toggle, detail views, normal-play frames and the
  clearly distinguished staged video. `overview.png` is its actual browser
  screenshot. Gallery: http://127.0.0.1:8786/royal-castle-20261008/index.html .

## Preserved failures and rejected candidates

Nineteen baseline files and their hashes remain under
`build/royal-castle-20261008/baseline`. Models01 exceeded the 12k triangle cap;
models02 passed geometry but its flat entry and oversize dormers failed art
review. Models03 fixes those concerns. Earlier Frost/garden typing, garden
hull-containment and freed-test-body failures remain with their logs. No
containment/admission budget was weakened to hide a failure.

Movie01 has cropped framing/stale fixture badge. Movie02 isolated its target;
movie03's stationary normal scan left neighboring props partly beyond intake.
Final movie04 uses actual movement and receipts. Thumbnail01 lacked a strong
castle focal point, 02 exposed a large outer pedestal and 03 was too wide;
only candidate04 is installed. All earlier evidence remains recoverable.

## Delivery closure

The final full gate is `web-gate-01/release.json`: 98 suites per phase,
176,870 source / 176,860 package checks. The ten-check difference is the
Frost historical-source comparison, which is unavailable inside the PCK;
all 47 packaged isolation checks pass. All 1,342 guarded inputs and 18 exported
files match. Independent runtime review scans all 392 suite logs plus export
and auxiliary logs with no unexpected warning, error or leak. Against the
previous accepted input manifest, 26 scoped entries differ (17 changed and nine
newly guarded); none are removed. Do not rerun this gate without a new concern
or changed guarded input.

- Release SHA: `e1174c847489eb053141d4604a319b91c23aaa760e893607b9c2562d5d1b0a1d`.
- PCK SHA: `60750bb44a19a1f388449f9a1cb4267eb730e23f5e06b2eaa72142b2aea73297`.
- Playable review: http://127.0.0.1:8795/royal-review.html . This additional
  HTML selects Toys and unlocks all worlds using existing `--test`,
  `--qa-unlocked-worlds`, `--qa-map=toys` flags. It has an isolated wallet and
  no save path or SDK initialization. It is hashed separately, outside the
  gate's original 18 exports; the exact tested PCK is unchanged.
- Fresh browser checks visibly confirm the new card, 90-second Toy intro,
  ordinary movement, four points collected, pause and return HOME. Music and
  sound are off in that isolated session. `browser-title.png`,
  `browser-play.png` and empty `browser-console.json` preserve evidence.
  The first PLAY mouse dispatch timed out while the world was built; the next
  screenshot confirmed the loaded intro without reload. No timing claim is
  based on this browser test.
- `delivery.json` records exact gate, PCK, wrapper and media hashes. Review
  reports separately distinguish authored work, independent checking and
  remaining phone/human-play limitations.

All owned Blender, capture, encode and gate jobs are complete. Keep the new
localhost-only preview server alive (owned session25494; PID file
`build/royal-castle-20261008/preview-server.pid`) and preserve all earlier preview
servers. No further background engine work is required. Real saves and native
build34 remain untouched.

## User-requested power cleanup — October 8, 2026

The user explicitly requested closing unused work to reduce power usage. Ten
obsolete/duplicate browser tabs were closed and the eight owned historical
preview servers on ports8787–8794 were gracefully stopped after process/cwd
identity checks. Their files and evidence remain; those old game URLs require
restarting their corresponding server if needed. Preserve only the8786 static
gallery (current Common skin page and Royal Court page) and8795 final castle
preview for this chat. The unrelated active gate-siege service8810 was preserved.
All three owned review agents are completed; no Godot/Blender/encode/awake
helper was found running. Apple review monitoring remains at three hours.
Receipt: `build/cleanup-20261008/power-cleanup.json`. This supersedes earlier
instructions to leave every historical preview server running. Future review
work should close obsolete game tabs and stop replaced owned preview services.
