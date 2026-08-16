# ==================================================
# YouTube Playables integration — Godot 4 bridge
# ==================================================
extends Node
## Bridges `window.YTGameSDK_Godot` (the official YTGameSDK.js object,
## https://developers.google.com/youtube/gaming/playables/samples/godot_wrapper)
## into this Node.
##
## Google's sample targets Godot 3 (`get_interface().set(...)`). Godot 4's
## JavaScriptBridge changed: a `create_callback()` result is a
## `JavaScriptObject` that does NOT serialize to JS source (str() ->
## "<JavaScriptObject#id>"), and `.set()` on it invokes a JS *method*, not a
## property write. So this Godot 4 port uses the bulletproof pattern:
##
##   * JS installs the official SDK's system listeners ONCE onto a pure-JS
##     `window.GodotYTCallbacks` object (set up in `_ready`). Those callbacks
##     only set plain `window.__XENOHT.*` flags — no Godot objects involved.
##   * GDScript polls those flags each frame (`_process`) via `eval` and
##     emits the public signals. Reading a window property is a trivial,
##     injection-free `eval`, so it always works in the web build.
##
## Public names/signals match the official wrapper, so game code is unchanged.

# Signals for async operations and callbacks
signal audio_enabled_changed(is_enabled: bool)
signal game_paused
signal game_resumed
signal save_data_success
signal save_data_failed(error_message: String)
signal load_data_received(data: String)
signal ad_request_success
signal ad_request_failed(error_message: String)

const SDK := "window.YTGameSDK_Godot"
const STATE := "window.__XENOHT"

# Set once in _ready; when false (standalone / local) we skip all polling.
var _in_env := false

# Poll cursors so each event is handled exactly once.
var _pause_seen := 0
var _resume_seen := 0
var _saveok_seen := 0
var _adok_seen := 0


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	# Install the official SDK's system listeners onto a pure-JS object that
	# only records state into window.__XENOHT. Then tell the SDK to wire it.
	JavaScriptBridge.eval("""
		window.__XENOHT = {
			pauseCount: 0, resumeCount: 0,
			audioEnabled: true, audioDirty: false,
			loadPayload: null,
			saveOkCount: 0, saveFailMsg: "",
			adOkCount: 0, adFailMsg: ""
		};
		window.GodotYTCallbacks = {
			onAudioEnabledChanged: function(e){ window.__XENOHT.audioEnabled = !!e; window.__XENOHT.audioDirty = true; },
			onGamePaused: function(){ window.__XENOHT.pauseCount++; },
			onGameResumed: function(){ window.__XENOHT.resumeCount++; },
			onLoadDataReceived: function(d){ window.__XENOHT.loadPayload = (d == null ? "" : String(d)); },
			onSaveSuccess: function(){ window.__XENOHT.saveOkCount++; },
			onSaveFailed: function(e){ window.__XENOHT.saveFailMsg = String(e); },
			onAdSuccess: function(){ window.__XENOHT.adOkCount++; },
			onAdFailed: function(e){ window.__XENOHT.adFailMsg = String(e); }
		};
		%s.setAllCallbacks();
	""" % SDK)
	# Detect the env once; skip per-frame polling outside Playables.
	_in_env = bool(JavaScriptBridge.eval("%s.inPlayablesEnv();" % SDK))


## Reads a numeric window.__XENOHT counter.
func _poll_count(prop: String) -> int:
	return int(JavaScriptBridge.eval("%s.%s" % [STATE, prop]))


func _process(_delta: float) -> void:
	if not OS.has_feature("web") or not _in_env:
		return
	# One-arg reads are injection-free (we own the property names).
	var pc: int = _poll_count("pauseCount")
	if pc != _pause_seen:
		_pause_seen = pc
		game_paused.emit()
	var rc: int = _poll_count("resumeCount")
	if rc != _resume_seen:
		_resume_seen = rc
		game_resumed.emit()
	var so: int = _poll_count("saveOkCount")
	if so != _saveok_seen:
		_saveok_seen = so
		save_data_success.emit()
	var ao: int = _poll_count("adOkCount")
	if ao != _adok_seen:
		_adok_seen = ao
		ad_request_success.emit()
	# String flags (read then cleared so they fire exactly once).
	var sf: String = str(JavaScriptBridge.eval("%s.saveFailMsg" % STATE))
	JavaScriptBridge.eval("%s.saveFailMsg = \\'\\';" % STATE)
	if sf != "":
		save_data_failed.emit(sf)
	var af: String = str(JavaScriptBridge.eval("%s.adFailMsg" % STATE))
	JavaScriptBridge.eval("%s.adFailMsg = \\'\\';" % STATE)
	if af != "":
		ad_request_failed.emit(af)
	var lp: String = str(JavaScriptBridge.eval("%s.loadPayload" % STATE))
	JavaScriptBridge.eval("%s.loadPayload = null;" % STATE)
	if lp != "" and lp != "null":
		load_data_received.emit(lp)
	var audio_dirty: bool = bool(JavaScriptBridge.eval("%s.audioDirty" % STATE))
	if audio_dirty:
		JavaScriptBridge.eval("%s.audioDirty = false;" % STATE)
		audio_enabled_changed.emit(bool(JavaScriptBridge.eval("%s.audioEnabled" % STATE)))


# --- Public API (names match the official wrapper) ---

func get_sdk_version() -> String:
	if not OS.has_feature("web"):
		return "N/A"
	return str(JavaScriptBridge.eval("%s.getSDKVersion();" % SDK))


func send_score(score: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.sendScore(%d);" % [SDK, int(score)])


func first_frame_ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.firstFrameReady();" % SDK)


func game_ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.gameReady();" % SDK)


func save_data(data: String) -> void:
	if not OS.has_feature("web"):
		return
	# `data` is our compact JSON payload string; embed it as an escaped JS
	# string literal (no raw embedding -> no injection), the SDK stringifies it
	# server-side. Result arrives via the onSaveSuccess/onSaveFailed flags.
	JavaScriptBridge.eval("%s.saveData(%s);" % [SDK, _js_str(data)])


func load_data() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.loadData();" % SDK)


func log_error(message: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.logError(%s);" % [SDK, _js_str(message)])


func log_warning(message: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.logWarning(%s);" % [SDK, _js_str(message)])


func is_audio_enabled() -> bool:
	if not OS.has_feature("web"):
		return true
	return bool(JavaScriptBridge.eval("%s.isAudioEnabled();" % SDK))


func in_playables_env() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("%s.inPlayablesEnv();" % SDK))


func request_interstitial_ad() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("%s.requestInterstitialAd();" % SDK)


## Escape a GDScript string into a single-quoted JS string literal.
func _js_str(s: String) -> String:
	var out := s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
	return "'%s'" % out
