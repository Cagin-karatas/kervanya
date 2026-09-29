extends SceneTree
## İçerik fabrikası (plan §6): spesifikasyon dosyasından bölüm üretir.
## Her bölüm için seed'leri sırayla dener; çözücü, zorluk aralığı, alternatif çözüm ve
## tekrar kurallarını geçen ilk seed'i levels/level_NNN.json olarak yazar.
## Kullanım: godot --headless --path . -s tools/make_levels.gd -- levels/specs/<dosya>.json

const LEVEL_PATH := "res://levels/level_%03d.json"
const MAX_TRIES := 600


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Kullanım: -- levels/specs/<dosya>.json")
		quit(2)
		return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + args[0]))
	var start: int = int(spec["start_number"])
	var gw: int = int(spec["grid"][0])
	var gh: int = int(spec["grid"][1])
	var accepted: Array = []
	for i in range(1, start):
		accepted.append(LevelData.load_file(LEVEL_PATH % i))
	var failed := false
	for k in range(spec["levels"].size()):
		var ls: Dictionary = spec["levels"][k]
		var n := start + k
		var found := {}
		var tries := 0
		var why := {"üretilemedi": 0, "rota uzunluğu": 0, "zorluk": 0, "alternatif yok": 0, "tekrar kuralı": 0}
		for s in range(int(ls.get("tries", MAX_TRIES))):
			var seed := int(spec["seed_base"]) + k * 1000 + s
			tries += 1
			var r := LevelBaker.generate(seed, gw, gh, {
				"blocked": ls["blocked"], "pois": ls["pois"], "move_slack": ls["slack"],
				"spare_straight": ls["spare_straight"], "spare_corner": ls["spare_corner"]})
			if not r["ok"]:
				why["üretilemedi"] += 1
				continue
			var d: Dictionary = r["data"]
			if d["minimum_solution_moves"] < ls["min_moves"][0] or d["minimum_solution_moves"] > ls["min_moves"][1]:
				why["rota uzunluğu"] += 1
				continue
			var diff := LevelBaker.difficulty_score(d)
			if diff < ls["difficulty"][0] or diff > ls["difficulty"][1]:
				why["zorluk"] += 1
				continue
			if ls.get("need_alternative", false) and not LevelBaker.has_alternative(d):
				why["alternatif yok"] += 1
				continue
			d["difficulty_score"] = diff
			d["rhythm"] = ls["rhythm"]
			d["template_id"] = ls["template_id"]
			d["world_id"] = (n - 1) / 100 + 1
			d["chapter_id"] = ((n - 1) % 100) / 20 + 1
			d["level_id"] = "w%d_c%d_l%03d" % [d["world_id"], d["chapter_id"], n]
			var trial := accepted.duplicate()
			trial.append(LevelData.from_dict(d))
			var warns := LevelBaker.check_sequence(trial)
			var own := false
			for w in warns:
				if w.begins_with("Bölüm %d:" % n):
					own = true
			if own:
				why["tekrar kuralı"] += 1
				continue
			found = d
			break
		if found.is_empty():
			printerr("Bölüm %d: %d denemede uygun seed bulunamadı; elenme nedenleri: %s" % [n, tries, why])
			failed = true
			continue
		var f := FileAccess.open(LEVEL_PATH % n, FileAccess.WRITE)
		f.store_string(JSON.stringify(found, "  ", false) + "\n")
		f.close()
		accepted.append(LevelData.from_dict(found))
		print("Bölüm %d  seed=%d  deneme=%d  min=%d  limit=%d  zorluk=%d %s  pazar=%d  kapalı=%d  %s" % [
			n, found["seed"], tries, found["minimum_solution_moves"], found["move_limit"], found["difficulty_score"],
			LevelBaker.difficulty_components(found), found["points_of_interest"].size(), found["blocked_cells"].size(), found["rhythm"]])
	quit(1 if failed else 0)
