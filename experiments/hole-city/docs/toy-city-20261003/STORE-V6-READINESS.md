# Three-world V6 media and upload readiness

This is a local release checklist, not an upload receipt. The user paused the
toy-map automation; direct authorized combined-release work continues. Root owns
native27, the physical device, Apple fields, upload and the App Review response.
No engine, GPU or encoder was started for this readiness check.

## Verified candidate binding

- Candidate game: `0.13.0`, three worlds selectable on HOME between rounds.
- Accepted gate: `artifacts/toy-city-20261003/web-gate-01/release.json`.
- Gate SHA-256: `90282062e4106474c22549fb8dba87ee8a28d959b68cc862c1ca1aca983506c4`.
- All90 source suites and all90 exact Web-PCK suites executed freshly; each
  phase passed71,202 checks. There is no report reuse.
- Current824 guarded input hashes match the accepted gate exactly.
- The18 published preview files match the tested package exactly. Web PCK:
  `3f005c0a65a898d03825e0efda212df4638c6377396a2afe4e648644398439fa`.
- These facts establish source/Web acceptance, not native installation,
  StoreKit sandbox success or physical-iPhone performance.

## English listing copy

The current V6-specific English copy is
`artifacts/toy-city-20261003/store-copy-v6/store-copy.md`; its local character
checks are in the adjacent `copy-checks.json`. The public store fields retain
the inspected draft wording. The V6-specific preamble identifies actual accepted
0.13.0 and keeps native/device evidence separate.

| Field | Current text or count | Limit |
| --- | --- | --- |
| Name | Black Hole Feast: Eat & Grow ·28 characters |30 |
| Subtitle | Cities, Snacks & Toy Castles ·28 characters |30 |
| Keywords |99 ASCII characters |100 |
| Promotional text |138 characters |170 |
| Description |1,877 characters |4,000 |

Keywords:

`food,collect,skins,physics,donut,cake,sushi,offline,relaxing,arcade,toy,castle,games,eating,swallow`

The copy says HOME selection occurs between rounds; City/Toy start at90seconds,
Food at60. Optional1.5x earned coins and extra30seconds remain independent once
per round. It identifies actual diamond products and provider-controlled video
length without invented prices, ad durations, rankings or successful purchases.
Original0.12.7/build26 and V5 material are historical evidence and stay intact.

## Capture helper and feasibility

Prepared helper: `build/toy-city-20261003/store-media-01.py`.
The `--phase check` command passed, with zero engine/encoder starts. Its Python
AST and dependency paths are checked; actual Godot parsing, rendered frames,
train visibility, master timestamp alignment and encoded playback are not yet
verified. The helper is awaiting root's single heavy-job lease.

Private future output: `build/toy-city-20261003/store-review-v6/`.
Public future output: `artifacts/toy-city-20261003/store-review-v6/`.
Neither output exists at this check. Each phase binds the final gate, all actual
suite reports/logs,824 current inputs, engine, helper, copy, captions and branding
hashes. Previously completed folders are not overwritten.

The planned recording is four sequential normal masters: City90, Food60, Toy90,
and Sushi60. Each begins with actual mouse input on HOME, PLAY and real intro
input. Only ordinary direction input follows; there are no granted score,
radius, position, wallet, skin ownership or extra-time fixtures. Live output
uses Dummy while MovieWriter records the mixer. Nice15, bounded owned process
groups and low encoder thread counts keep the job below normal user processes.

Actual ordinary GPU06 completed90seconds at306points/level7, with complete
castle collections at87.5667 and89.2833seconds. This supports capture feasibility
but does not guarantee the next independent normal master reproduces that path.
Its desktop frame median is9.684ms and p95 is14.992ms at the previous capture
resolution; those are not phone FPS or guaranteed886x1920 MovieWriter costs.
The new helper deliberately stops if the fresh Toy master has no real ordinary
castle collection, City has no intact48-point collection, or Sushi has no clear
moving-train section. Preserve failures and inspect the real pixels rather than
substituting old gameplay or injecting growth.

