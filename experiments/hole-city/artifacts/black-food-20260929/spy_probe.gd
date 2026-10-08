extends SceneTree
class Spy:
	extends MultiMesh
	var writes:Dictionary={}
	@warning_ignore("native_method_override")
	func set_instance_color(index:int,color:Color)->void:writes[index]=color
func _initialize()->void:
	var spy:=Spy.new();spy.use_colors=true;spy.instance_count=3
	var typed:MultiMesh=spy;typed.set_instance_color(1,Color.WHITE)
	print("COLOR_SPY ",spy.writes);quit(0 if spy.writes.has(1) else 1)
