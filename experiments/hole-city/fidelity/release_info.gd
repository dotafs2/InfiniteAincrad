extends Control
## Local, permanently reachable release information. No network requests.
const SUPPORT_EMAIL:="chenxi.qu.work@gmail.com"
const OPERATOR:="Chenxi"
const PRIVACY_TEXT:="""Privacy policy
Effective October 2, 2026

Hole Feast is operated by Chenxi.
Contact: chenxi.qu.work@gmail.com

Local progress
Coins, diamonds, owned skins, selected maps and audio preferences are saved in the app's local storage. We do not receive these saves or operate an account or cloud-save service. Device backups are managed by your operating system.

This version
The game does not include account sign-in, advertising or analytics services, and does not transmit gameplay data to us. Real-money purchases are unavailable. The game does not request camera, microphone, photo-library or location access.

Optional reports and support
Testing reports are created locally only when testing mode is enabled. They are not automatically uploaded. If you email us, we receive your email address, message and any attachments you choose to send. We use them to respond to your request and retain them only as needed for support. You may ask us to delete your support correspondence.

Your choices
You can change Music, Sound and Haptics in Settings or the pause panel. Privacy and Support are available from Settings. Removing the app may remove its local progress. We cannot restore a save that we have never received. Contact us about privacy or support at the email above.

Platform services
Apple distributes the app and may process App Store and device diagnostic information under its own settings and privacy policy. Our support email is hosted by Google. Their services are governed by their respective policies.

Updates
If future versions add online services, advertising or purchases, this policy and the app's disclosures will be updated before those services are enabled."""
const SUPPORT_TEXT:="""Support

Developer: Chenxi
Email: chenxi.qu.work@gmail.com

For help, describe the issue and include your device model, iOS version, app version and the map you were playing. Screenshots are optional. Do not send passwords or verification codes.

Progress is stored locally. App removal may delete it; we do not operate a cloud-save service.

Three maps are playable: Sunny City, Snack Garden and Bubble Toy Town. Rival holes are controlled by the game. Earn one coin per ten points, rounded down, with no finish bonus. A skin draw costs 100 coins. Additional map cards are marked Coming Soon. Ads and real-money purchases are unavailable in this version."""
const NOTICE_FILES:=["LICENSE.txt","MBMAYER_LICENSE.txt","FREDOKA_OFL.txt","MUSIC_CREDITS.txt","GODOT_LICENSES.txt"]
var body:RichTextLabel
var tabs:Array[Button]=[]
var ads_bridge:Node
var privacy_choices:Button
const IOS_PRIVACY_TEXT:="""Privacy policy
Effective October 2, 2026

Hole Feast is operated by Chenxi.
Contact: chenxi.qu.work@gmail.com

Local progress
Coins, diamonds, owned skins, selected maps, audio preferences and redeemed transaction IDs are saved locally. We do not receive these saves or provide accounts or cloud saves. Operating-system backups are managed by Apple. Removing the app may remove this progress.

Rewarded advertising on iOS
The iOS app uses Google AdMob and Google's User Messaging Platform to provide optional rewarded videos and manage privacy choices. Google may process IP addresses and approximate location, device identifiers, ad interactions, app interactions and diagnostic/performance information for ad delivery, measurement, fraud prevention and service operation. We request non-personalized ads and disable Google's publisher first-party ID. The app does not request Apple's tracking authorization or provide your local wallet or skin collection to Google. Non-personalized ads still involve data processing.

We check Google's consent status before requesting ads. Where required, Google's privacy form is presented. When Google requires a privacy-choice entry, it is available below in this Privacy page. Optional rewarded videos can earn diamonds, grant one 1.5x round coin boost or grant one 30-second extension in the same run. The coin boost and extension are independent and available at most once per run. Coin boosts and extensions are applied after the ad confirms your reward and you close the video. Closing it without earning a reward gives no bonus. The ad provider determines video length.

Apple purchases on iOS
Apple handles optional diamond purchases. Diamonds can be exchanged for coins, spent on one 1.5x round coin boost for two diamonds or spent on one 30-second round extension for two diamonds. The boost and extension are independent. Fractional boosted coins are rounded down. The app receives Apple-verified product and transaction information to deliver the purchased currency and prevent duplicate grants. Unfinished verified purchases of earlier coin packs remain valid and credit coins. We do not receive payment-card details, your Apple account credentials or Apple's billing address. Diamond and legacy coin packs are consumable items. Completed purchases and spent currency are not a cloud backup and cannot be restored by us after local data is lost. Contact Apple about billing or refunds, and contact us about missing currency.

Optional reports and support
Testing reports are created locally only in testing mode and are not automatically uploaded. If you email us, we receive your email address, message and any attachments you choose to send. We use them for support and retain them only as needed. You may request deletion of support correspondence.

Your choices
You can play without buying diamonds or watching a rewarded video. Music, Sound and Haptics can be changed in Settings or the pause panel. Privacy and Support are available from Settings. This app does not request camera, microphone, photo-library or precise-location access. Google manages retention and privacy choices for data it processes; Apple manages its platform and payment data.

Provider policies
Google: https://policies.google.com/privacy
Google ads: https://policies.google.com/technologies/ads
Apple: https://www.apple.com/legal/privacy/

Web and desktop builds do not include the iOS advertising or payment SDKs. We update this policy and store disclosures when data practices change."""

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color("25356f",.88)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel:=PanelContainer.new()
	panel.position=Vector2(24,92);panel.size=Vector2(492,744)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("fffdf7");style.set_corner_radius_all(28)
	style.content_margin_left=20;style.content_margin_right=20
	style.content_margin_top=20;style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14)
	panel.add_child(column)
	var title:=Label.new();title.text="Hole Feast"
	title.add_theme_color_override("font_color",Color("263467"))
	title.add_theme_font_size_override("font_size",30)
	column.add_child(title)
	var version:=Label.new();version.text="Version "+str(ProjectSettings.get_setting("application/config/version"))
	version.add_theme_color_override("font_color",Color("3771ce"))
	version.add_theme_font_size_override("font_size",20)
	column.add_child(version)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8)
	column.add_child(row)
	for page in ["Privacy","Support","Credits"]:
		var tab:=Button.new();tab.text=page
		tab.custom_minimum_size=Vector2(0,64)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",22)
		tab.pressed.connect(show_page.bind(page))
		row.add_child(tab);tabs.append(tab)
	body=RichTextLabel.new();body.bbcode_enabled=false;body.selection_enabled=true
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.custom_minimum_size=Vector2(0,300)
	body.add_theme_color_override("default_color",Color("263467"))
	body.add_theme_font_size_override("normal_font_size",22)
	column.add_child(body)
	privacy_choices=Button.new();privacy_choices.text="AD PRIVACY CHOICES"
	privacy_choices.custom_minimum_size=Vector2(0,64)
	privacy_choices.add_theme_font_size_override("font_size",22)
	privacy_choices.pressed.connect(_open_ad_privacy)
	column.add_child(privacy_choices)
	if is_instance_valid(ads_bridge):ads_bridge.availability_changed.connect(_refresh_privacy_choices)
	var close:=Button.new();close.text="BACK TO GAME"
	close.custom_minimum_size=Vector2(0,64)
	close.add_theme_font_size_override("font_size",22)
	close.pressed.connect(queue_free)
	column.add_child(close)
	show_page("Privacy")

