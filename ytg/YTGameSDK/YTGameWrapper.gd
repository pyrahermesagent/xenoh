# ==================================================
# Begin YouTube Playables integration section 
# ==================================================
extends Node

## This script provides a bridge to the YouTube Playables JS SDK for Godot games.
## It should be configured as an Autoload singleton in your project settings.
##
## It provides functions to interact with the SDK and signals for handling
## asynchronous events and callbacks from the YouTube environment.

# Signals for async operations and callbacks
signal audio_enabled_changed(is_enabled: bool)
signal game_paused
signal game_resumed
signal save_data_success
signal save_data_failed(error_message: String)
signal load_data_received(data: String)
signal ad_request_success
signal ad_request_failed(error_message: String)

const YT_GAME_SDK_JS_WINDOW_OBJECT = "window.YTGameSDK_Godot"

func _ready() -> void:
	# This script should be an Autoload/Singleton.
	if OS.has_feature("web"):
		# Create a global object for JS to hold callback functions
		JavaScriptBridge.eval("""
			window.GodotYTCallbacks = {
				onAudioEnabledChanged: (isEnabled) => {},
				onGamePaused: () => {},
				onGameResumed: () => {},
				onLoadDataReceived: (data) => {},
				onSaveSuccess: () => {},
				onSaveFailed: (error) => {},
				onAdSuccess: () => {},
				onAdFailed: (error) => {}
			};
		""")
		
		# Create Godot-side callbacks and assign them to the JS object
		var godot_callbacks = JavaScriptBridge.get_interface("GodotYTCallbacks")
		godot_callbacks.set("onAudioEnabledChanged", Callable(self, "_on_audio_enabled_changed"))
		godot_callbacks.set("onGamePaused", Callable(self, "_on_game_paused"))
		godot_callbacks.set("onGameResumed", Callable(self, "_on_game_resumed"))
		godot_callbacks.set("onLoadDataReceived", Callable(self, "_on_load_data_received"))
		godot_callbacks.set("onSaveSuccess", Callable(self, "_on_save_success"))
		godot_callbacks.set("onSaveFailed", Callable(self, "_on_save_failed"))
		godot_callbacks.set("onAdSuccess", Callable(self, "_on_ad_success"))
		godot_callbacks.set("onAdFailed", Callable(self, "_on_ad_failed"))
		
		# Tell the JS library to set up its own internal callbacks to YouTube
		var js_code = "%s.setAllCallbacks();" % YT_GAME_SDK_JS_WINDOW_OBJECT
		JavaScriptBridge.eval(js_code)

# --- Public API ---

## Returns the YouTube Playables SDK version string.
func get_sdk_version() -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("%s.getSDKVersion();" % YT_GAME_SDK_JS_WINDOW_OBJECT)
	return "N/A"

## Sends the player's score to YouTube.
func send_score(score: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.sendScore(%d);" % [YT_GAME_SDK_JS_WINDOW_OBJECT, score])

## Notifies YouTube that the game's first frame is ready to be shown.
## NOTE: The game MUST call this API. Otherwise, the game isn't shown on YouTube.
func first_frame_ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.firstFrameReady();" % YT_GAME_SDK_JS_WINDOW_OBJECT)

## Notifies YouTube that the game is ready for players to interact with.
func game_ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.gameReady();" % YT_GAME_SDK_JS_WINDOW_OBJECT)

## Saves game data to the YouTube cloud. Emits save_data_success or save_data_failed.
func save_data(data: String) -> void:
	if OS.has_feature("web"):
		print("save_data call")
		# May need to escape string before seding it >> something like data.javascript_escape() ??
		JavaScriptBridge.eval("%s.saveData('%s');" % [YT_GAME_SDK_JS_WINDOW_OBJECT, data])  

## Requests to load game data from the YouTube cloud. Emits load_data_received on success.
func load_data() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.loadData();" % YT_GAME_SDK_JS_WINDOW_OBJECT)

## Logs an error to YouTube for tracking in the developer dashboard.
func log_error(message: String) -> void:
	if OS.has_feature("web"):
		print("log_error call")
		JavaScriptBridge.eval("%s.logError('%s');" % [YT_GAME_SDK_JS_WINDOW_OBJECT, message])

## Logs a warning to YouTube for tracking in the developer dashboard.
func log_warning(message: String) -> void:
	if OS.has_feature("web"):
		print("log_warning call")
		JavaScriptBridge.eval("%s.logWarning('%s');" % [YT_GAME_SDK_JS_WINDOW_OBJECT, message])

## Returns whether the game audio is enabled in the YouTube settings.
func is_audio_enabled() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("%s.isAudioEnabled();" % YT_GAME_SDK_JS_WINDOW_OBJECT)
	return true

## Returns whether the game is currently loaded in a proper Playables Environment.
func in_playables_env() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("%s.inPlayablesEnv();" % YT_GAME_SDK_JS_WINDOW_OBJECT)
	return false

## Requests an Interstitial Ad. Emits ad_request_success or ad_request_failed.
func request_interstitial_ad() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.requestInterstitialAd();" % YT_GAME_SDK_JS_WINDOW_OBJECT)

# --- Callback Handlers (called from JavaScript) ---
func _on_audio_enabled_changed(is_enabled: bool) -> void:
	audio_enabled_changed.emit(is_enabled)

func _on_game_paused() -> void:
	game_paused.emit()

func _on_game_resumed() -> void:
	game_resumed.emit()

func _on_load_data_received(data: String) -> void:
	load_data_received.emit(data)

func _on_save_success() -> void:
	save_data_success.emit()

func _on_save_failed(error_message: String) -> void:
	save_data_failed.emit(error_message)

func _on_ad_success() -> void:
	ad_request_success.emit()

func _on_ad_failed(error_message: String) -> void:
	ad_request_failed.emit(error_message)
