extends SceneTree
## Exercise the real hole/controller with an isolated game callback fixture.
## This suite never loads or writes player progress.
const Hole=preload("res://fidelity/hole.gd")
const OLD_STARTS=[0,10,30,60,100,160,240,350,500,700,950,1250]
const OLD_RADII=[.85,1.2,1.65,2.2,3.5,5.1,6.0,7.2,8.7,10.2,12.0,14.0]
class FixtureGame:
	extends Node3D
	const WORLD_LIMIT=76.0
	var phase:="playing"
	var notifications:=0
	var reported_score:=0
	func level_up()->void:notifications+=1
	func note_skin_progress(points:int)->void:reported_score=points
	func auto_direction(_hole:Node3D,_delta:float)->Vector2:return Vector2.RIGHT
	func screen_direction(direction:Vector2)->Vector2:return direction
var checks:=0
var failures:Array[String]=[]
var fixture:FixtureGame
var metrics:Dictionary={}

func _initialize()->void:run.call_deferred()

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func make_hole(player:bool)->Node3D:
	var hole:=Hole.new();hole.game=fixture;hole.is_player=player
	fixture.add_child(hole);fixture.add_child(hole.hole);hole.hole.hide()
	hole.set_physics_process(false)
	return hole

func badge(hole:Node3D,expected_level:int,earned:int,cost:int)->void:
	check(hole.level==expected_level and hole.label.text=="LVL %d"%expected_level,"Award updates the real level and visible badge at level %d"%expected_level)
	check(hole.meter.text=="%d / %d"%[earned,cost],"Badge has the correct positive next-level cost at level %d"%expected_level)
	check(is_equal_approx(hole.rim.scale.x,hole.radius) and is_equal_approx(hole.disk.scale.z,hole.radius),"Rendered rim and disk follow awarded growth at level %d"%expected_level)

func old_progression()->void:
	var human:=make_hole(true)
	badge(human,1,0,10)
	check(Hole.LEVEL_STARTS==OLD_STARTS and Hole.RADII==OLD_RADII,"All twelve original thresholds and radii remain compatible")
	for index in range(1,OLD_STARTS.size()):
		var cost:int=OLD_STARTS[index]-OLD_STARTS[index-1]
		human.award(OLD_STARTS[index]-1-human.score)
		badge(human,index,cost-1,cost)
		check(is_equal_approx(human.radius,OLD_RADII[index-1]),"Original radius holds until the actual threshold %d"%OLD_STARTS[index])
		human.award(1)
		var next_cost:int=OLD_STARTS[index+1]-OLD_STARTS[index] if index+1<OLD_STARTS.size() else 350
		badge(human,index+1,0,next_cost)
		check(is_equal_approx(human.radius,OLD_RADII[index]),"Original radius is applied at threshold %d"%OLD_STARTS[index])
	check(fixture.notifications==11 and fixture.reported_score==1250,"Player score callbacks and level-up notifications preserve original progression")
	check(human.score==1250 and human.pulse_charge==100.0,"Player awards retain full points and pulse charge")
	# The next thresholds come from an independent increasing-cost recurrence.
	var next_score:=1250;var cost:=350;var previous_radius:=14.0
	for next_level in range(13,213):
		next_score+=cost
		human.award(next_score-1-human.score)
		badge(human,next_level-1,cost-1,cost)
		human.award(1)
		cost+=50
		badge(human,next_level,0,cost)
		check(human.radius>previous_radius and human.radius<48.0,"Actual award continues physical growth without a new nearby cap at level %d"%next_level)
		check(Hole.level_start_for(next_level)==next_score,"Extended score helper agrees with the independently accumulated threshold %d"%next_level)
		check(Hole.level_for_radius(human.radius)==next_level,"Swallow hints find the first fitting extended level %d"%next_level)
		previous_radius=human.radius
	check(is_equal_approx(Hole.radius_for_level(13),15.88888888888889) and Hole.radius_for_level(20)>24,"The first post-cap levels give visible, substantial size increases")
	check(Hole.level_for_radius(48.0)==0 and Hole.level_for_radius(INF)==0 and Hole.level_for_radius(NAN)==0,"Unreachable or invalid footprints do not invent a level hint")
	metrics.extended_level=human.level;metrics.extended_radius=human.radius