func show_page(page:String)->void:
	for tab in tabs:tab.disabled=tab.text==page
	if page=="Privacy":body.text=IOS_PRIVACY_TEXT if Engine.has_singleton("GoogleMobileAds") else PRIVACY_TEXT
	elif page=="Support":
		body.text=SUPPORT_TEXT.replace("Ads and real-money purchases are unavailable in this version.","iOS supports optional rewarded videos and Apple diamond purchases when the services are available. One 1.5x coin boost costs two diamonds or a completed rewarded video. One 30-second extension in the same run costs two diamonds or a completed rewarded video. These two choices are independent and each can be used once per run. Fractional boosted coins are rounded down. Diamonds can also convert to coins. Music, Sound, Haptics, Privacy and Support are available in Settings. Earlier verified coin purchases remain valid. Contact Apple about billing and refunds; email us about missing currency.") if Engine.has_singleton("SinkCityCommerce") else SUPPORT_TEXT
	else:
		var text:="Credits and licenses\n\nOriginal game additions: InfiniteAincrad contributors.\nDeveloper: Chenxi\nMusic: Shop Theme, Children's March and Through the Snow by Cleyton Kauffman; Hometown and Sunshine Coast by Juhani Junkala (CC0). Original Hole Feast case music and sounds. Full music credits below.\nFont: Fredoka (SIL OFL).\nEngine: Godot (MIT).\nTemplate: mbMayer (MIT).\n\n"
		for filename in NOTICE_FILES:
			text+="\n"+filename+"\n\n"+FileAccess.get_file_as_string("res://assets/legal/"+filename)+"\n"
		body.text=text
	body.scroll_to_line(0)
	_refresh_privacy_choices()

func _refresh_privacy_choices()->void:
	if not is_instance_valid(privacy_choices):return
	privacy_choices.visible=is_instance_valid(ads_bridge) and ads_bridge.privacy_options_required() and tabs[0].disabled

func _open_ad_privacy()->void:
	if is_instance_valid(ads_bridge):ads_bridge.show_privacy_options()
