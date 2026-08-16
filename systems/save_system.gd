class_name SaveSystem
## JSON (de)serialization of the save payload.
##
## Transport is deliberately NOT here: the Game autoload decides whether the
## payload goes to YouTube Playables `saveData`/`loadData` or browser
## localStorage. Keeping transport out keeps this class pure and testable
## (and avoids a compile-time dependency on the web-only wrapper).

const SAVE_KEY := "xenoh_save_v1"
const VERSION := 1


func build_payload(game: Dictionary) -> String:
	var payload := {
		"version": VERSION,
		"data": game,
	}
	return JSON.stringify(payload)


func parse_payload(json_str: String) -> Dictionary:
	if json_str == "":
		return {}
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION:
		push_warning("SaveSystem: unexpected save version %s" % str(d.get("version")))
	return d.get("data", {})


# ---------------- standalone localStorage ----------------

func save_local(json_str: String) -> void:
	if not _js_available():
		return
	# JSON.stringify quotes+escapes the Godot string on the JS side — no
	# manual escaping (which would double-escape).
	JavaScriptBridge.eval(
		"try { localStorage.setItem(JSON.stringify(%s), JSON.stringify(%s)); } catch (e) { /* sandboxed or private mode */ }"
		% [_js_str(SAVE_KEY), _js_str(json_str)]
	)


func load_local() -> String:
	if not _js_available():
		return ""
	var ret: Variant = JavaScriptBridge.eval(
		"(function(){ try { var v = localStorage.getItem(JSON.stringify(%s)); return v == null ? '' : v; } catch (e) { return ''; } })();"
		% _js_str(SAVE_KEY)
	)
	return str(ret)


func clear_local() -> void:
	if _js_available():
		JavaScriptBridge.eval("try { localStorage.removeItem(JSON.stringify(%s)); } catch (e) { /* noop */ }" % _js_str(SAVE_KEY))


# ---------------- helpers ----------------

func _js_available() -> bool:
	return OS.has_feature("web")


func _js_escape(s: String) -> String:
	var out: String = s
	out = out.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r")
	return out


func _js_str(s: String) -> String:
	return "'%s'" % _js_escape(s)
