extends SceneTree
# Exact maintained predicates copied programmatically for bounded negative fixtures.
# This checks predicate sensitivity, not a second physics or performance run.
var checks:=0
var failures:Array[String]=[]
var cases:Array[Dictionary]=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);push_error(label)
func scale_ok(value:Vector3,city_scale:Vector3=Vector3.ONE)->bool:
    var body:=Node3D.new();body.scale=value
    var city:=Node3D.new();city.scale=city_scale
    var game:={"city":city}
    var scaled:=[]
    var maximum_scale_error:=0.0
    var scale_error:float=body.scale.distance_to(Vector3.ONE)
    maximum_scale_error=maxf(maximum_scale_error,scale_error)
    if scale_error>0.000001:scaled.append(str(body.name))
    var accepted:bool=scaled.is_empty() and game.city.scale==Vector3.ONE
    body.free();city.free()
    return accepted
func budget_ok(total:int,train_count:int,cache_count:int=40)->bool:
    var foods:=[];foods.resize(total)
    var cache:=[];cache.resize(cache_count)
    var game:={"city":{"foods":foods,"mesh_cache":cache}}
    return (game.city.foods.size()-train_count==2922 and game.city.mesh_cache.size()<=40) and (train_count==8 and game.city.foods.size()==2930)
func _initialize()->void:
    if not OS.get_cmdline_user_args().has("--test"):quit(2);return
    check(scale_ok(Vector3.ONE),"Exact unit body accepted")
    check(scale_ok(Vector3(.999999940395355,1,.999999940395355)),"Observed float32 rotation decomposition accepted")
    for scale in [Vector3(1.00001,1,1),Vector3(1,1.00001,1),Vector3(1,1,1.00001),Vector3(.99999,1,1)]:
        check(not scale_ok(scale),"Actual non-unit scale rejected: "+str(scale))
    check(not scale_ok(Vector3.ONE,Vector3(.99999994,1,1)),"Map-root scale still exact, without tolerance")
    check(budget_ok(2930,8),"Exact original 2922 plus eight trains accepted")
    for fixture in [[2931,8,40],[2929,8,40],[2931,9,40],[2929,7,40],[2930,9,40],[2930,7,40],[2930,8,41]]:
        var accepted:=budget_ok(fixture[0],fixture[1],fixture[2])
        cases.append({"total":fixture[0],"trains":fixture[1],"mesh_cache":fixture[2],"accepted":accepted})
        check(not accepted,"Extra/missing ordinary food, extra/missing train or oversized shared cache rejected: "+str(fixture))
    print("FIXTURE_MAINTENANCE_COUNTEREXAMPLES "+JSON.stringify({"checks":checks,"failures":failures,"cases":cases}))
    quit(0 if failures.is_empty() else 1)
