# Night delivery: ten DeepSeek GMs and reviewed baking candidate

Date: 2026-09-18 (Beijing)
World: `research:gm-npc-20260917:living-quarter-01`

## Result

Ten distinct retained GM sessions (`gm-01` through `gm-10`) each completed one substantive DeepSeek observation against this same world lineage. Nine completed against the immutable life-seq 166 projection. `gm-05`'s seq166 provider stream disconnected after the request began but before any completed usage record; that attempt remains unknown-cost and was never replayed. `gm-05` instead completed one new observation against the later immutable seq173 projection.

The successful runs are:

- `run-20260917T191216Z-3591d1`: gm-01 through gm-04 succeeded; gm-05 failed unknown-cost; later GMs were not dispatched after the abort.
- `run-20260917T192232Z-17d218`: gm-06 through gm-10 succeeded.
- `run-20260917T193335Z-44d048`: gm-05 succeeded on seq173 as a new snapshot task, not a retry of the failed seq166 task.

The source GM state was copied once into the delivery-private state. The original retained state and all immutable world snapshots remained unchanged.

## Usage accounting

For every successful observation, `usage` is the measured difference between that session's `usage_accounting.baseline` and `usage_cumulative`. Summing those ten per-attempt deltas gives:

| Field | Measured delta |
| --- | ---: |
| input tokens | 13,039,458 |
| cached input tokens | 10,535,424 |
| cache-write input tokens | 0 |
| output tokens | 155,532 |
| reasoning output tokens | 125,640 |

The audit records are each run's `run.json` and `gm-XX.attempt.json` under `private/night-delivery/gm-state/runs/`. Every successful result has `cost: measured` and `usage_accounting.status: measured_delta`, with coverage `since last measured session highwater`.

This is token accounting, not a currency invoice. `currency_billing` is explicitly `not derived from token counters`. In particular, the later successful gm-05 delta may overlap or incompletely cover the earlier unknown interval; no exact incremental provider charge is claimed. The failed attempt remains `cost: unknown`, `usage: null`, and `usage_measured: false` in both its attempt file and `state.json` recovery/acknowledgement records.

## Candidate selected for substantive host review

GM-07 owns the unverified `public_baking_route` proposal. Its proposal is a finite-flour public point learned only through each resident's own line of sight, followed by a voluntary 60-second bake that conserves flour and produces the acting resident's own eatable loaf. Installation grants no skill, item, material, or coin. Later ordinary resident action, a terminal receipt, and GM-07 effect review are required before adoption may be claimed.

The correct resident grounding is life event 59: the baker publicly says they want to learn bread baking and asks about flour or an oven. Events 157-162 concern a separate wooden oven-frame commission. They can support the west-forecourt location, but they do not prove that a resident built or delivered this public oven.

The exact candidate spec is `private/night-delivery/baking/install-spec.json`:

```json
{
  "id": "public_bakery_oven_west_forecourt_v1",
  "label": "西侧工匠前庭公共烤炉",
  "initial_flour": 4,
  "position": [-18.5, 0.1, 36.0],
  "access": "public"
}
```

The coordinate and four-unit stock were selected by the host for review; GM-07 did not publish this exact spec. The installer records `actor_id: development_gm`, `source: development_gm_review`, and no recipients. The only accurate release description is a host-reviewed public point placed in response to seq59—not a resident-built oven, fulfillment of the carpenter's commission, or an autonomous GM publication.

## Immutable-copy validation

The candidate was installed only into a copy of frozen seq201. Source SHA-256 `ac592d2007244e0b38197919d904b53d1b1264f78ffc012b345ee04124115f4f` remained unchanged. The installed copy SHA-256 is `7e08d8bd9db4ce576007d363bede9290a9c5e5bdcc79b240119826ab4d7937d1`.

Validation results:

- installer returned `baking_route_installed` for source seq59;
- real `town_street.tscn` cold restore exited 0 and did not change the candidate bytes;
- navigation reached `ready`;
- all 40 existing resident-to-public-place paths remained reachable;
- all 16 house door/window collision fixtures passed;
- the oven visual and line-of-sight target existed at `[-18.5, 1.15, 36.0]`;
- the authoritative working point `[-18.5, 0.1, 36.85]` was 0.05 m from the navigation surface;
- all 10 current resident positions had a navigation path to the working point;
- a resident-sized capsule reported no solid overlap at the working point.

Private evidence is in `private/night-delivery/baking/seq201-copy/quarter-review/report/report.json` and `private/night-delivery/baking/seq201-copy/site-probe-2/report.json`.

The reviewed canonical command is therefore:

```text
Godot_v4.7.2-stable_mono_win64.exe --headless --path game --script res://tools/install_baking_route_cli.gd -- --town-save=<canonical-world.json> --source-seq=59 --command-id=development_gm:night-20260918-public-baking-seq59-host-review-v1 --spec-file=<absolute-install-spec.json>
```

It must run only at a coordinator-owned safe write boundary. Installation alone is not adoption.

## Bounded maintenance risk

The current food loop is not renewable at the ten-resident load. Hunger drops by one every 120 simulation seconds, and a ration restores 40 hunger, which is equivalent to about 7.5 rations per simulation hour for ten residents. The only renewable food producer found in the core loop is the berry node at one berry per 1,800 simulation seconds, or two per hour. The resulting steady-state deficit is about 5.5 ration-equivalents per simulation hour.

At frozen seq201 the foraging stock is zero of six, with three berries produced and nine harvested; the next berry is about 10.07 simulation seconds away. Residents collectively hold nine food, four residents hold none, and the smith and carpenter are already at zero hunger. The reviewed oven's four finite flour units would therefore be a buffer rather than a sustainable supply fix. A simple `(9 + 4) / 5.5` upper-bound estimate is about 2.36 simulation hours, before distribution and action latency.

This is a simulation-time risk, not a wall-clock deadline claim: a paused world does not consume food while waiting for 09:00 Beijing. The current rules also do not apply death or damage at zero hunger, so the supported description is chronic shortage with residents at zero hunger—not starvation or death. After a genuine ordinary-resident baking adoption, the next bounded GM maintenance review should seek an attributable sustainable-production proposal; this evidence does not authorize broad agriculture or a new platform.

## Runner reliability change

`gm_runner.emit()` now ASCII-escapes its final one-line JSON envelope. Persisted prompts and model results remain UTF-8. This prevents a successful paid turn containing Chinese text from being hidden by a later `UnicodeEncodeError` on a legacy Windows console. A cp1252 regression test covers the boundary.

## Validation commands

```text
python -m unittest tools.test_gm_runner
python -m unittest tools.test_gm_autonomy tools.test_run_production_gm_autonomy
```

Godot asset UID and navigation edge warnings remain pre-existing diagnostics. They did not prevent the navigation map reaching `ready`, but this validation does not relabel those warnings as fixed.
