# Store media and copy refresh for 0.12.4

This audit reads the preserved Store Review V1 pack, all five composed PNGs,
both existing video contact sheets and their capture receipts. It also reads
the local listing-copy source that the upload handoff reports was saved to
App Store Connect. The audit does not independently reread live Apple fields,
change an account, render media or modify the frozen game.

The V1 pack is authentic **0.12.3 Mac footage**, not current 0.12.4 footage. Keep
it intact as historical review evidence. Its decorative marketing captions
remain accurate; its embedded economy and city timing require the following
refresh before representing the changed build.

## Exact visible media findings

All paths below are relative to `experiments/hole-city/`.

| Existing composition | Visible finding | Required refresh |
| --- | --- | --- |
| `artifacts/store-review-20261001-v1/screenshots/01-black-hole-food-city.png` | HUD shows **36 POINTS / 3 COINS**. Current score coins would be zero. | Retain the food-city marketing concept; replace the entire embedded viewport with a current ordinary gameplay capture. |
| `artifacts/store-review-20261001-v1/screenshots/02-eat-grow.png` | HUD shows **153 POINTS / 15 COINS**. Current score coins would be one. Food's **00:03** timing is consistent with its unchanged 60-second base, but the coin display is stale. | Recapture an actual current stack entering the hole; use the existing original caption and frame style. |
| `artifacts/store-review-20261001-v1/screenshots/03-sushi-express.png` | HUD shows **3 POINTS / 0 COINS**, numerically consistent with current rules. The food timer is **00:31**, also compatible with a 60-second food round. No visible diamond or two-times-coin claim appears. | This specific still has no identified economy contradiction. It remains an old-version source, so recapture the Sushi Express for a fully current pack instead of relabeling its provenance. |
| `artifacts/store-review-20261001-v1/screenshots/04-swallow-city.png` | HUD shows **67 POINTS / 6 COINS**. Current score coins would be zero. Source `city-drop-553.png` belongs to the old one-minute city capture. Its visible **00:05** alone does not establish a base duration; the historical capture provenance establishes the old rule. | Capture a current street object or tram entering the hole, with the actual new timer and coin HUD. |
| `artifacts/store-review-20261001-v1/screenshots/05-original-skins.png` | The collection footer visibly states **10 points = 1 coin · Finish with points: +20**. Current rule is one coin per 100 points, cap 30, plus five for a scored finish. The **44 original skins** and single low-to-high collection remain correct. | Recapture the actual current collection and replace its intact viewport. Keep the 44-skin marketing caption. |

Matching editable originals are the same five paths with `.svg`. Each contains
an embedded intact PNG viewport. Do not paint new timers or coin values over
the old game pixels; replace the full source image after actual capture.

Both existing MP4s also need new current-version masters:

- `artifacts/store-review-20261001-v1/videos/01-food-feast.mp4`: the preserved
  `food-contact.png` visibly includes **15 points / 1 coin**, **60 / 6**, **135 /
  13**, **149 / 14** and **202 / 20**. Those show the previous per-ten-points
  economy, even though food's base duration remains 60 seconds. Original
  chronological source cuts are 11–17, 46–53 and 53–60 seconds.
- `artifacts/store-review-20261001-v1/videos/02-city-swallow.mp4`: the preserved
  `city-contact.png` shows old coin values including **24 / 2**, **30 / 3** and
  **81 / 8**. Its first contact shows **00:46** around the old source's 14-second
  position; current city timing at that position would be approximately
  **01:16**. Original source cuts are 14–20, 30–37 and 53–60 seconds.

The five screenshots and video contact frames inspected here do **not** show
a `2X COINS` button or the previous purchasable coin-pack cards. Their removal
is a stale listing/review-copy issue rather than an observed claim in these
seven formal media files. Do not overstate that finding.

Video receipts are `videos/food-receipt.json` and `videos/city-receipt.json` in
the same V1 directory. Their hashes, version labels and previous media
acceptance remain historical facts; do not edit them to imply new capture.

## Listing copy that needs replacement

Both `docs/app-store-release-20261001/store-copy.md` and
`artifacts/store-review-20261001-v1/store-copy.md` contain:

- Promotional text beginning **One minute. One hungry hole.**
- Description stating **Every round lasts one minute**.
- Review notes stating **Each gameplay round is sixty seconds**.
- Description referring to **Apple coin packs** and review notes referring to
  **COINS opens the optional coin store** / **Coin packs are consumables**.
- An obsolete draft-status paragraph naming `sink_city.coins_320` and the
  2000/9600-coin proposals. It must not be copied into new review notes.

`artifacts/store-review-20261001-v1/index.html` likewise presents the old
one-minute promotional text and **60-second rounds** in its explanatory list.
Its footer correctly identifies historical V1/0.12.3; preserve this page as the
old review rather than silently switching its media's version.

The saved-field claim comes from
`docs/upload-preparation-20261001-10/CONTINUE.md`: five images, two previews,
English copy, keywords and review notes were saved. Root should reread the
actual version fields before overwriting them, because this file-backed audit
is not fresh live-state proof.

## Refresh plan

1. Keep the same five-card order: food city, falling stack growth, Sushi
   Express, Sunny City, original collection. Retain the original decorative
   design and valid captions. Obtain new actual 0.12.4 frames with the current
   HUD, ideally during ordinary play; use a fresh evidence directory.
2. Record new food and city swallowing footage with the same following camera,
   normal-speed chronological cuts and actual game audio. City masters need
   the full 90-second base; food masters remain 60 seconds. Capture real drops
   and meaningful growth. The two preview exports can remain 20 seconds each.
   Do not substitute the isolated timer-boundary UI captures for ordinary
   gameplay or a full-duration acceptance run.
3. The current `artifacts/diamond-economy-20261002/ui-gpu-02/` frames are useful
   interface QA for 90/60 tutorials, unavailable diamond prices and a result
   continuation. They are isolated Mac GPU frames, not Apple sandbox purchase
   review screenshots. The result is a forced timer boundary with zero points.
4. A sixth feature screenshot may explain **ONE EXTRA 30s** after an actual
   normal timeout. Show the honest provider state; do not claim an available
   rewarded video without the actual SDK. Avoid making payment the main ASO
   hook; food swallowing, growth, the moving train and original skins remain
   the first five conversion messages.
5. Use the new draft in
   `artifacts/diamond-economy-20261002/store-draft/store-copy.md` for correct
   current duration, one continuation, diamonds and entry paths. It contains no
   hardcoded runtime StoreKit prices, guaranteed ad duration or false physical
   purchase acceptance. Save only after root rereads live fields and validates
   the corresponding production build/product configuration.
6. Replace Apple media with verified current exports; recheck file dimensions,
   playback, chronology, hashes and server processing. Preserve V1 assets and
   receipts. Changing local draft files does not upload or submit anything.

The lightweight caption plan is
`artifacts/diamond-economy-20261002/store-draft/captions.json`. No new media is
rendered by this audit and no old game pixels are modified.
