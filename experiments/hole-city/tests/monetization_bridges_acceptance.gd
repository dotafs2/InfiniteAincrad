extends SceneTree
const Ads=preload("res://fidelity/ads_bridge.gd")
const Commerce=preload("res://fidelity/commerce_bridge.gd")
const SMALL:="sink_city.coins_320"
const LARGE:="sink_city.coins_9600"
const DIAMOND_SMALL:="sink_city.diamonds_60"
const DIAMOND_ENTRY:="sink_city.diamonds_100"
const DIAMOND_MID:="sink_city.diamonds_360"
const DIAMOND_LARGE:="sink_city.diamonds_1800"
var checks:=0
var failures:Array[String]=[]
var earned:Array=[]
var closed:Array=[]
var ad_failures:Array=[]
var receipts:Array=[]
var store_failures:Array=[]
var pending:Array=[]

class AdProvider extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var version:=1
	var ready:=true
	var accepted:=true
	var sync_events:Array=[]
	var init_calls:=0
	var show_calls:Array=[]
	var retry_calls:=0
	func sink_city_rewarded_protocol_version()->int:return version
	func initialize()->void:init_calls+=1
	func rewarded_available()->bool:return ready
	func retry_rewarded()->void:retry_calls+=1;ready=true
	func show_rewarded(request_id:String)->bool:
		show_calls.append(request_id)
		for event in sync_events:
			if event=="earned":rewarded_earned.emit(request_id)
			elif event=="closed":rewarded_closed.emit(request_id)
			else:rewarded_failed.emit(request_id,"provider failure")
		return accepted

class OldAds extends RefCounted:
	signal rewarded_earned
	signal rewarded_closed
	func initialize()->void:pass
	func show_rewarded()->bool:return true

class BadSignatureAds extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return true
	func show_rewarded()->bool:return true

class StoreProvider extends RefCounted:
	signal products_received(products:Array)
	signal purchase_verified(transaction_id:String,product_id:String,request_id:String)
	signal purchase_failed(request_id:String,message:String)
	signal purchase_pending(request_id:String)
	signal availability_changed
	var version:=1
	var ready:=true
	var accepted:=true
	var ack_ok:=true
	var init_calls:=0
	var requested:PackedStringArray=[]
	var purchase_calls:Array=[]
	var ack_calls:Array=[]
	var sync_events:Array=[]
	func sink_city_commerce_protocol_version()->int:return version
	func initialize()->void:init_calls+=1
	func purchases_available()->bool:return ready
	func request_products(ids:PackedStringArray)->void:requested=ids
	func purchase(product_id:String,request_id:String)->bool:
		purchase_calls.append([product_id,request_id])
		for event in sync_events:
			if event=="verified":purchase_verified.emit("sync-"+request_id,product_id,request_id)
			elif event=="pending":purchase_pending.emit(request_id)
			else:purchase_failed.emit(request_id,"provider failure")
		return accepted
	func acknowledge(transaction_id:String)->bool:
		ack_calls.append(transaction_id);return ack_ok

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func watch_ads(ads:Node)->void:
	ads.rewarded_completed.connect(func(id:String):earned.append(id))
	ads.rewarded_closed.connect(func(id:String):closed.append(id))
	ads.rewarded_failed.connect(func(id:String,message:String):ad_failures.append([id,message]))
func watch_store(store:Node)->void:
	store.verified_purchase.connect(func(tx:String,product:String):receipts.append([tx,product]))
	store.purchase_failed.connect(func(id:String,message:String):store_failures.append([id,message]))
	store.purchase_pending.connect(func(id:String):pending.append(id))
