# Public oven site replacement evidence — 2026-09-18

Scope: one bounded correction for the unused public oven installed from need event 59. The probe
and replacement were run only on disposable copies; this change does not write the canonical town.

## Site selection

The original point `[-18.5, 0.1, 36.0]` is 4.0 m from the verified west road, outside the core's
3.0 m observation gate. The only west-forecourt arrival slot inside that gate belongs to a resident
who does not know the place. At live sequence 243 the old point still had all four flour and empty
`known`, `jobs`, `commands`, and `ledgers`, so it remained eligible for the narrow unused-point
replacement.

Actual `town_street.tscn` restore-only probes compared z=37.3 and z=37.4. Both passed. The selected
site is `[-18.5, 0.1, 37.4]`, because it gives the common road 0.1 m more observation margin while
retaining the same clear work approach:

- Three samples on the authored west road at x=-19.5, -18.5, and -17.5 were 2.786 m, 2.600 m,
  and 2.786 m from the oven; all three had real physics line of sight.
- The smith and carpenter's established west-forecourt slots were 1.780 m and 2.602 m away and
  both had line of sight. The well-keeper and baker slots remain farther away, but their normal
  road route crosses the verified three-sample discovery corridor.
- The real navigation map reached the work apron with a 0.050 m endpoint error.
- A real resident capsule following the production fallback road steering reached the apron in
  385 physics frames, ending 0.440 m from the target (inside the authoritative 0.45 m gate).
- The apron retained real line of sight to the oven mouth. The production oven collider was present.
- The restore-only probe left the candidate save byte-identical and made zero model calls.

## Replacement semantics

`replace_unused_baking_route` accepts only a host-reviewed command and refuses replacement unless
the old active point has never been observed or used: remaining flour must equal initial flour;
there may be no knowledge, job, command, ledger, or use event. The replacement must cite the same
need sequence and carry exactly the same initial flour. It creates a new point/install, removes only
the unused old active projection, preserves both immutable install journals and install events, and
appends one explicit `baking_route_superseded` event linking old to new.

The validator now rejects any inactive install journal without that exact supersession evidence.
The operation is idempotent for an exact retry and returns a command conflict for a changed payload.
It deliberately permits only this one supersession hop: the replacement must remain active, so it
cannot itself be replaced through the same operation. This is a one-time unused-site correction,
not a general facility migration chain.

## Verification

- `town_baking_replacement_acceptance.gd`: 27 checks, 0 failures, 0 paid calls.
- `town_baking_route_acceptance.gd`: 53 checks, 0 failures, 0 paid calls.
- `town_baking_physics_acceptance.gd`: 66 checks, 0 failures, 0 paid calls.
- `town_baking_site_probe.gd` on a replaced sequence-243 copy: 10 checks, 0 failures, save
  byte-identical, 0 model calls.
- The new CLI succeeded on a disposable copy and its exact retry returned `duplicate`; final active
  point was `public_bakery_oven_west_forecourt_v2`, both install records remained, total flour was
  still four, and the four use-state dictionaries remained empty.