Budget approximately7–15minutes for serial import/four-master recording/two-video
export, subject to actual MovieWriter cost. The masters contain300seconds of
normal gameplay plus their real UI/result transitions. Raw AVI/snapshot output
remains private; prepare requires6GiB free space. V5 and draft01 are preserved.

Commands, only after root allocates the appropriate lease:

```sh
python3 build/toy-city-20261003/store-media-01.py --phase check
/usr/bin/nice -n 15 python3 build/toy-city-20261003/store-media-01.py --phase prepare
/usr/bin/nice -n 15 python3 build/toy-city-20261003/store-media-01.py --phase capture
/usr/bin/nice -n 15 python3 build/toy-city-20261003/store-media-01.py --phase export
```

The helper currently pins the inspected draft01 copy; its public store fields
are byte-equivalent to the V6 copy. Root should use the V6-specific preamble/review
notes when preparing final Apple fields. No listing field has been saved here.

## Five screenshots to inspect before upload

| Order | Composition | Required actual source |
| --- | --- | --- |
|1 | THREE WORLDS. / ONE HUNGRY HOLE. | Accepted HOME, all three available cards, actual map selection and framing. |
|2 | SMALL BITES. / GIANT FEASTS. | Fresh ordinary Food60 stack actually dropping into the hole. |
|3 | SUSHI. / ON THE MOVE. | Fresh moving Sushi Express with recognizable cars and unchanged HUD. |
|4 | TOY CASTLES. / BIG APPETITE. | Fresh ordinary Toy90 intact castle entering the mouth, with court context. |
|5 | EAT YOUR WAY / THROUGH TOWN. | Fresh Sunny City whole building falling; no shell fragments or fake size. |

Inspect all five complete1320x2868 opaque PNGs and their editable SVGs. Each uses
the accepted original frame around the complete current viewport. Check text,
HUD, corner masks, swallowing state, roof/wall continuity, color clipping and
control clearance. Broad whole-building stipple must be reviewed separately;
physical receipt counts alone do not establish visual polish. A root Toy PNG
requires full accepted-source/image binding and truthful ordinary-play metadata.

## Two videos to inspect before upload

1. `01-three-worlds.mp4`:20seconds. Genuine HOME/PLAY boundaries for City, Food
   and Toy each precede that world's actual ordinary swallowing. Within-world
   cuts remain chronological and normal speed. World changes happen on HOME;
   the montage must not imply in-round teleportation.
2. `02-sushi-express.mp4`:20seconds. Ordinary earned growth and the real moving
   sushi train, with actual car-position/visibility samples and swallowing
   receipts. Do not imply injected growth or a successful ad/purchase.

Verify886x1920 H.264/yuv420p/30fps, AAC stereo48kHz, full decode and measured
non-clipping game audio. Open both files muted and inspect beginning, every cut,
late swallow and ending. Check actual raw-frame alignment against receipt
timestamps. No title banner covers HUD, no frames are retimed, and no effects
are painted over gameplay. Contact sheets and receipt hashes are supporting
evidence, not a substitute for actual playback review.

## Apple completion checklist owned by root

- Complete and verify the exact native27 signature/IPA and current food icon;
  preserve source/Web and separate SDK/native packaging bindings.
- Back up phone saves before authorized installation; retain exact installed
  version/build, device OS and launch receipts.
- Establish the required current-OS physical-device launch-to-typical-flow
  recording for Guideline2.1, including main navigation and real IAP access.
  Mac marketing media cannot substitute for this recording.
- Use actual StoreKit prices/catalog states. Record real sandbox outcomes;
  neither code checks nor an unavailable-price mock proves a successful purchase.
- Finish the truthful seven-item reply/App Review Notes and any changed version
  metadata. Review SDK/privacy/service/regional statements against native27.
- Upload the reviewed fivePNG/twoMP4 pack, verify Apple's processed assets, choose
  the actually processed new build, and complete the authorized review response.
- Preserve prior rejection, failed attempts, V5/draft01 and local player saves.
  No bank/tax declaration, new legal agreement or Git publication is made here.