func products(provider:StoreProvider)->void:
	provider.products_received.emit([{"product_id":SMALL,"localized_price":"₩1,100"},{"product_id":"sink_city.coins_2000","localized_price":"$4.99"},{"product_id":LARGE,"localized_price":"€19,99"},{"product_id":DIAMOND_SMALL,"localized_price":"₩1,100","diamonds":99999},{"product_id":DIAMOND_MID,"localized_price":"$4.99"},{"product_id":DIAMOND_LARGE,"localized_price":"€19,99"}])

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var offline:=Ads.new();root.add_child(offline);watch_ads(offline);offline.initialize();offline.initialize()
	check(offline.initialized and not offline.native_available,"Absent ad SDK is initialized but unavailable")
	check(not offline.validated_reward_available() and not offline.show_rewarded("offline"),"Absent SDK never pretends an ad started")
	check(earned.is_empty() and closed.is_empty() and ad_failures.size()==1,"Unavailable ad has no earned or close callback")
	check(not offline.unavailability_reason().is_empty(),"Unavailable ads provide a truthful reason")
	check(not offline.bind_test_native(AdProvider.new()),"Initialized bridge cannot swap its provider")
	offline.free()
	var bad:=Ads.new();root.add_child(bad)
	check(not bad.bind_test_native(OldAds.new()),"Unversioned no-ID legacy ad plugin is rejected")
	check(not bad.bind_test_native(BadSignatureAds.new()),"Version alone does not accept incompatible method arguments")
	var wrong:=AdProvider.new();wrong.version=2
	check(not bad.bind_test_native(wrong),"Unknown native protocol version is rejected")
	bad.free()
	var ads:=Ads.new();root.add_child(ads);watch_ads(ads);var native:=AdProvider.new()
	check(ads.bind_test_native(native),"Typed protocol-compatible ad provider can be injected only in test mode")
	check(not ads.validated_reward_available(),"Uninitialized native adapter cannot show an ad")
	ads.initialize();ads.initialize()
	check(native.init_calls==1 and ads.validated_reward_available(),"Initialization is idempotent and ready state comes from SDK")
	for id in [""," "," padded","x".repeat(161)]:check(not ads.show_rewarded(id),"Invalid rewarded request ID is rejected: "+str(id.length()))
	check(native.show_calls.is_empty(),"Invalid IDs never reach the native adapter")
	check(ads.show_rewarded("round-a"),"Valid opt-in request starts one native ad")
	check(native.show_calls==["round-a"] and ads.reward_in_flight,"Request identity reaches native unchanged")
	check(not ads.show_rewarded("round-b") and not ads.validated_reward_available(),"Concurrent ad request cannot replace the active round")
	native.rewarded_earned.emit("unknown");native.rewarded_closed.emit("unknown")
	check(earned.is_empty() and closed.is_empty() and ads.reward_in_flight,"Unknown callbacks cannot complete or close a real request")
	native.rewarded_closed.emit("round-a")
	check(closed==["round-a"] and earned.is_empty() and not ads.reward_in_flight,"Close alone never earns coins")
	check(ads.show_rewarded("round-b"),"Next ad can start after closing the previous one")
	native.rewarded_earned.emit("round-a")
	check(earned==["round-a"] and ads.reward_in_flight,"Late mediated earned callback retains original round and does not clear newer ad")
	native.rewarded_earned.emit("round-a");native.rewarded_closed.emit("round-a")
	check(earned.size()==1 and closed.size()==1,"Duplicate earned and closed callbacks are individually idempotent")
	native.rewarded_earned.emit("round-b")
	check(earned==["round-a","round-b"] and ads.reward_in_flight,"Earning does not pretend the visible ad has closed")
	native.rewarded_failed.emit("round-b","late failure")
	check(earned.size()==2 and ads.reward_in_flight,"Late failure cannot revoke a validated earned callback")
	native.rewarded_closed.emit("round-b")
	check(not ads.reward_in_flight and closed.size()==2,"Actual close releases the active presentation")
	check(not ads.show_rewarded("round-a"),"Used request IDs cannot create a second ad reward")
	native.ready=false
	check(not ads.validated_reward_available() and not ads.show_rewarded("not-ready"),"SDK load or consent unavailability blocks presentation")
	check(ads.retry_rewarded() and native.retry_calls==1 and ads.validated_reward_available(),"A native retry clears a stale unavailable state immediately")
	native.ready=true;native.accepted=false;native.sync_events=["earned","closed"]
	check(not ads.show_rewarded("rejected"),"Native rejected request returns false")
	check(earned.size()==2 and closed.size()==2 and not ads.reward_in_flight,"Synchronous callbacks from a rejected invocation cannot award")
	native.accepted=true;native.sync_events=["closed","earned","earned"]
	check(ads.show_rewarded("sync"),"Accepted synchronous native completion is supported")
	check(earned.back()=="sync" and earned.size()==3 and closed.back()=="sync" and not ads.reward_in_flight,"Synchronous close-before-earned remains valid and duplicate-safe")
	native.sync_events=[]
	check(ads.show_rewarded("failed"),"Failure fixture starts a valid request")
	native.rewarded_failed.emit("failed","network unavailable");native.rewarded_earned.emit("failed")
	check(earned.size()==3 and not ads.reward_in_flight,"Explicit provider failure cannot later fabricate earned state")
	ads.free()

	var absent:=Commerce.new();root.add_child(absent);watch_store(absent);absent.initialize()
	check(not absent.native_available and not absent.purchase_available(SMALL),"Missing purchase SDK is unavailable")
	check(absent.product_info(SMALL).is_empty(),"No fabricated localized price exists without store metadata")
	check(not absent.purchase(SMALL,"offline-store") and receipts.is_empty(),"Missing SDK never grants a purchase receipt")
	check(not absent.acknowledge("unknown") and not absent.unavailability_reason().is_empty(),"Unknown transaction cannot be acknowledged")
	absent._on_purchase_verified("fake-tx",SMALL,"")
	check(receipts.is_empty(),"An absent adapter cannot produce a verified callback")
	check(absent.product_info(DIAMOND_SMALL).is_empty() and not absent.purchase_available(DIAMOND_SMALL),"Diamond packs have no fabricated prices or readiness without StoreKit")
	absent.free()
	for product_id in Commerce.LEGACY_COIN_PRODUCTS:
		check(Commerce.product_currency(product_id)=="coins" and Commerce.product_amount(product_id)==Commerce.LEGACY_COIN_PRODUCTS[product_id],"Legacy coin receipt keeps its exact currency and amount: "+product_id)
	for product_id in Commerce.DIAMOND_PRODUCTS:
		check(Commerce.product_currency(product_id)=="gems" and Commerce.product_amount(product_id)==Commerce.DIAMOND_PRODUCTS[product_id],"Diamond receipt resolves the fixed gem wallet amount: "+product_id)
	for product_id in ["","unknown","sink_city.diamonds_999","sink_city.Diamonds_60","sink_city.diamonds_60 "]:
		check(Commerce.product_currency(product_id).is_empty() and Commerce.product_amount(product_id)==0,"Unknown product has no reward currency or amount: "+product_id)
	var store:=Commerce.new();root.add_child(store);watch_store(store);var provider:=StoreProvider.new()
	provider.version=4;check(not store.bind_test_native(provider),"Unsupported commerce protocol is rejected")
	provider.version=1;check(store.bind_test_native(provider),"Correct commerce adapter contract binds")
	store.initialize();store.initialize()
	check(provider.init_calls==1 and provider.requested.size()==7,"Four diamond quantities and three legacy coin IDs are requested once")
	check(provider.requested.has(SMALL) and provider.requested.has(LARGE) and provider.requested.has("sink_city.coins_2000") and provider.requested.has(DIAMOND_SMALL) and provider.requested.has(DIAMOND_MID) and provider.requested.has(DIAMOND_LARGE) and provider.requested.has(DIAMOND_ENTRY),"The new entry pack and exact legacy quantities are queried together")
	check(not store.purchase_available(SMALL),"No purchase before localized store products arrive")
	provider.products_received.emit([{},null,{"product_id":"alien","localized_price":"$1"},{"product_id":SMALL,"localized_price":""},{"product_id":LARGE,"localized_price":19.99}])
	check(store.product_info(SMALL).is_empty() and store.product_info(LARGE).is_empty(),"Malformed metadata cannot fabricate prices or purchasability")
	products(provider)
	check(store.product_info(SMALL)=={"product_id":SMALL,"coins":320,"localized_price":"₩1,100"},"SDK localized price is preserved exactly and coin amount comes from fixed catalog")
	check(store.product_info(LARGE).localized_price=="€19,99","Localized currency formatting is not reconstructed")
	check(store.product_info(DIAMOND_SMALL)=={"product_id":DIAMOND_SMALL,"currency":"gems","diamonds":60,"gems":60,"localized_price":"₩1,100"},"Diamond amount comes from allowlist even when provider supplies a forged amount")
	check(not store.purchase_available(DIAMOND_ENTRY) and store.product_info(DIAMOND_ENTRY).is_empty(),"A new catalog ID stays unavailable until actual StoreKit metadata arrives")
	provider.products_received.emit([{"product_id":DIAMOND_ENTRY,"localized_price":"$1.99","diamonds":60}])
	check(store.product_info(DIAMOND_ENTRY)=={"product_id":DIAMOND_ENTRY,"currency":"gems","diamonds":100,"gems":100,"localized_price":"$1.99"} and store.purchase_available(DIAMOND_ENTRY),"Explicit test metadata preserves its supplied price while the new ID credits100; legacy60 is never redefined")
	products(provider)
	check(store.product_info(DIAMOND_MID).diamonds==360 and store.product_info(DIAMOND_LARGE).diamonds==1800 and store.product_info(DIAMOND_LARGE).localized_price=="€19,99","Every diamond tier preserves its amount and the real localized store price")
	var copied:Dictionary=store.product_info(SMALL);copied.localized_price="fake"
	check(store.product_info(SMALL).localized_price=="₩1,100","Caller cannot mutate verified product metadata")
	provider.products_received.emit([{"product_id":SMALL,"localized_price":"$1"},{"product_id":SMALL,"localized_price":"$2"}])
	check(store.product_info(SMALL).is_empty(),"Conflicting duplicate product metadata is rejected")
	products(provider)
	for id in [""," padded","x".repeat(257)]:check(not store.purchase(SMALL,id),"Invalid purchase request ID is rejected")
	check(not store.purchase("unknown","bad-product") and provider.purchase_calls.is_empty(),"Unknown product cannot reach the store")
	check(store.purchase(SMALL,"buy-a"),"SDK-approved purchase request starts")
	check(provider.purchase_calls==[[SMALL,"buy-a"]],"Product and request ID are passed unchanged")
	check(not store.purchase(LARGE,"buy-b") and not store.purchase_available(LARGE),"One active purchase presentation at a time")
	provider.purchase_failed.emit("unknown","unexpected");provider.purchase_pending.emit("unknown")
	check(not store.purchase_available(LARGE) and pending.is_empty(),"Unknown request callbacks do not unlock active purchase state")
	provider.purchase_pending.emit("buy-a");provider.purchase_pending.emit("buy-a")
	check(pending==["buy-a"] and receipts.is_empty() and store.purchase_available(LARGE),"Pending parental approval releases UI without coins and is deduplicated")
	check(store.purchase(SMALL,"buy-same"),"Same product can be requested while the old approval is pending")
	provider.purchase_verified.emit("approved-old",SMALL,"buy-a")
	check(not store.purchase_available(SMALL) and store.active_request_id()=="buy-same" and receipts.back()==["approved-old",SMALL],"Old same-product approval cannot close the newer purchase presentation")
	provider.purchase_failed.emit("buy-same","cancelled")
	check(store.purchase_available(LARGE) and store.active_request_id().is_empty(),"Cancellation releases only its actual request")
	receipts.clear()
	check(store.purchase(LARGE,"buy-b"),"Another product may be purchased while approval is pending")
	provider.purchase_verified.emit("tx-a",SMALL,"")
	check(receipts==[["tx-a",SMALL]] and not store.purchase_available(LARGE),"Delayed approval is verified without disturbing a different active product")
	provider.purchase_verified.emit("tx-a",SMALL,"")
	check(receipts.size()==2 and provider.ack_calls.is_empty(),"Unacknowledged verified receipt redelivers for wallet save retry")
	provider.purchase_verified.emit("tx-a",LARGE,"")
	check(receipts.size()==2,"Conflicting product for an existing transaction never grants")
	provider.ack_ok=false
	check(not store.acknowledge("tx-a"),"Failed native acknowledgement remains retryable")
	provider.purchase_verified.emit("tx-a",SMALL,"")
	check(receipts.size()==3,"Receipt redelivery continues after acknowledgement failure")
	provider.ack_ok=true
	check(store.acknowledge("tx-a") and store.acknowledge("tx-a") and provider.ack_calls==["tx-a","tx-a"],"Successful acknowledgement is idempotent after wallet persistence")
	provider.purchase_verified.emit("tx-a",SMALL,"")
	check(receipts.size()==3,"Acknowledged transaction does not repeatedly grant in one bridge lifetime")
	provider.purchase_verified.emit("tx-b",LARGE,"buy-b")
	check(receipts.back()==["tx-b",LARGE] and store.purchase_available(SMALL),"Verified current purchase releases its presentation")
	check(store.active_request_id().is_empty(),"Verified matching request clears the externally visible active ID")
	provider.purchase_failed.emit("buy-b","late failure")
	check(receipts.size()==4,"Late failure cannot undo verified receipt")
	provider.purchase_verified.emit("restore-tx",SMALL,"")
	check(receipts.back()==["restore-tx",SMALL],"Verified unfinished transaction can arrive without a request after restart")
	for tx in [""," spaced","x".repeat(257)]:provider.purchase_verified.emit(tx,SMALL,"")
	provider.purchase_verified.emit("alien-tx","alien","")
	check(receipts.size()==5,"Invalid transaction IDs and unknown products are rejected")
	check(not store.acknowledge("not-seen"),"Wallet cannot acknowledge a transaction never verified by adapter")
	provider.accepted=false;provider.sync_events=["verified","pending","failed"]
	check(not store.purchase(SMALL,"rejected-store"),"Native purchase rejection returns false")
	check(receipts.size()==5 and pending.size()==1 and store.purchase_available(SMALL),"Rejected synchronous provider invocation cannot manufacture receipts or pending state")
	provider.accepted=true;provider.sync_events=["verified"]
	check(store.purchase(SMALL,"sync-store"),"Accepted synchronous store verification is handled")
	check(receipts.back()==["sync-sync-store",SMALL] and store.purchase_available(SMALL),"Synchronous verified receipt retains transaction and product identity")
	check(not store.purchase(SMALL,"sync-store"),"Duplicate purchase request ID never starts another payment")
	provider.sync_events=[]
	check(store.purchase(SMALL,"mismatch"),"Receipt mismatch fixture starts an accepted request")
	provider.purchase_verified.emit("mismatched-tx",LARGE,"mismatch")
	check(receipts.size()==6 and store.active_request_id()=="mismatch" and not store.acknowledge("mismatched-tx"),"Mismatched request product neither grants, stores nor closes the pending request")
	provider.purchase_failed.emit("mismatch","cancelled")
	provider.ready=false
	check(not store.purchase_available(SMALL) and not store.purchase(SMALL,"store-unready"),"Store readiness is required on every purchase")
	provider.ready=true
	check(store.purchase(SMALL,"observer-race"),"Observer race starts an accepted purchase")
	provider.purchase_verified.emit("observer-race-tx",SMALL,"")
	check(store.acknowledge("observer-race-tx") and store.active_request_id()=="observer-race","Verified observer can persist a receipt before the purchase result")
	var receipt_count:=receipts.size()
	provider.purchase_verified.emit("observer-race-tx",SMALL,"observer-race")
	check(receipts.size()==receipt_count and store.active_request_id().is_empty() and store.purchase_available(SMALL),"Acknowledged observer receipt still closes its matching purchase without a second grant")
	store.free()

	# A fresh bridge models the new diamond storefront without depending on the
	# legacy purchase fixtures above. It still accepts unfinished coin receipts.
	receipts.clear();store_failures.clear();pending.clear()
	var diamond_store:=Commerce.new();root.add_child(diamond_store);watch_store(diamond_store)
	var diamond_provider:=StoreProvider.new()
	check(diamond_store.bind_test_native(diamond_provider),"Diamond storefront binds the same verified commerce protocol")
	diamond_store.initialize();products(diamond_provider)
	check(diamond_store.purchase(DIAMOND_SMALL,"diamond-a"),"A diamond request reaches the native store with its own product identity")
	check(diamond_provider.purchase_calls==[[DIAMOND_SMALL,"diamond-a"]],"Diamond purchase does not substitute a coin product")
	diamond_provider.purchase_verified.emit("cross-currency",SMALL,"diamond-a")
	check(receipts.is_empty() and diamond_store.active_request_id()=="diamond-a" and not diamond_store.acknowledge("cross-currency"),"A verified coin receipt mismatched to a diamond request never grants or finishes")
	diamond_provider.purchase_verified.emit("diamond-tx",DIAMOND_SMALL,"diamond-a")
	check(receipts==[["diamond-tx",DIAMOND_SMALL]] and diamond_store.active_request_id().is_empty(),"Matching diamond verification emits one wallet credit identity")
	diamond_provider.purchase_verified.emit("diamond-tx",DIAMOND_SMALL,"")
	check(receipts.size()==2 and diamond_provider.ack_calls.is_empty(),"Diamond receipt redelivers until the wallet has persisted it")
	diamond_provider.purchase_verified.emit("diamond-tx",LARGE,"")
	check(receipts.size()==2,"A known diamond transaction cannot change into a legacy coin reward")
	check(diamond_store.acknowledge("diamond-tx") and diamond_provider.ack_calls==["diamond-tx"],"Diamond receipt finishes only after explicit wallet acknowledgement")
	diamond_provider.purchase_verified.emit("diamond-tx",DIAMOND_SMALL,"")
	check(receipts.size()==2,"Acknowledged diamond replay does not produce another wallet grant")
	diamond_provider.purchase_verified.emit("legacy-after-diamond",LARGE,"")
	check(receipts.back()==["legacy-after-diamond",LARGE] and Commerce.product_currency(receipts.back()[1])=="coins", "New diamond storefront still honors an unfinished legacy coin transaction")
	check(diamond_store.acknowledge("legacy-after-diamond"),"Legacy transaction can still finish after durable coin-wallet persistence")
	diamond_provider.accepted=false;diamond_provider.sync_events=["verified"]
	check(not diamond_store.purchase(DIAMOND_MID,"diamond-rejected") and receipts.size()==3,"Rejected diamond native invocation cannot fabricate a verified reward")
	diamond_provider.accepted=true;diamond_provider.sync_events=[]
	check(diamond_store.purchase(DIAMOND_LARGE,"diamond-cancelled"),"Largest diamond tier can start a store request")
	diamond_provider.purchase_failed.emit("diamond-cancelled","cancelled")
	check(receipts.size()==3 and diamond_store.active_request_id().is_empty(),"Cancelled diamond purchase releases UI without any wallet reward")
	diamond_provider.products_received.emit([{"product_id":DIAMOND_SMALL,"localized_price":"$0.99"},{"product_id":DIAMOND_SMALL,"localized_price":"$9.99"},{"product_id":DIAMOND_MID,"localized_price":""},{"product_id":DIAMOND_LARGE,"localized_price":19.99}])
	check(diamond_store.product_info(DIAMOND_SMALL).is_empty() and diamond_store.product_info(DIAMOND_MID).is_empty() and diamond_store.product_info(DIAMOND_LARGE).is_empty(),"Conflicting or malformed diamond metadata cannot invent a usable price")
	diamond_store.free()
	await process_frame
	print("MONETIZATION_BRIDGES_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"native_sdk_installed":false,"scope":"Deterministic protocol boundary tests with explicit --test providers; no real ad, payment or network transaction."}))
	quit(0 if failures.is_empty() else 1)
