# Local black-hole game study

Date: 2026-09-27. Our source baseline: `7551f6c`, Sink//Field, read from
`/Users/dotafs/Documents/ChatGPT/hole-city-local/experiments/hole-city`.

**Delivery status: inventory and evidence-based desk review complete; native
playthrough and implementation pending.** No competitor has a completed,
observed playthrough in this study. Computer Use returned an access denial for
Eat Em All Black Hole and Hole.io. Earlier process launches and an accessible
window tree do not establish gameplay. No competitor files or saves were moved.
No runtime code was changed.

## Installed collection

The package identities and versions below come from local Info.plist files.
[inventory.json](inventory.json) records their paths, hashes and store IDs.
These are four identified applications, not a claim to have inventoried every
download. Sultan's Game is excluded: its earlier classification was unsupported.
All four packages report `iphoneos` and contain Unity data.

| Installed title | Local version / build | Developer | Study category | Play status |
| --- | --- | --- | --- | --- |
| Hole.io | 2.53.5 / 23736 | Voodoo | City consumption and scale progression | Pending UI access |
| Hole Em All | 2.15.1 / 421 | BRAINWORKS PUBLISHING PTE. LTD. | Target collection puzzle | Pending playthrough |
| Eat Em All Black Hole | 1.0.0 / 0 | Infinity Studio (PK) | City consumption, according to listing | Pending UI access |
| Black Hole Attack Games | 1.0.14 / 14 | Dead Pixel | Needs direct verification | Pending playthrough |

Hole Em All's current US store title is *Hole Em All: Collect Master*.
US store metadata reports 1.0 for Eat Em All and 1.0.2 for Black Hole Attack,
different from their installed package versions. Preserve both values; do not
infer that the installed copy needs an update or matches the current store build.

## What may make each game satisfying

These are **design interpretations of publisher descriptions**, not subjective
ratings from hands-on play. Store artwork and marketing cannot establish frame
rate, latency, physics reliability or the exact installed game's behavior.

