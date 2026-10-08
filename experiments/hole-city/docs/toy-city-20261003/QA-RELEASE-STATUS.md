# Bubble Toy Town: QA and release status

This is the current local acceptance snapshot for version **0.13.0** on October
3, 2026. It supersedes the earlier map-development snapshots for local QA.
The user paused the map automation; direct, authorized combined release work
continues under the coordinator. This document does not change that automation.

## Accepted local package

The final gate runs **90 fresh source suites and 90 fresh Web-PCK suites**, with
**71,202 checks in each phase** and no reused reports. All 180 reports meet the
current registry minimums, match their completion markers and have clean
stdout/engine logs under the gate's documented expected-fixture exceptions.
The 824 guarded inputs match the before/after maps, the preserved source bytes
and the current files. The actual engine SHA matches the final provenance and
owned-run summary.

All 18 artifacts in the tested package, the final release receipt and the new
preview have identical inventories and SHA-256 values. The separate candidate
preview is `build/toy-city-20261003/web`; the 18-file historical `build/web`
preview remains byte-for-byte unchanged. No historical acceptance is relabeled
as a fresh run.

The final gate includes the original City/Food regression suites and these five
new map suites, in both source and exact Web-PCK phases:

| Suite | Actual checks per phase | Scope |
| --- | ---: | --- |
| Toy geometry | 131 | Ten original prop kinds, normalized bounds, closed surfaces, opaque shared material, cache ownership and visual-only preview |
| Guard geometry | 191 | Sixteen distinct living costumes and a drone, real geometry/props, topology, normalized bounds, collider copies and triangle budgets |
| Toy city | 2,946 | Real rotated bounds, lanes, size admission, growth reachability, actual compound support, independent layer release, intact physical collection and scene budgets |
| Toy map integration | 76 | Third-map selection, ordinary lifecycle, save compatibility, 90-second round and shared music stream/decoder continuity |
| Toy court | 639 | Actual City/Toy population comparison, routes, delivery, formation, pursuit/alarm/flee, rest, heading/contact separation and intact physics handoff |

The device-recorder helper's 12 checks and train-asset validation's 246 checks
are separately reported by the gate. They do not constitute physical-phone
recording or sandbox-purchase evidence.

## Ordinary 90-second pacing

Two fresh Mac GPU runs use ordinary automatic travel, isolated test saves and
muted game audio. Neither uses an extension or injects growth, ownership or
wallet rewards. Actual collection ledgers confirm whole palaces finish falling
before the initial 90-second round ends.

| Run | Scores at approximately 12 / 30 / 60 / 90 seconds | Whole palaces completed before 90 seconds | Final radius |
| --- | --- | --- | ---: |
| GPU06 | 18 / 48 / 104 / 306 | Two, at 87.57 and 89.28 seconds | 6.0 |
| GPU07 | 18 / 48 / 114 / 333 | Two, at 66.23 and 82.82 seconds | 6.0 |

GPU06 records 139 actual player collections; GPU07 records 159. The actual eight
inner starter palaces require radius 3.323644 and fit earned level 5 at radius
3.5. Ordinary travel outcomes still vary; these two accepted samples do not
promise the same result for every player.

The current Court06 source fixture passes 639 checks. It and both ordinary runs
share the same 711 runtime-core inputs, plus each run's owned fixture. Their
exact source bindings remain in the immutable local receipts. The final gate
subsequently binds the current complete 824-input package, including the final
public-facing credit-text changes.

## NPC and visual review

Actual construction produces 470 static toys and 344 court bodies: 814 bodies,
1,290 collision parts and 874 mesh instances. There are 80 living NPCs with 16
distinct costume geometries. The fair assembly comparison is 236 Toy world
actors against Sunny City's 217, with eight parade/traffic vehicles counted
separately. Toy uses 10 authored installation recipes repeated across 100
assemblies; Sunny City's 100 authored recipe variants remain a distinct metric.
Raw body counts or palette clones alone do not establish richer behavior.

