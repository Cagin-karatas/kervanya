extends Node
## Analitik olayları (üretim planı §10).
## Şimdilik olaylar yalnız cihazda, JSON satırları olarak saklanır; ağa hiçbir şey gönderilmez.
## Serbest metin ve kişisel veri kabul edilmez: parametreler yalnız sayı, mantıksal değer veya
## kısa küçük harfli kimlik (ör. "w1_c1_l003") olabilir.

const LOG_PATH := "user://analytics/events.jsonl"
const MAX_BYTES := 1500000
const MAX_ID_LENGTH := 40

const EVENTS := [
	"app_open", "session_start", "tester_start",
	"tutorial_start", "tutorial_complete",
	"level_start", "level_complete", "level_fail", "level_quit", "level_restart",
	"tile_placed", "tile_rotated", "tile_moved", "tile_returned", "tile_undo",
	"assist_triggered", "report_opened",
]

var log_path := LOG_PATH
var session_id := ""

var _id_regex := RegEx.create_from_string("^[a-z0-9_]{1,%d}$" % MAX_ID_LENGTH)


func _ready() -> void:
	session_id = Crypto.new().generate_random_bytes(8).hex_encode()
	track("app_open")
	track("session_start")


func old_log_path() -> String:
	return log_path.get_basename() + ".1.jsonl"


## Olayı ortak alanlarla birlikte kaydeder. Geçersiz olay adı veya parametre reddedilir.
func track(event_name: String, params: Dictionary = {}) -> bool:
	if not EVENTS.has(event_name):
		push_warning("Bilinmeyen analitik olayı: %s" % event_name)
		return false
	var ev := common_fields()
	ev["event"] = event_name
	for k in params:
		var v = params[k]
		if not _id_regex.search(str(k)):
			push_warning("Geçersiz analitik alan adı: %s" % k)
			continue
		if not _valid_value(v):
			push_warning("Analitik değeri reddedildi: %s" % k)
			continue
		ev[k] = v
	_append(JSON.stringify(ev))
	return true


func common_fields() -> Dictionary:
	var data := _save_data()
	return {
		"event_time": Time.get_unix_time_from_system(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "0")),
		"platform": OS.get_name().to_lower(),
		"country": _country(),
		"session_id": session_id,
		"local_player_id": str(data.get("player_id_local", "")),
		"content_pack_version": int(data.get("content_pack_version", 1)),
		"experiment_group": "none",
		"tester": int(data.get("test_tester", 1)),
	}


func read_events() -> Array:
	var out: Array = []
	for path in [old_log_path(), log_path]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		while f != null and not f.eof_reached():
			var line := f.get_line()
			if line.is_empty():
				continue
			var ev = JSON.parse_string(line)
			if typeof(ev) == TYPE_DICTIONARY:
				out.append(ev)
	return out


func clear() -> void:
	for path in [old_log_path(), log_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _valid_value(v) -> bool:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			return _id_regex.search(str(v)) != null
	return false


func _append(line: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_path.get_base_dir()))
	var f: FileAccess
	if FileAccess.file_exists(log_path):
		f = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if f != null and f.get_length() > MAX_BYTES:
			f.close()
			var abs_old := ProjectSettings.globalize_path(old_log_path())
			if FileAccess.file_exists(old_log_path()):
				DirAccess.remove_absolute(abs_old)
			DirAccess.rename_absolute(ProjectSettings.globalize_path(log_path), abs_old)
			f = FileAccess.open(log_path, FileAccess.WRITE)
	else:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()


func _save_data() -> Dictionary:
	if not is_inside_tree():
		return {}
	var gs := get_node_or_null("/root/GameState")
	return gs.data if gs != null else {}


func _country() -> String:
	var loc := OS.get_locale().replace("-", "_")
	var parts := loc.split("_")
	return parts[1].to_lower() if parts.size() > 1 and parts[1].length() == 2 else "xx"
