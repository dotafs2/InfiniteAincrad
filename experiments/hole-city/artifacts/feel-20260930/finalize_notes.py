"""Write delivery notes only after a complete, HTTP-verified local release."""
from pathlib import Path
import json

GAME = Path(__file__).resolve().parents[2]
ROOT = GAME.parents[1]
EVIDENCE = Path(__file__).resolve().parent
v = json.loads((EVIDENCE / "verification.json").read_text())
assert v["version"] == "0.11.0" and v["inputs_unchanged"]
assert v["suites_per_phase"] == 76 and v["tested_input_count"] == 785
assert len(v["served_artifacts"]) == 10
source, package = v["checks"]["source"], v["checks"]["package"]
pck = next(a["sha256"] for a in v["served_artifacts"] if a["file"] == "index.pck")
counts = f"{source:,} source checks and {package:,} package checks"

def insert_after(path, anchor, note, unique):
    data = path.read_bytes()
    assert unique.encode() not in data, f"Already updated: {path}"
    encoded = anchor.encode()
    assert data.count(encoded) == 1, f"Ambiguous anchor: {path}"
    path.write_bytes(data.replace(encoded, encoded + note.encode(), 1))

game_note = f"""**v0.11.0** replaces the crowded music with two sparse original loops,
adds usable intermediate food sizes in every inner district, and rebuilds six
original skins with rounded forms and lit collection cards. BOOST now provides
55% faster movement for 2.5 seconds. Three cookie-supported heaps retain 177
separately falling, separately scored pieces. A follow-up fixes sleeping rain
that stayed suspended after its actual support moved or disappeared.

All changes received non-author review. All **76 source and package suites**
pass **{counts}**, with **785 stable inputs** and ten
served files verified. The rain limit remains a strict new-wave admission
capacity; existing food can wake and fall again naturally. Failed runs and
reviewed fixture maintenance remain documented. Actual browser appearance,
phone-speaker listening, retention and sustained iPhone 14 60 FPS are unverified.
See [changes, original media and complete QA evidence](docs/feel-20260930/README.md).

"""
insert_after(GAME / "README.md", "# Sink City — two playable maps\n\n", game_note, "**v0.11.0**")

roadmap_note = f"""- **Music, food progression, original skins and BOOST (2026-09-30):**
  local v0.11.0 adds sparse original music, intermediate food sizes across all
  inner districts, three separately collapsing cookie heaps, six rounded
  original skins and actual collection-card lighting. BOOST grants 55% faster
  motion for 2.5 seconds. Independent rain review also fixes suspended food
  after support loss, without extra rays or disabled sleeping. All changes
  received non-author review; 76 suites per phase pass {counts},
  with 785 stable inputs and ten verified HTTP artifacts. Failed probes and
  narrowly maintained fixtures remain recorded. Browser appearance, subjective
  phone listening, retention and sustained iPhone 14 60 FPS remain unverified.
  No Git publication was requested.
  [Changes and complete evidence](experiments/hole-city/docs/feel-20260930/README.md).

"""
insert_after(ROOT / "ROADMAP.md", "## Current work\n\n", roadmap_note, "**Music, food progression, original skins and BOOST (2026-09-30):**")

history_note = f"""## 2026-09-30 · Music, food progression, original skins and BOOST

The user reported noisy music, abrupt food-map growth, unpolished skins and an
ineffective BOOST button. Local v0.11.0 recomposes both original tracks into
four sparse parts at 104/108 BPM. It redistributes 182 existing foods into
intermediate physical sizes and turns three existing heaps into level-six
cookie foundations with 58 separate upper pieces each. Inventory, ownership,
base growth rules and the remaining 38 skin forms are retained.

Six original skin forms gain rounded geometry and lit materials. Non-author
review also found and fixed missing lights in the actual collection cards.
BOOST previously spent charge on a pull without changing speed; real touch
tests now measure a 1.55 speed ratio for 2.5 seconds, with independent Beacon
Step timing. A natural-touch food route, with rain and rivals isolated, verifies
177 separate heap receipts only after complete descent. Original music previews
and Blender model comparisons are retained; neither is a phone gameplay capture.

The complete gate exposed an obsolete rain assertion: the limit of 24 controls
new-wave admission, while previously landed food can legitimately wake again.
The maintained test observes actual body IDs at every wave, preserves the old
continuity/retirement bounds and rejects an extra spawn. Independent physical
review then found a real bug: swept-rest food could sleep without a reliable
native support contact and remain suspended after that support disappeared.
The focused fix tracks the actual support through a weak reference and wakes
the existing body when its owner, transform or collision layer changes. It adds
no extra rays, pose override, forced deletion or permanent awake state. A broader
contact-slop prototype was rejected and retained with its failed evidence.

Every implementation received non-author review, including 392 final rain
checks. Music-duration, six-skin mesh and measured opening-view budget fixtures
were narrowly maintained and separately reviewed. The first gate failure and
a later explicitly interrupted fixture-parse run remain preserved. Final
76-suite source and isolated-PCK gates pass {counts}; all
785 input hashes remain stable and all ten served files match. PCK SHA-256:
`{pck}`.

The existing preview is updated locally. Browser pixels, subjective musical
preference, actual retention and sustained iPhone 14 60 FPS remain unverified.
Player progress, unrelated resident worlds and user applications are preserved.
No Git commit or publication was requested.
See [complete iteration evidence](experiments/hole-city/docs/feel-20260930/README.md).

"""
history = ROOT / "HISTORY.md"
first = history.read_bytes().split(b"\n\n", 1)[0].decode() + "\n\n"
insert_after(history, first, history_note, "## 2026-09-30 · Music, food progression, original skins and BOOST")

doc = GAME / "docs/feel-20260930/README.md"
data = doc.read_text()
start = data.index("The full 76-suite", data.index("## Delivery verification"))
end = data.index("Current browser pixels", start)
data = data[:start] + f"""The complete **76-suite source and isolated-package gates pass**
**{counts}**, with all **785 input hashes unchanged**.
The existing local preview is updated to **v0.11.0**. All ten actual HTTP files
match the tested export, including PCK SHA-256:
`{pck}`.

- [Frozen release manifest](../../artifacts/feel-20260930/release/release.json)
- [Strict reports and served-file verification](../../artifacts/feel-20260930/verification.json)
- [Preserved first failure](../../artifacts/feel-20260930/release-first/source-food_rain_continuity.json)

An intermediate complete gate was explicitly interrupted after the reviewer
found a new fixture's missing local variable type; that failure and the
interrupted run remain preserved. The corrected fixture changed no product
behavior or assertion. The final runs use fresh evidence and stable inputs.

""" + data[end:]
doc.write_text(data)
print(json.dumps({"version": v["version"], "counts": counts, "pck_sha256": pck,
                  "updated": [str(p) for p in [GAME / "README.md", ROOT / "ROADMAP.md", history, doc]]}, indent=2))
