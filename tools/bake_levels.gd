extends SceneTree
## İçerik fabrikası adımı: "Solver ile çöz -> hamle dengele -> paketle" + tekrar kuralları.
## Her bölüm için LevelBaker.bake çalıştırır ve dosyayı günceller.
## Kullanım: godot --headless --path . -s tools/bake_levels.gd

const LEVEL_PATH := "res://levels/level_%03d.json"


func _initialize() -> void:
	var failed := false
	var levels: Array = []
	var i := 1
	while FileAccess.file_exists(LEVEL_PATH % i):
		var path := LEVEL_PATH % i
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var t0 := Time.get_ticks_msec()
		var r := LevelBaker.bake(d)
		if not r["ok"]:
			printerr("HATA %s: %s" % [path, "; ".join(r["errors"])])
			failed = true
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(r["data"], "  ", false) + "\n")
			f.close()
			levels.append(LevelData.from_dict(r["data"]))
			print("%s  pratik=%d  min=%d  limit=%d  yıldız=%s  %dms" % [
				r["data"]["level_id"], r["practical"], r["min_moves"], r["data"]["move_limit"],
				r["data"]["star_thresholds"], Time.get_ticks_msec() - t0])
		i += 1
	for w in LevelBaker.check_sequence(levels):
		print("UYARI: " + w)
	quit(1 if failed else 0)
