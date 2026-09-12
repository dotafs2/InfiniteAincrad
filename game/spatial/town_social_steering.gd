extends "res://spatial/town_foraging_steering.gd"
## Bounded local detour steering for the SOCIAL approach journey only.
##
## Reviewed defect this serves: in the real shared-world run the innkeeper held the
## accepted approach turn:shared:innkeeper:0:2 at x=2.000277 with zero accrued work
## for 93.5167 s, 1.1503 m from the meeting point, while the carpenter stood
## 0.500277 m away - exactly the 0.5 m sum of the two 0.25 m resident capsule radii.
## The approach action had no detour steering at all, so the mover pressed straight
## into a stationary neighbour and the physical contact cancelled every step.
##
## This owner deliberately adds no new geometry. It reuses the already-validated
## bounded search exactly as the material and foraging journeys do: a two-leg
## perpendicular waypoint search over four fixed distances and two sides, then the
## three-segment rectangle fallback, every leg swept with the mover's own capsule
## through body.test_move. No navmesh, no broad plan, no world mutation.
##
## What this file exists for:
##  - the social journey owns its own route cache, so a material detour and a social
##    detour can neither share nor drop each other's route;
##  - the social contract and its limits are stated in one reviewable place.
##
## One behaviour is added on top of the reused search, and only one: when no bounded
## route exists at all, the resident still walks straight at the accepted target and
## lets real contact stop it. That is exactly the pre-repair behaviour, kept so a
## blocked social approach cannot become a resident frozen in place. The 93.5167 s
## observation is itself an instance of it: the mover was already in contact at
## 0.500277 m, so the straight push cancelled every step and position_delta stayed 0.
## This fallback grants no arrival, no work and no receipt by itself.
##
## Explicit limits, unchanged from the reused algorithm:
##  - a bounded detour cannot solve mazes or fully enclosed goals;
##  - a target whose arrival radius is physically occupied stays honestly unfinished
##    and pending. The mover never gains arrival, work or a receipt by shrinking
##    collision, moving a bystander, widening the 0.45 m gate or teleporting;
##  - the cached route is re-validated every physics frame and is never persisted, so
##    it cannot enter a save, a resident view or a model context;
##  - with no bounded route the mover can only press against the obstruction and stay
##    pending; there is still no resident-perceptible obstruction report, and that
##    general gap stays open.

func direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	var bounded := super.direction_for(id, command_id, body, target)
	if bounded.length() > 0.0:
		return bounded
	if id.is_empty() or command_id.is_empty():
		return Vector3.ZERO
	if not Engine.is_in_physics_frame() or body == null or not is_instance_valid(body) or not body.is_inside_tree() or not target.is_finite():
		return Vector3.ZERO
	var offset := target - body.global_position
	offset.y = 0.0
	if offset.length() <= ARRIVAL_RADIUS:
		return Vector3.ZERO
	return offset.normalized()