The court fixture measures 60 horizontally moving living figures over its
22-second simulated controller interval, eight real corner deliveries, all 100
moving installation assemblies, six-body formation and 29,742 heading/contact
samples at 30/60/120 Hz. Explicit local interaction fixtures establish actual
station movement, pursuit priority, alarm/flee and pause/claim handoff. These
are controller/physics checks, not ordinary wall-clock pacing or FPS.

Independent inspection of existing GPU06-89, GPU07-60, GPU07-89 and the staged
overview finds no visible planar cut face or shell grid. GPU06-89 shows rounded
roof caps descending together into the aperture. Large intact castles and
stacked landmarks remain visible late in the round. GPU07-89 follows its earlier
palace completions and cannot independently show their falling animation. Still
images do not prove every collision or all animation frames; the actual ledger
and geometry/support checks provide separate evidence.

## Performance and physical-device limits

These are desktop wall-frame intervals from actual Mac rendering, excluding PNG
writes and capture waits. They are not iPhone FPS or GPU-timer measurements.

| Run | Full-round median / p95 | Cold first 3 seconds: p95 / maximum | After 3 seconds: p95 / maximum |
| --- | --- | --- | --- |
| GPU06 | 9.684 / 14.992 ms | 86.811 / 161.630 ms | 14.902 / 30.872 ms |
| GPU07 | 9.671 / 14.374 ms | 85.725 / 155.275 ms | 14.252 / 255.646 ms |

Both runs retain startup spikes. GPU07 also has real late spikes around 81–84
seconds, including 255.646 ms. Their cause is not established by these interval
samples. No smooth-phone-performance claim follows from the desktop medians.

The user reports updating the connected phone; the coordinator is verifying it.
This local QA snapshot does not establish its OS version, a new installation,
audible music/haptics, actual sandbox payment or physical-device recording.
The save-preserving plan is in
[physical-review-plan.md](../release-completion-20261003/physical-review-plan.md).

## Release boundary and retained failures

The submitted version 0.12.7 / build 26 and its Apple review history remain
immutable. The coordinator owns preparation of version 0.13.0 / build 27,
latest-OS physical review evidence, sandbox paid-feature verification,
three-world store assets and Apple's Guideline 2.1 response. This document
does not claim a newly signed IPA, device installation, upload, reply,
resubmission, approval or public availability. Native SDK configuration and
privacy evidence require their own package/account receipts.

Rejected GPU04 remains preserved: a clean 90-second run reaches 219 points but
collects no palace. GPU05 remains a failed capture-only diagnostic, not a pacing
pass. The original parser, geometry-fixture, seek-boundary and fixture-teardown
failures also remain in their numbered evidence directories. Successful later
attempts do not overwrite or erase them.

Current authoritative local receipts:

- `artifacts/toy-city-20261003/web-gate-01/release.json` — SHA-256
  `90282062e4106474c22549fb8dba87ee8a28d959b68cc862c1ca1aca983506c4`.
- `build/toy-city-20261003/web-gate-01/independent-review-01.json` — SHA-256
  `52ac6fd008b90a6a4dc2d29481592062d89c35ea384eb36c9acef18b76c9884c`;
  binds all 180 reports/logs, engine, input maps and exact preview artifacts.
- `build/toy-city-20261003/ordinary-palace-cohort-01.json` — SHA-256
  `41ff5de003b02ee8d8d97b7f0b10a6e840028f53a850266b2e571125230335f4`.
- `build/toy-city-20261003/ordinary-palace-pixel-review-01.json` — SHA-256
  `d31144298965939317cc8f914ae7a9d6d9ac01eeb3397a68d214b1f38845bb5f`.

The preserved final Web-PCK SHA-256 is
`3f005c0a65a898d03825e0efda212df4638c6377396a2afe4e648644398439fa`.
Private build receipts are local handoff evidence; they contain no new approval
or publication authorization. No Git publication is performed by this review.
