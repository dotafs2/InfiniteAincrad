extends Node
class_name AdsBridge

## Small platform boundary for the iOS AdMob implementation.
##
## Desktop, Web and exports without the native plugin deliberately behave as
## "ads unavailable". The game therefore remains playable and tests never
## need a network, an account, or a live ad request. The eventual iOS plugin
## exposes the singleton named GoogleMobileAds and the methods/signals listed
## below; its SDK and identifiers stay outside this repository.
signal rewarded_completed
signal rewarded_closed

const PLUGIN_NAME:="GoogleMobileAds"
const IOS_TEST_REWARDED_UNIT:="ca-app-pub-3940256099942544/1712485313"

var native:Object
var native_available:=false
var initialized:=false
var reward_in_flight:=false

func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		native=Engine.get_singleton(PLUGIN_NAME)
		native_available=native!=null
		if native.has_signal("rewarded_earned"):
			native.connect("rewarded_earned", _on_rewarded_earned)
		if native.has_signal("rewarded_closed"):
			native.connect("rewarded_closed", _on_rewarded_closed)

func initialize() -> void:
	if initialized:return
	initialized=true
	if not native_available:return
	# The plugin performs UMP requestConsentInfoUpdate/loadAndPresentIfRequired
	# before Mobile Ads start, then only requests ads when canRequestAds is true.
	if native.has_method("initialize"):
		native.call("initialize")

func show_rewarded() -> bool:
	if not native_available or not native.has_method("show_rewarded"):
		return false
	if reward_in_flight:return false
	reward_in_flight=true
	var result=native.call("show_rewarded")
	if result is bool and not result:
		reward_in_flight=false
		return false
	return true

func _on_rewarded_earned() -> void:
	if not reward_in_flight:return
	reward_in_flight=false
	rewarded_completed.emit()

func _on_rewarded_closed() -> void:
	if reward_in_flight:reward_in_flight=false
	rewarded_closed.emit()
