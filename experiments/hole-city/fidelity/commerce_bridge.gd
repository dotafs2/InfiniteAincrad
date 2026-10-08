extends Node
class_name CommerceBridge

## Optional, verified native commerce boundary. No SDK or product-price data
## ships here. A protocol-compatible adapter must verify StoreKit/Play receipts.
## The wallet persists a transaction before calling acknowledge().
signal products_changed
signal verified_purchase(transaction_id:String,product_id:String)
signal purchase_failed(request_id:String,message:String)
signal purchase_pending(request_id:String)

const PLUGIN_NAME:="SinkCityCommerce"
const PROTOCOL_VERSION:=1
## Legacy coin receipts remain valid for unfinished transactions and old saves.
## New storefront purchases use diamonds; prices still come only from StoreKit.
const LEGACY_COIN_PRODUCTS:={"sink_city.coins_320":320,"sink_city.coins_2000":2000,"sink_city.coins_9600":9600}
const DIAMOND_PRODUCTS:={"sink_city.diamonds_60":60,"sink_city.diamonds_100":100,"sink_city.diamonds_360":360,"sink_city.diamonds_1800":1800}
const PRODUCTS:={"sink_city.coins_320":320,"sink_city.coins_2000":2000,"sink_city.coins_9600":9600,"sink_city.diamonds_60":60,"sink_city.diamonds_100":100,"sink_city.diamonds_360":360,"sink_city.diamonds_1800":1800}

static func product_currency(product_id:String)->String:
	if LEGACY_COIN_PRODUCTS.has(product_id):return "coins"
	if DIAMOND_PRODUCTS.has(product_id):return "gems"
	return ""
static func product_amount(product_id:String)->int:
	return int(PRODUCTS.get(product_id,0))
var native:Object
var native_available:=false
var initialized:=false
var _products:Dictionary={}
var _requests:Dictionary={}
var _active_id:=""
var _transactions:Dictionary={}
var _acknowledged:Dictionary={}
var _dispatching:=false
var _events:Array=[]

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web") and Engine.has_singleton(PLUGIN_NAME):_bind(Engine.get_singleton(PLUGIN_NAME))
func _process(_delta:float)->void:
	if initialized and native_available and is_instance_valid(native) and native.has_method("poll_events"):
		native.call("poll_events")
func bind_test_native(provider:Object)->bool:
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
	if not _typed_method(provider,"sink_city_commerce_protocol_version",[],TYPE_INT):return false
	if not _typed_method(provider,"initialize",[],TYPE_NIL):return false
	if not _typed_method(provider,"purchases_available",[],TYPE_BOOL):return false
	if not _typed_method(provider,"request_products",[TYPE_PACKED_STRING_ARRAY],TYPE_NIL):return false
	if not _typed_method(provider,"purchase",[TYPE_STRING,TYPE_STRING],TYPE_BOOL):return false
	if not _typed_method(provider,"acknowledge",[TYPE_STRING],TYPE_BOOL):return false
	var version:Variant=provider.call("sink_city_commerce_protocol_version")
	if not version is int or version!=PROTOCOL_VERSION:return false
	if not _typed_signal(provider,"products_received",[TYPE_ARRAY]) or not _typed_signal(provider,"purchase_verified",[TYPE_STRING,TYPE_STRING,TYPE_STRING]) or not _typed_signal(provider,"purchase_failed",[TYPE_STRING,TYPE_STRING]) or not _typed_signal(provider,"purchase_pending",[TYPE_STRING]) or not _typed_signal(provider,"availability_changed",[]):return false
	native=provider;native_available=true
	native.connect("products_received",_on_products_received)
	native.connect("purchase_verified",_on_purchase_verified)
	native.connect("purchase_failed",_on_purchase_failed)
	native.connect("purchase_pending",_on_purchase_pending)
	native.connect("availability_changed",_on_availability_changed)
	return true
func initialize()->void:
	if initialized:return
	initialized=true
	if native_available and is_instance_valid(native):
		native.call("initialize")
		native.call("request_products",PackedStringArray(PRODUCTS.keys()))
	products_changed.emit()
func active_request_id()->String:
	return _active_id
func product_info(product_id:String)->Dictionary:
	return _products.get(product_id,{}).duplicate(true)
func purchase_available(product_id:String)->bool:
	if not initialized or not native_available or not is_instance_valid(native) or not _active_id.is_empty() or not _products.has(product_id):return false
	var ready:Variant=native.call("purchases_available")
	return ready is bool and ready
