extends Resource
## Offline hulls of the imported model's connected geometry islands.
## They preserve empty space beside posts, under signs and between rack bars.
@export var shapes:Array[Shape3D]=[]
@export var rim_samples:PackedVector3Array=PackedVector3Array()
@export var support_anchor:=Vector3.ZERO
@export var support_radius:=0.0
@export var source_asset:String=""
@export var source_sha256:String=""
