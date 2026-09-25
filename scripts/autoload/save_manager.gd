extends Node
## Sürümlü, checksum'lı ve yedekli yerel kayıt.
## Yazma sırası (üretim planı §5): geçici dosya -> doğrulama -> eski kaydı yedekle -> geçiciyi aktif yap.
## Okuma: aktif kayıt bozuksa yedek, o da bozuksa varsayılan kayıt açılır.

const SAVE_VERSION := 1

var save_path := "user://save.json"


func tmp_path() -> String:
	return save_path + ".tmp"


func backup_path() -> String:
	return save_path + ".bak"


func default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"player_id_local": Crypto.new().generate_random_bytes(16).hex_encode(),
		"last_completed_level": 0,
		"level_stars": {},
		"currencies": {"gold": 0, "caravan_seal": 0, "trade_goods": 0},
		"inventory": {},
		"building_levels": {},
		"daily_task_state": {},
		"cosmetics_owned": [],
		"settings": {"music": true, "sfx": true, "vibration": true},
		"privacy_choices": {},
		"content_pack_version": 1,
		"purchase_entitlements": [],
	}


func load_data() -> Dictionary:
	for path in [save_path, backup_path()]:
		var d = _read_valid(path)
		if d != null:
			return _normalize(d)
	return default_data()


func save_data(data: Dictionary) -> bool:
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({
		"save_version": SAVE_VERSION,
		"checksum": payload.sha256_text(),
		"payload": payload,
	})
	# 1) geçici dosyaya yaz
	var f := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if f == null:
		push_error("Kayıt geçici dosyası açılamadı: %s" % FileAccess.get_open_error())
		return false
	f.store_string(envelope)
	f.close()
	# 2) şema ve checksum doğrula
	if _read_valid(tmp_path()) == null:
		push_error("Geçici kayıt doğrulanamadı")
		return false
	# 3) önceki sağlam kaydı yedekle
	var abs_save := ProjectSettings.globalize_path(save_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path())
	var abs_bak := ProjectSettings.globalize_path(backup_path())
	if FileAccess.file_exists(save_path) and _read_valid(save_path) != null:
		DirAccess.copy_absolute(abs_save, abs_bak)
	# 4) geçiciyi aktif kayıt yap
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(abs_save)
	var err := DirAccess.rename_absolute(abs_tmp, abs_save)
	if err != OK:
		push_error("Kayıt taşınamadı: %s" % err)
		return false
	return true


func _read_valid(path: String):
	if not FileAccess.file_exists(path):
		return null
	var env = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(env) != TYPE_DICTIONARY:
		return null
	var payload = env.get("payload")
	if typeof(payload) != TYPE_STRING or payload.sha256_text() != str(env.get("checksum", "")):
		return null
	var data = JSON.parse_string(payload)
	if typeof(data) != TYPE_DICTIONARY or not data.has("save_version"):
		return null
	return data


## JSON sayıları float olarak döner; alanları beklenen türlere çevirir, eksikleri doldurur.
func _normalize(d: Dictionary) -> Dictionary:
	var out := default_data()
	for k in d:
		out[k] = d[k]
	out["save_version"] = int(out["save_version"])
	out["last_completed_level"] = int(out["last_completed_level"])
	out["content_pack_version"] = int(out["content_pack_version"])
	var stars := {}
	for k in out["level_stars"]:
		stars[str(k)] = int(out["level_stars"][k])
	out["level_stars"] = stars
	return out