func unavailability_reason()->String:
	if not native_available or not is_instance_valid(native):return "Purchases are not available on this platform yet."
	if not _active_id.is_empty():return "A purchase is already in progress."
	return "Store products are not available. Please try again later."
func purchase(product_id:String,request_id:String)->bool:
	if not _valid_id(request_id) or _requests.has(request_id):return false
	if not PRODUCTS.has(product_id) or not purchase_available(product_id):
		purchase_failed.emit(request_id,unavailability_reason());return false
	_requests[request_id]={"product_id":product_id,"accepted":false,"terminal":false,"pending":false}
	_active_id=request_id;_dispatching=true
	var result:Variant=native.call("purchase",product_id,request_id)
	_dispatching=false
	var accepted:bool=result is bool and result
	_requests[request_id].accepted=accepted
	if not accepted:_requests[request_id].terminal=true;_active_id=""
	var events:=_events;_events=[]
	for event in events:
		# A rejected synchronous invocation cannot manufacture a new receipt.
		if accepted or (event[0]=="verified" and _transactions.has(event[1])):_deliver(event)
	if not accepted:purchase_failed.emit(request_id,"The store could not start this purchase.")
	products_changed.emit()
	return accepted
func acknowledge(transaction_id:String)->bool:
	if _acknowledged.has(transaction_id):return true
	if not _transactions.has(transaction_id) or not native_available or not is_instance_valid(native):return false
	var result:Variant=native.call("acknowledge",transaction_id)
	if not result is bool or not result:return false
	_acknowledged[transaction_id]=true
	return true
func _valid_id(value:String)->bool:
	return not value.is_empty() and value==value.strip_edges() and value.length()<=256
func _on_products_received(products:Array)->void:
	var fresh:Dictionary={};var seen:Dictionary={}
	for value in products:
		if not value is Dictionary:continue
		var product_id:Variant=value.get("product_id")
		var price:Variant=value.get("localized_price")
		if not product_id is String or not PRODUCTS.has(product_id):continue
		if seen.has(product_id):fresh.erase(product_id);continue
		seen[product_id]=true
		if not price is String or price.strip_edges().is_empty() or price.length()>96:continue
		if product_currency(product_id)=="coins":
			# Preserve the old metadata shape for legacy callers and receipts.
			fresh[product_id]={"product_id":product_id,"coins":product_amount(product_id),"localized_price":price}
		else:
			fresh[product_id]={"product_id":product_id,"currency":"gems","diamonds":product_amount(product_id),"gems":product_amount(product_id),"localized_price":price}
	_products=fresh;products_changed.emit()
func _on_purchase_verified(transaction_id:String,product_id:String,request_id:String)->void:_queue(["verified",transaction_id,product_id,request_id])
func _on_purchase_failed(request_id:String,message:String)->void:_queue(["failed",request_id,message])
func _on_purchase_pending(request_id:String)->void:_queue(["pending",request_id,""])
func _on_availability_changed()->void:products_changed.emit()
func _queue(event:Array)->void:
	if not initialized or not native_available or not is_instance_valid(native):return
	if _dispatching:_events.append(event)
	else:_deliver(event)
func _deliver(event:Array)->void:
	var identity:String=event[1]
	if event[0]=="verified":
		var product_id:String=event[2]
		if not _valid_id(identity) or not PRODUCTS.has(product_id):return
		if _transactions.has(identity) and _transactions[identity]!=product_id:
			purchase_failed.emit("","The store returned conflicting transaction data.");return
		var request_id:String=event[3]
		if not request_id.is_empty() and _requests.has(request_id):
			var request:Dictionary=_requests[request_id]
			if not request.accepted or request.product_id!=product_id:
				purchase_failed.emit(request_id,"The store returned a mismatched purchase receipt.");return
			request.terminal=true
			if _active_id==request_id:_active_id=""
		# An unfinished observer can deliver before purchase() returns its
		# matching result. Complete that request even if the wallet already
		# acknowledged the observer event, without granting the receipt twice.
		if _acknowledged.has(identity):products_changed.emit();return
		_transactions[identity]=product_id
		# Redelivery remains possible until the wallet confirms durable storage.
		verified_purchase.emit(identity,product_id)
		products_changed.emit();return
	if not _requests.has(identity):return
	var state:Dictionary=_requests[identity]
	if not state.accepted or state.terminal:return
	if event[0]=="pending":
		if state.pending:return
		state.pending=true
		if _active_id==identity:_active_id=""
		purchase_pending.emit(identity)
	elif event[0]=="failed":
		state.terminal=true
		if _active_id==identity:_active_id=""
		purchase_failed.emit(identity,event[2])
	products_changed.emit()