| Sample | Evidence from its listing | Candidate satisfaction mechanism | Lesson to test in Sink//Field |
| --- | --- | --- | --- |
| [Hole.io](https://apps.apple.com/us/app/hole-io/id1389111413) | Small objects lead to skyscrapers; varied locations; recent release notes describe collectible albums. | A previously impossible object becomes food; local destruction builds toward visibly clearing a whole area. | Make new edible categories obvious after growth. Let the player enjoy the large-hole phase before ending the round. |
| [Hole Em All](https://apps.apple.com/us/app/hole-em-all-collect-master/id6739246483) | Collect specified targets before a timer expires; skins, events and team features are advertised. | Spotting the next target gives movement a purpose; finishing a finite set produces closure. | Test one compact target-collection variation after the core city loop works. Social systems are not needed to test this idea. |
| [Eat Em All: Black Hole](https://apps.apple.com/us/app/eat-em-all-black-hole/id6751702593) | Advertises city consumption, growth, multiple environments and offline play. | Straightforward movement and a growing area of influence can create a quick power fantasy. | Test readable routes and uninterrupted collection; do not copy its claimed speed curve without playing it. |
| [Black Hole Attack Games](https://apps.apple.com/us/app/black-hole-attack-games/id6449774937) | Description mixes hole, ball, obstacle and gun terminology. | Its actual core loop is unresolved. A collection-to-payoff loop is only a study question, not an observed feature. | Defer feature borrowing until a round is played. Do not assume this is another similarly named Attack Hole title. |

The descriptions above are supported by the linked publisher listings and
Apple's lookup API, retrieved on the study date. App Store user reviews are not
used to assert that a current installed build has a particular bug. The old
Poki observation ledger in `fidelity/REFERENCE.md` is historical browser-version
evidence; it is not a playthrough of this installed Hole.io build.

## Our verified gaps

Evidence paths below are relative to the source baseline stated above. These
are code observations and prior bounded audit results, not comparative user-test
scores.

| Gap | Evidence | Impact and proposed change |
| --- | --- | --- |
| Growth payoff is cut short | `fidelity/game.gd:9`, `:179`: the objective is 420 and reaching it ends the round. `fidelity/hole.gd:4-5` defines later thresholds at 500, 700, 950 and 1250. | Normal play ends before the upper progression sequence. A same-frame score overshoot is possible, but does not provide a sustained large-hole phase. Test a short optional clear-out phase after the objective, or retune the round's growth table as one coherent curve. |
| Collection sound has no category distinction | `fidelity/game.gd:368-373`, `:424-434`: every ordinary player collection creates the same 620 Hz, 80 ms waveform and restarts one audio player. | A cone and a major collapse share the same basic collection sound. Cache generated sound buffers; vary category/pitch; bound overlap. Give growth and a completed collapse distinct feedback. Measure audio with permitted capture or a human listener before claiming it sounds better. |
| Next useful target is unclear | `fidelity/ui.gd:482-530` shows total score, timer, kills and skills. Eligibility is computed separately by `fidelity/rim_body.gd` and the swallow path. | Prototype a brief nearby eligible-target cue after growth, using the same fit predicate as gameplay. Avoid a permanent marker over every object. |
| Visual population and collectible population differ | `fidelity/catalog_city.gd:165-172` marks residents as non-colliding and non-swallowable; `game.gd:248-250` skips them. | The previous audit's 451 entries are not 451 edible targets: 64 residents are explicitly excluded. Keep this design choice explicit and give decorative actors a consistent visual language. Do not make residents edible merely to imitate a competitor. |
| Cars and people undermine spatial readability | Earlier audit plus `catalog_city.gd:241-245`, `:283-304`, `:347-383` and `asphalt.gdshader:9` confirm inconsistent lane coordinates, duplicate traffic starts and road-band pedestrian spawns. | Shared road geometry, staggered vehicle starts, verified model headings and bounded sidewalk routes remain prerequisites for evaluating city feel. |
| The performance diagnosis is incomplete | Prior headless census found about 3.35k nodes and 1,612 mesh instances. Native process CPU was high, but no comparative frame-time capture exists. `catalog_city.gd:316-419` updates many actors; `game.gd:173-176` repeatedly scans objects; `scripts/hole.gd:83-86` moves CSG cutters under a colliding combiner. | Profile script, render, CSG rebuild and physics costs separately. CPU percentage alone cannot identify the dominant stall. Sample identical scenes before choosing between culling, spatial indexing, lower update rates or geometry changes. |
| Replays have little verified structural variation | `game.gd:100-137` rebuilds the same seeded city with the same objective and rival starts; `ui.gd:422-424` primarily reports score at completion. | After one satisfying round is proven, test a small route/objective variant and a result summary of actual category counts, largest object and newly unlocked form. More decorative assets alone do not demonstrate more replay value. |

Existing strengths worth retaining: physical rim tipping and release, staged
building fragments, a player-controlled Pulse, ten selectable forms with some
working skills, and local unlock persistence. The study does not justify replacing
these with a different engine, copying competitor assets, or adding multiple
unproven modes at once.

## First improvement pass

This is the single ordered next-pass proposal, not a second project roadmap.
No item below is implemented by this research delivery.

1. **Establish a trustworthy baseline.** After native UI access is available,
   play the four samples and our current build through a complete round or a
   clearly recorded blocker. Record actual outcomes before ranking their feel.
2. **Restore flow.** Fix the confirmed car and sidewalk defects. Profile and
   remove the dominant frame-time spike. Keep gameplay and cosmetics comparable
   before/after; do not judge optimization by node count alone.
3. **Improve one round's reward rhythm.** Add cached, differentiated collection
   feedback; show what growth newly enables; prototype a brief clear-out ending
   without changing existing unlock thresholds or writing test progress to saves.
4. **Compare the result.** Repeat the same route and test the opening, first
   vehicle, first building and ending. Keep changes only when they improve a
   measured behavior or a directly observed player-facing result.

Suggested acceptance targets below are **our proposed targets**, not measured
competitor values:

- On an agreed 60 Hz test device: p95 frame time at or below 20 ms in the fixed
  route and no gameplay stall over 100 ms; report p99 and the worst frame too.
- In three opening trials: first successful collection within 3 seconds and
  first growth within 15 seconds, without a scripted score grant.
- Eligibility cues never advertise an object rejected by the authoritative fit
  predicate. A growth test demonstrates at least one newly usable target category.
- Separate audible/visible feedback for a small item, a vehicle and a completed
  building collapse; bounded voice count and no waveform construction per item.
- Bonus clearing, if retained, has explicit duration and reward rules; timeouts,
  pause/resume and terminal result persistence still work. It cannot duplicate
  points or unlocks when leaving/restarting.
- Car footprints remain in their assigned road lane; pedestrian routes remain
  in sidewalk regions for the tested interval. Tests must check geometry and
  overlap, not only entity count and nonzero movement.

## Native playtest worksheet

Use at least one completed round and one retry per title where possible; never
reset an existing user save to manufacture a first-launch experience. Skip paid
offers. Record tutorials, login, consent, unsupported controls or crashes as
blockers rather than improvising results. Test one game at a time and close only
task-owned sessions when permitted and no longer needed.

| Checkpoint | Record |
| --- | --- |
| Entry | Version, starting level, game window size, tutorial/consent blocker |
| First 30 seconds | Input method, first collection time, first growth time, unsuccessful swallow attempts |
| Mid-round | Target readability, turning/stopping, newly edible categories, object jamming |
| Payoff | Largest consumed object, cascade behavior, ending interruption, actual success/failure |
| Feedback | Visible cues; audio only if observed with an available audio path; haptics untested on Mac |
| Replay | Result summary, useful reward, time to re-enter, change from the prior round |
| Performance | Frame-time trace where measurable; distinguish screenshots from motion evidence |

Current worksheet: **zero completed competitor rounds**. No performance rankings
or enjoyment scores are assigned. Native UI access must be enabled before
dependent gameplay observation can continue.