func large_awards()->void:
	var human:=make_hole(true)
	var previous_level:=0;var previous_radius:=0.0
	for total:int in [1600,5000,50000,1000000000,1000000000000,1000000000000000000,Hole.MAX_SCORE]:
		var before_notifications:=fixture.notifications
		human.award(total-human.score)
		check(human.score==total and human.level>previous_level,"Large actual award preserves score and skips directly across levels: "+str(total))
		var start:int=Hole.level_start_for(human.level)
		var progress:Dictionary=human.growth_progress()
		check(start<=total and progress.earned>=0 and progress.earned<progress.cost and progress.cost>1,"Large-score progress is bounded by a genuine next-level cost: "+str(total))
		check(Hole.level_for_score(start-1)==human.level-1 and Hole.level_for_score(start)==human.level,"Exact integer comparison retains both sides of a large-score threshold: "+str(total))
		check(is_finite(human.radius) and human.radius>previous_radius and human.radius<=48.0,"Large awarded size grows while remaining finite and safe for world geometry: "+str(total))
		check(fixture.notifications==before_notifications+1,"A giant receipt emits one level-up event rather than one event per skipped level")
		badge(human,human.level,progress.earned,progress.cost)
		previous_level=human.level;previous_radius=human.radius
	check(human.level==607400105 and Hole.level_start_for(human.level)==9223372021815247700,"Signed-64-bit endpoint agrees with an independently computed integer-root oracle")
	var before_score:int=human.score;var before_level:int=human.level;var before_meter:String=human.meter.text
	human.award(Hole.MAX_SCORE)
	check(human.score==before_score and human.level==before_level and human.meter.text==before_meter,"Repeated extreme rewards saturate numeric storage without overflow or negative progression")
	check(Hole.level_start_for(Hole.MAX_SCORE)==Hole.MAX_SCORE,"An out-of-storage threshold query cannot overflow")
	metrics.maximum_score=str(human.score);metrics.maximum_level=human.level;metrics.maximum_radius=human.radius

func rival_rewards()->void:
	var small:=make_hole(false);var aggregate:=make_hole(false)
	var expected=[0,1,2,2,3,4,4,5,6,7]
	for index in 10:
		small.award(1)
		check(small.score==expected[index] and small.ai_reward_tenths>=0 and small.ai_reward_tenths<10,"One-point NPC food accumulates exactly seventy percent: receipt %d"%(index+1))
	aggregate.award(10)
	check(small.score==aggregate.score and small.ai_reward_tenths==aggregate.ai_reward_tenths and small.collected==10,"Reward splitting cannot lose fractional NPC growth or receipt counts")
	for index in range(10,15):small.award(1)
	check(small.level==2 and small.score==10 and small.ai_reward_tenths==5,"A rival eventually levels up from only one-point food")
	badge(small,2,0,20)
	var grouped:=make_hole(false);var split:=make_hole(false)
	var input_sum:=0
	for points in [1,2,3,7,19,251,1600,4,1]:input_sum+=points;split.award(points)
	grouped.award(input_sum)
	check(split.score==1321 and split.ai_reward_tenths==6 and grouped.score==split.score and grouped.ai_reward_tenths==split.ai_reward_tenths,"Mixed NPC receipts retain exact rational credit independent of grouping")
	var giant:=make_hole(false)
	giant.award(Hole.MAX_SCORE)
	check(giant.score==6456360425798343064 and giant.ai_reward_tenths==9,"Extreme NPC reward applies seventy percent without intermediate multiplication overflow")
	giant.award(Hole.MAX_SCORE)
	check(giant.score==Hole.MAX_SCORE and giant.ai_reward_tenths==8,"Repeated extreme NPC rewards remain numerically safe")
	var restarted:=make_hole(false)
	check(restarted.ai_reward_tenths==0 and restarted.score==0 and restarted.level==1,"A new round's rival has a fresh fractional ledger")
	var human:=make_hole(true)
	for index in 15:human.award(1)
	check(human.score==15 and human.ai_reward_tenths==0,"Small player food keeps full credit and never enters the AI discount")
	metrics.npc_small_food_score=small.score;metrics.npc_small_food_tenths=small.ai_reward_tenths

func movement()->void:
	var human:=make_hole(true);var rival:=make_hole(false)
	human.test_direction=Vector2.RIGHT
	human.enabled=true;rival.enabled=true
	await physics_frame
	human._physics_process(1.0/60.0);rival._physics_process(1.0/60.0)
	check(is_equal_approx(human.velocity.length(),7.8/(1.0+.85*.05)),"Real player controller keeps its original base movement speed")
	check(is_equal_approx(rival.velocity.length(),3.5/(1.0+.85*.05)) and rival.position.x>0,"Real rival controller moves at the reduced 3.5 base speed")
	human.speed_boost_time=1.0;human._physics_process(1.0/60.0)
	check(is_equal_approx(human.velocity.length(),7.8*1.55/(1.0+.85*.05)),"Player's existing movement ability multiplier is preserved")

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	fixture=FixtureGame.new();root.add_child(fixture)
	old_progression();large_awards();rival_rewards();await movement()
	fixture.free();await process_frame
	print("GROWTH_EXTENSION_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Real hole awards, badges and movement; isolated callback fixture, no player-save access"}))
	quit(0 if failures.is_empty() else 1)
