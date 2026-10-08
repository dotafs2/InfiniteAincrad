extends Node
class_name AdsBridge

## Versioned boundary, not an installed advertising SDK. The native adapter
## must handle consent, loading and ID propagation before reporting available.
## No Web/desktop fallback ever invents an earned reward.
signal rewarded_completed(request_id:String)
signal rewarded_closed(request_id:String)
signal rewarded_failed(request_id:String,message:String)
signal availability_changed

const PLUGIN_NAME:="GoogleMobileAds"
const IOS_TEST_REWARDED_UNIT:="ca-app-pub-3940256099942544/1712485313"
const PROTOCOL_VERSION:=1
var native:Object
var native_available:=false
var initialized:=false
var reward_in_flight:=false
var _active_id:=""
var _requests:Dictionary={}
var _dispatching:=false
var _events:Array=[]

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web") and Engine.has_singleton(PLUGIN_NAME):_bind(Engine.get_singleton(PLUGIN_NAME))

func _process(_delta:float)->void:
	if initialized and native_available and is_instance_valid(native) and native.has_method("poll_events"):
		native.call("poll_events")

func privacy_options_required()->bool:
	if not initialized or not native_available or not is_instance_valid(native) or not native.has_method("privacy_options_required"):return false
	return native.call("privacy_options_required")==true

func show_privacy_options()->bool:
	if not privacy_options_required() or reward_in_flight or not native.has_method("show_privacy_options"):return false
	return native.call("show_privacy_options")==true

func bind_test_native(provider:Object)->bool:
	# Explicit test injection never discovers a fake SDK in a shipped game.
	if not OS.get_cmdline_user_args().has("--test") or initialized:return false
	return _bind(provider)

func _typed_signal(provider:Object,name:String,types:Array)->bool:
	for entry in provider.get_signal_list():
		if entry.name!=name:continue
		var args:Array=entry.args
		if args.size()!=types.size():return false
		for index in types.size():
			if int(args[index].type)!=int(types[index]):return false
		return true
	return false

func _typed_method(provider:Object,name:String,types:Array,result_type:int)->bool:
	for entry in provider.get_method_list():
		if entry.name!=name:continue
		var args:Array=entry.args
		if args.size()!=types.size() or int(entry["return"].type)!=result_type:return false
		for index in types.size():
			if int(args[index].type)!=int(types[index]):return false
		return true
	return false

func _bind(provider:Object)->bool:
	if native_available or not is_instance_valid(provider):return false
	if not _typed_method(provider,"sink_city_rewarded_protocol_version",[],TYPE_INT):return false
	if not _typed_method(provider,"initialize",[],TYPE_NIL):return false
	if not _typed_method(provider,"rewarded_available",[],TYPE_BOOL):return false
	if not _typed_method(provider,"show_rewarded",[TYPE_STRING],TYPE_BOOL):return false
	var version:Variant=provider.call("sink_city_rewarded_protocol_version")
	if not version is int or version!=PROTOCOL_VERSION:return false
	if not _typed_signal(provider,"rewarded_earned",[TYPE_STRING]) or not _typed_signal(provider,"rewarded_closed",[TYPE_STRING]) or not _typed_signal(provider,"rewarded_failed",[TYPE_STRING,TYPE_STRING]) or not _typed_signal(provider,"availability_changed",[]):return false
	native=provider;native_available=true
	native.connect("rewarded_earned",_on_rewarded_earned)
	native.connect("rewarded_closed",_on_rewarded_closed)
	native.connect("rewarded_failed",_on_rewarded_failed)
	native.connect("availability_changed",_on_availability_changed)
	return true

func initialize()->void:
	if initialized:return
	initialized=true
	if native_available and is_instance_valid(native):native.call("initialize")
	availability_changed.emit()

func validated_reward_available()->bool:
	if not initialized or not native_available or not is_instance_valid(native) or reward_in_flight:return false
	var ready:Variant=native.call("rewarded_available")
	return ready is bool and ready

func retry_rewarded()->bool:
	# A native provider can be retried after the player changes network/VPN
	# without waiting for the adapter's bounded background backoff. Desktop and
	# test providers without this optional method remain unavailable.
	if not native_available or not is_instance_valid(native) or not native.has_method("retry_rewarded"):return false
	native.call("retry_rewarded")
	return true

func unavailability_reason()->String:
	if not native_available or not is_instance_valid(native):return "Rewarded ads are not available on this platform yet."
	if reward_in_flight:return "An ad is already open."
	return "No rewarded ad is ready. Please try again later."

func show_rewarded(request_id:String="")->bool:
	if request_id.is_empty() or request_id!=request_id.strip_edges() or request_id.length()>160 or _requests.has(request_id):return false
	if not validated_reward_available():
		rewarded_failed.emit(request_id,unavailability_reason());return false
	_requests[request_id]={"accepted":false,"earned":false,"closed":false,"failed":false}
	_active_id=request_id;reward_in_flight=true;_dispatching=true
	var result:Variant=native.call("show_rewarded",request_id)
	_dispatching=false
	var accepted:bool=result is bool and result
	_requests[request_id].accepted=accepted
	if not accepted:
		_requests[request_id].failed=true;_clear_active(request_id)
	var pending:=_events;_events=[]
	for event in pending:_deliver(event)
	if not accepted:rewarded_failed.emit(request_id,"The ad provider could not open this ad.")
	availability_changed.emit()
	return accepted

func _on_rewarded_earned(request_id:String)->void:_queue(["earned",request_id,""])
func _on_rewarded_closed(request_id:String)->void:_queue(["closed",request_id,""])
func _on_rewarded_failed(request_id:String,message:String)->void:_queue(["failed",request_id,message])
func _on_availability_changed()->void:availability_changed.emit()
func _queue(event:Array)->void:
	if _dispatching:_events.append(event)
	else:_deliver(event)
func _clear_active(request_id:String)->void:
	if _active_id!=request_id:return
	_active_id="";reward_in_flight=false
func _deliver(event:Array)->void:
	var request_id:String=event[1]
	if not _requests.has(request_id):return
	var state:Dictionary=_requests[request_id]
	if not state.accepted:return
	match event[0]:
		"earned":
			if state.earned or state.failed:return
			state.earned=true
			# Mediation may close before its earned callback. Keep this ID alive.
			rewarded_completed.emit(request_id)
		"closed":
			if state.closed:return
			state.closed=true;_clear_active(request_id)
			rewarded_closed.emit(request_id)
		"failed":
			if state.failed or state.earned:return
			state.failed=true;_clear_active(request_id)
			rewarded_failed.emit(request_id,event[2])
	availability_changed.emit()
