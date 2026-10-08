# Rival combat and AI food decisions

Implemented 2026-09-28. Runtime owner: city agent (`fidelity/game.gd`). Hole growth/speed/reward rules are separately authored in `fidelity/hole.gd`; this change calls those APIs without duplicating their formulas.

## Problem and resulting behavior

Previously every pairing required a 1.4 radius ratio. A level-12 hole of radius 14 could never eat a level-11 hole of radius 12: it would need radius 16.8 while growth stopped at 14. The first ten seconds also disabled **all** rival combat, and the AI steering routine could select only food objects. Rival swallowing was therefore limited to chance overlaps among already sufficiently different sizes.

The size rules are now player-to-AI 1.15, AI-to-AI 1.20 and AI-to-player 1.40. Equal-sized holes remain ineligible. The first ten seconds protect the player from being eaten; they do not prevent the player or other AI from eating eligible AI. A legal size relation alone does not award anything: the complete smaller mouth must fit inside the larger mouth.

Combat runs each physics step. A bounded relative-motion segment catches fast crossings between samples. Remote teleports are rejected as movement history, and explicit restarts/test fixtures call `reset_rival_state()`. The first protection-expiry step cannot replay a contact from protected time.

AI steering can select a nearby eligible rival while preserving its separate food target. It prefers a reachable nearby opponent or one nearer than its available food, with modest target persistence. Existing released-food settlement remains first: the AI waits for gravity rather than abandoning its current meal. The player retains manual steering. No AI is instructed to move into a predator, no opponent is retired without the geometry test, and no score is injected to stage a win. The separate hole change supplies the slower AI movement and exact 70% receipt accounting.

Each combat scan snapshots radii and victim scores, resolves larger predators first and retires a victim before granting its normal reward. A reward cannot unlock a second size gate within the same scan. The largest-first ordering prevents a dead intermediate opponent from taking another turn or duplicating victim rewards; array order does not decide the outcome. The existing reward base is preserved: max(5, 30% of the victim's score), followed by the recipient's ordinary `award()` behavior.

Pending `claimed_by`, `pull_owner`, `fall_credit` and delayed `release_hole` references transfer to the survivor. A weak successor map resolves a late physical collection receipt to its still-active owner. Round settlement still rejects subsequent receipts and is idempotent. No round goal, balance, saved progress or existing growth table was reset.

## Extended-growth integration

Food admission hints call `level_for_radius()` instead of indexing the original twelve radii. Reachable items show their actual required level; an unreachable requirement displays `TOO LARGE`. The camera retains its established offset direction and zoom behavior, but respects an 8% mouth-sphere margin using the current viewport aspect and limiting perspective field of view. The minimum distance also holds during smoothing after a large growth step. The far plane is at least max(220, distance + radius + 20). Root and the growth agent independently validate this integration.

## Author evidence

`tests/rival_combat_acceptance.gd` passes **58 checks** through the strict release acceptance helper. Evidence: `artifacts/rival-combat-20260929/author.json` and `author.log`.

The movement tests instantiate the real game, physical cut ground, actual hole controllers and actual falling food in a bounded arena. Both AI are enabled and move through normal steering. At 30/60/120 physics Hz the hunter travels 5.20–5.28 metres while prey forages almost 2 metres, then one legal swallow occurs after approximately 1.61–1.70 seconds. The hunter's score increases from 30 to 33 through the real reduced reward function. No direct scan or position placement performs that swallow.

Other checks cover the real level-12/level-11 pairing, all three ratio boundaries, complete-circle containment, equal-sized opponents, opening protection, protection expiry, nonplaying phases and pause, swept crossings, rejected teleport sweeps, same-step growth limits, reversed array order, duplicate scans, pending ownership transfer, late collection and food settlement priority.

This is native headless gameplay evidence, not browser visual acceptance, full-city balance validation or an iPhone frame-rate measurement. The controlled arena removes unrelated city activity to isolate opponent behavior. Root coordinates separate independent reviews and the full source/package gate before delivery.
