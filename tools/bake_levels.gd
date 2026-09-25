extends SceneTree
## İçerik fabrikası adımı: "Solver ile çöz -> hamle dengele -> paketle".
## Her bölüm için RouteSolver çalıştırır ve şu alanları yazar:
##   minimum_solution_moves, move_limit (= min + move_slack), star_thresholds, solution
## Kullanım: godot --headless --path . -s tools/bake_levels.gd

const LEVEL_PATH := "res://levels/level_%03d.json"


func _initialize() -> void:
	var failed := false
	var i := 1
	while FileAccess.file_exists(LEVEL_PATH % i):
		var path := LEVEL_PATH % i
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		d["move_limit"] = 99
		d["star_thresholds"] = [99, 99]
		var level := LevelData.from_dict(d)
		var t0 := Time.get_ticks_msec()
		var res := RouteSolver.solve(level)
		if not res["solvable"]:
			printerr("ÇÖZÜMSÜZ: %s" % path)
			failed = true
			i += 1
			continue
		var min_moves: int = res["min_moves"]
		var slack: int = int(d.get("move_slack", 4))
		# Pratik minimum: çözüm sırasıyla oynandığında otomatik yönlendirme sonrası
		# gereken döndürmeler dahil hamle sayısı. Üç yıldız bununla garanti edilir.
		var practical := _practical_moves(level, res["placements"])
		d["minimum_solution_moves"] = min_moves
		d["move_limit"] = practical + slack
		d["star_thresholds"] = [practical + ceili(slack * 0.4), practical + ceili(slack * 0.75)]
		var sol := []
		for p in res["placements"]:
			sol.append({"cell": [p["cell"].x, p["cell"].y], "type": TileDefs.TYPE_NAMES[p["type"]], "rot": p["rot"]})
		d["solution"] = sol
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "  ", false) + "\n")
		f.close()
		print("%s  pratik=%d  min=%d  limit=%d  yıldız=%s  düğüm=%d  %dms" % [
			d["level_id"], practical, min_moves, d["move_limit"], d["star_thresholds"], res["nodes"], Time.get_ticks_msec() - t0])
		i += 1
	quit(1 if failed else 0)


func _practical_moves(level: LevelData, placements: Array) -> int:
	var m := BoardModel.new(level, 999)
	for p in placements:
		m.place_from_tray(p["type"], p["cell"])
		var guard := 0
		while m.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and guard < 4:
			m.rotate_tile(p["cell"])
			guard += 1
	return m.moves_used
