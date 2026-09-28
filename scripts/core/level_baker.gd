class_name LevelBaker
extends RefCounted
## İçerik fabrikası çekirdeği (plan §6): bölüm verisini çöz, hamle/yıldız dengesini yaz,
## rastgele seed'den bölüm üret ve bölüm dizisini tekrar kurallarına göre denetle.

const HARD_DIFFICULTY := 7


## Bölüm sözlüğünü çözer ve şu alanları yazar: minimum_solution_moves, move_limit,
## star_thresholds, solution. Dönüş: {ok, data, errors, min_moves, practical, nodes}
static func bake(d: Dictionary) -> Dictionary:
	var src := d.duplicate(true)
	src["move_limit"] = 999
	src["minimum_solution_moves"] = 0
	src["star_thresholds"] = [999, 999]
	var level := LevelData.from_dict(src)
	var errs := level.validate()
	if not errs.is_empty():
		return {"ok": false, "data": d, "errors": errs}
	var res := RouteSolver.solve(level)
	if not res["solvable"]:
		return {"ok": false, "data": d, "errors": PackedStringArray(["Çözüm yok: parça havuzu veya kapalı kareler rotaya izin vermiyor"])}
	var min_moves: int = res["min_moves"]
	# Pratik minimum: çözüm sırasıyla oynandığında otomatik yönlendirme sonrası gereken
	# döndürmeler dahil hamle sayısı. Üç yıldız bununla garanti edilir.
	var practical := practical_moves(level, res["placements"])
	var slack: int = int(d.get("move_slack", 4))
	var out := d.duplicate(true)
	out["minimum_solution_moves"] = min_moves
	out["move_limit"] = practical + slack
	out["star_thresholds"] = [practical + ceili(slack * 0.4), practical + ceili(slack * 0.75)]
	var sol := []
	for p in res["placements"]:
		sol.append({"cell": [p["cell"].x, p["cell"].y], "type": TileDefs.TYPE_NAMES[p["type"]], "rot": p["rot"]})
	out["solution"] = sol
	return {"ok": true, "data": out, "errors": PackedStringArray(), "min_moves": min_moves,
			"practical": practical, "nodes": res["nodes"]}


static func practical_moves(level: LevelData, placements: Array) -> int:
	var m := BoardModel.new(level, 999)
	for p in placements:
		m.place_from_tray(p["type"], p["cell"])
		var guard := 0
		while m.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and guard < 4:
			m.rotate_tile(p["cell"])
			guard += 1
	return m.moves_used


## Aynı seed ve ayarlar her cihazda aynı bölümü üretir.
## opts: blocked (0-0.4 kapalı kare oranı), pois (pazar sayısı), spare_straight, spare_corner, move_slack
static func generate(seed: int, w: int, h: int, opts: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var density := clampf(float(opts.get("blocked", 0.15)), 0.0, 0.4)
	var n_pois := int(opts.get("pois", 0))
	for attempt in range(60):
		var start := _edge_cell(rng, w, h)
		var goal := _edge_cell(rng, w, h)
		if absi(start.x - goal.x) + absi(start.y - goal.y) < (w + h) / 2:
			continue
		var taken := {start: true, goal: true}
		var pois := []
		for i in range(n_pois):
			var c := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
			if not taken.has(c):
				taken[c] = true
				pois.append([c.x, c.y])
		var blocked := []
		for y in range(h):
			for x in range(w):
				var c := Vector2i(x, y)
				if not taken.has(c) and rng.randf() < density:
					blocked.append([x, y])
		var d := {
			"level_id": "gen_%d" % seed, "content_version": 1, "world_id": 1, "chapter_id": 1,
			"grid_width": w, "grid_height": h, "start_cell": [start.x, start.y], "goal_cell": [goal.x, goal.y],
			"blocked_cells": blocked, "points_of_interest": pois,
			"tile_pool": {"straight": w * h, "corner": w * h},
			"move_slack": int(opts.get("move_slack", 4)), "difficulty_score": 3,
			"rhythm": "", "template_id": "gen", "tutorial_key": "", "assist_after_fail_count": 3,
			"seed": seed,
		}
		var first := bake(d)
		if not first["ok"]:
			continue
		var counts := {"straight": 0, "corner": 0}
		for p in first["data"]["solution"]:
			counts[p["type"]] += 1
		d["tile_pool"] = {
			"straight": counts["straight"] + int(opts.get("spare_straight", 1)),
			"corner": counts["corner"] + int(opts.get("spare_corner", 1)),
		}
		var final := bake(d)
		if final["ok"]:
			return final
	return {"ok": false, "data": {}, "errors": PackedStringArray(["Bu ayarlarla çözülebilir bölüm üretilemedi"])}


static func _edge_cell(rng: RandomNumberGenerator, w: int, h: int) -> Vector2i:
	match rng.randi_range(0, 3):
		0:
			return Vector2i(rng.randi_range(0, w - 1), 0)
		1:
			return Vector2i(rng.randi_range(0, w - 1), h - 1)
		2:
			return Vector2i(0, rng.randi_range(0, h - 1))
	return Vector2i(w - 1, rng.randi_range(0, h - 1))


## Plan §6 "Tekrar önleme" kurallarından veriyle denetlenebilenler. Uyarı listesi döner.
static func check_sequence(levels: Array) -> PackedStringArray:
	var warns := PackedStringArray()
	for i in range(levels.size()):
		var l: LevelData = levels[i]
		var n := i + 1
		for j in range(maxi(0, i - 10), i):
			var p: LevelData = levels[j]
			if not l.template_id.is_empty() and l.template_id == p.template_id:
				warns.append("Bölüm %d: şablon '%s' son 10 bölümde (bölüm %d) kullanıldı" % [n, l.template_id, j + 1])
		for j in range(maxi(0, i - 5), i):
			var p: LevelData = levels[j]
			if l.start_cell == p.start_cell and l.goal_cell == p.goal_cell:
				warns.append("Bölüm %d: başlangıç/bitiş bölüm %d ile aynı (son 5 bölüm kuralı)" % [n, j + 1])
		if i > 0 and l.difficulty_score >= HARD_DIFFICULTY and levels[i - 1].difficulty_score >= HARD_DIFFICULTY:
			warns.append("Bölüm %d: iki zor bölüm arka arkaya" % n)
		for j in range(i):
			if board_key(l) == board_key(levels[j]):
				warns.append("Bölüm %d: tahta bölüm %d ile birebir aynı" % [n, j + 1])
	return warns


static func board_key(l: LevelData) -> String:
	var b := l.blocked_cells.duplicate()
	b.sort()
	var p := l.points_of_interest.duplicate()
	p.sort()
	return "%dx%d|%s|%s|%s|%s|%s" % [l.grid_width, l.grid_height, l.start_cell, l.goal_cell, b, p, l.tile_pool]
