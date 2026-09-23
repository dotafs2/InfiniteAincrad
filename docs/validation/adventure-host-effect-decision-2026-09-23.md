# Adventure host effect decision — 2026-09-23

The host selects `max(1, attack_power - defense_power)` as the v1 damage rule for
the bounded original extension. It is not official Aincrad canon. The reducer
executes it only with authoritative attack power, defense power and equipped
weapon; unknown values reject the action. Resident-versus-resident damage stays
out of scope.

The decision is supported by 29 reducer checks, 91 detached capability-registration
checks, 16 migration checks, 13 rendered navigation/retreat checks and 14
workstation route checks. Exact cold restore passed and the canonical seq323 hash
remained unchanged. This decision requests a disposable live-install review only;
it does not authorize canonical mutation or resident adoption.
