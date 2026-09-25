extends SceneTree
## Otomatik testler. Kullanım: godot --headless --path . -s tests/run_tests.gd
## Çıkış kodu 0 = tüm testler geçti.

const LEVEL_PATH := "res://levels/level_%03d.json"

var _passed := 0
var _failed := 0
var _current := ""


func _initialize() -> void:
	var tests := [
		"test_tile_rotation",
		"test_levels_schema",
		"test_levels_solvable_and_balanced",
		"test_solver_matches_game_route",
		"test_three_stars_without_ads",
		"test_move_rules_and_undo",
		"test_invalid_drops_do_not_change_state",
		"test_fuzz_no_tile_loss_or_duplication",
		"test_best_rotation_deterministic",
		"test_fail_when_out_of_moves",
		"test_save_roundtrip_and_recovery",
	]
	for t in tests:
		_current = t
		var before := _failed
		call(t)
		print(("  OK   " if _failed == before else "  FAIL ") + t)
	print("\n%d kontrol geçti, %d başarısız" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("    [%s] %s" % [_current, msg])


func all_levels() -> Array[LevelData]:
	var out: Array[LevelData] = []
	var i := 1
	while FileAccess.file_exists(LEVEL_PATH % i):
		out.append(LevelData.load_file(LEVEL_PATH % i))
		i += 1
	return out


func simple_level() -> LevelData:
	return LevelData.from_dict({
		"level_id": "test", "grid_width": 5, "grid_height": 5,
		"start_cell": [0, 2], "goal_cell": [4, 2], "blocked_cells": [[2, 0]],
		"points_of_interest": [], "tile_pool": {"straight": 3, "corner": 2},
		"move_limit": 20, "star_thresholds": [4, 6],
	})


# ------------------------------------------------------------------ testler

func test_tile_rotation() -> void:
	var TD := TileDefs
	check(TD.mask_of(TD.Type.STRAIGHT, 0) == TD.N | TD.S, "düz 0")
	check(TD.mask_of(TD.Type.STRAIGHT, 1) == TD.E | TD.W, "düz 1")
	check(TD.mask_of(TD.Type.CORNER, 1) == TD.E | TD.S, "köşe 1")
	check(TD.mask_of(TD.Type.CORNER, 3) == TD.W | TD.N, "köşe 3")
	check(TD.rotate_mask(TD.ALL, 1) == TD.ALL, "tam maske")
	for d in TD.DIRS:
		check(TD.opposite(TD.opposite(d)) == d, "karşı yön")
		check(TD.dir_between(Vector2i(2, 2), Vector2i(2, 2) + TD.dir_offset(d)) == d, "dir_between")
	for t in TD.TYPE_NAMES:
		for r in range(TD.rotation_count(t)):
			var m := TD.mask_of(t, r)
			check(TD.type_for_mask(m) == t, "type_for_mask")
			check(TD.rotation_for_mask(t, m) == r, "rotation_for_mask")


func test_levels_schema() -> void:
	var levels := all_levels()
	check(levels.size() >= 10, "en az 10 bölüm bekleniyor, bulunan %d" % levels.size())
	var ids := {}
	for l in levels:
		check(l != null, "bölüm yüklenemedi")
		if l == null:
			continue
		var errs := l.validate()
		check(errs.is_empty(), "%s şema hataları: %s" % [l.level_id, errs])
		check(not ids.has(l.level_id), "tekrarlı level_id %s" % l.level_id)
		ids[l.level_id] = true


func test_levels_solvable_and_balanced() -> void:
	for l in all_levels():
		var res := RouteSolver.solve(l)
		check(res["solvable"], "%s çözümsüz" % l.level_id)
		check(res["min_moves"] == l.minimum_solution_moves,
				"%s min hamle %d, dosyada %d (bake_levels çalıştır)" % [l.level_id, res["min_moves"], l.minimum_solution_moves])
		check(res["min_moves"] <= l.move_limit, "%s hamle limiti yetersiz" % l.level_id)


## Plan §4.1: Solver sonucu oyun içi rotayla aynıdır.
func test_solver_matches_game_route() -> void:
	for l in all_levels():
		var m := BoardModel.new(l, 999)
		for p in l.solution:
			check(m.place_from_tray(p["type"], p["cell"]), "%s çözüm parçası yerleşmedi %s" % [l.level_id, p["cell"]])
			var guard := 0
			while m.tiles.has(p["cell"]) and m.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and guard < 4:
				m.rotate_tile(p["cell"])
				guard += 1
		check(m.is_complete(), "%s çözüm oyunda rotayı tamamlamıyor" % l.level_id)


## Plan §16: Reklam olmadan üç yıldız mümkün. Otomatik yönlendirme ile en kötü
## sıralamada gereken hamle sayısı üç yıldız eşiğini aşmamalı.
func test_three_stars_without_ads() -> void:
	for l in all_levels():
		var m := BoardModel.new(l)
		for p in l.solution:
			m.place_from_tray(p["type"], p["cell"])
			var guard := 0
			while m.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and guard < 4 and not m.is_finished():
				m.rotate_tile(p["cell"])
				guard += 1
		check(m.is_complete(), "%s hamle limitiyle çözülemedi" % l.level_id)
		check(l.stars_for(m.moves_used) == 3,
				"%s çözüm sırasıyla %d hamle, 3 yıldız eşiği %d" % [l.level_id, m.moves_used, l.star_thresholds[0]])


func test_move_rules_and_undo() -> void:
	var m := BoardModel.new(simple_level())
	var S := TileDefs.Type.STRAIGHT
	check(m.place_from_tray(S, Vector2i(1, 2)), "yerleştir")
	check(m.moves_used == 1 and m.tray_count(S) == 2, "yerleştirme 1 hamle")
	check(m.tiles[Vector2i(1, 2)]["rot"] == 1, "başlangıca bakacak şekilde yatay dönmeli")
	check(m.rotate_tile(Vector2i(1, 2)) and m.moves_used == 2, "döndürme 1 hamle")
	check(m.move_tile(Vector2i(1, 2), Vector2i(1, 3)) and m.moves_used == 3, "taşıma 1 hamle")
	check(m.return_to_tray(Vector2i(1, 3)) and m.moves_used == 3 and m.tray_count(S) == 3, "tepsiye dönüş 0 hamle")
	var sig_before_undos := m.signature()
	check(m.undo() and m.tiles.has(Vector2i(1, 3)), "geri al: tepsiye dönüş")
	check(m.undo() and m.tiles.has(Vector2i(1, 2)) and not m.tiles.has(Vector2i(1, 3)), "geri al: taşıma")
	check(m.undo() and m.tiles[Vector2i(1, 2)]["rot"] == 1, "geri al: döndürme")
	check(m.undo() and m.tiles.is_empty() and m.moves_used == 0 and m.tray_count(S) == 3, "geri al: yerleştirme")
	check(not m.undo(), "boş geçmişte geri alma yok")
	check(sig_before_undos != m.signature(), "imza değişti")
	for x in [1, 2, 3]:
		m.place_from_tray(S, Vector2i(x, 2))
	check(m.is_complete(), "düz rota tamamlanmalı")
	check(not m.place_from_tray(TileDefs.Type.CORNER, Vector2i(0, 0)), "bitmiş bölümde işlem yok")
	check(not m.can_undo(), "bitmiş bölümde geri alma yok")


func test_invalid_drops_do_not_change_state() -> void:
	var m := BoardModel.new(simple_level())
	var S := TileDefs.Type.STRAIGHT
	var sig := m.signature()
	check(not m.place_from_tray(S, Vector2i(2, 0)), "kapalı hücre")
	check(not m.place_from_tray(S, Vector2i(0, 2)), "başlangıç hücresi")
	check(not m.place_from_tray(S, Vector2i(4, 2)), "hedef hücresi")
	check(not m.place_from_tray(S, Vector2i(-1, 0)), "ızgara dışı")
	check(not m.place_from_tray(S, Vector2i(5, 5)), "ızgara dışı 2")
	check(not m.rotate_tile(Vector2i(3, 3)), "boş hücre döndürme")
	check(not m.return_to_tray(Vector2i(3, 3)), "boş hücreyi tepsiye")
	check(m.signature() == sig, "geçersiz işlemler durumu değiştirmemeli")
	m.place_from_tray(S, Vector2i(1, 1))
	sig = m.signature()
	check(not m.place_from_tray(S, Vector2i(1, 1)), "dolu hücre")
	check(not m.move_tile(Vector2i(1, 1), Vector2i(1, 1)), "aynı hücreye taşıma")
	check(not m.move_tile(Vector2i(1, 1), Vector2i(2, 0)), "kapalı hücreye taşıma")
	check(not m.place_from_tray(TileDefs.Type.CORNER, Vector2i(1, 1)), "dolu hücreye köşe")
	check(m.signature() == sig, "geçersiz işlemler durumu değiştirmemeli 2")


## Plan Gün 4: Yanlış dokunuş parça kaybına veya çoğalmasına yol açmaz.
func test_fuzz_no_tile_loss_or_duplication() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	for l in all_levels():
		var m := BoardModel.new(l, 100000)
		var initial := m.signature()
		var ops := 0
		for step in range(1500):
			var c := Vector2i(rng.randi_range(-1, l.grid_width), rng.randi_range(-1, l.grid_height))
			var c2 := Vector2i(rng.randi_range(-1, l.grid_width), rng.randi_range(-1, l.grid_height))
			match rng.randi_range(0, 5):
				0, 1:
					m.place_from_tray(rng.randi_range(0, 1), c)
				2:
					m.rotate_tile(c)
				3:
					m.move_tile(c, c2)
				4:
					m.return_to_tray(c)
				5:
					m.undo()
			if m.is_complete():
				# Bitmiş bölümde işlem kabul edilmez; yeni tur için sıfırla.
				m.reset()
			ops += 1
			for t in TileDefs.TYPE_NAMES:
				if m.tray_count(t) + m.placed_count(t) != int(l.tile_pool[t]) or m.tray_count(t) < 0:
					check(false, "%s parça sayısı bozuldu adım %d" % [l.level_id, step])
					return
			for tc in m.tiles:
				if not l.in_bounds(tc) or m.is_blocked(tc) or l.is_hub(tc):
					check(false, "%s geçersiz hücrede parça %s" % [l.level_id, tc])
					return
			if m.moves_used < 0:
				check(false, "negatif hamle")
				return
		while m.undo():
			pass
		check(m.signature() == initial, "%s tüm geri almalar başlangıca dönmeli" % l.level_id)
		check(ops == 1500, "işlem sayısı")


func test_best_rotation_deterministic() -> void:
	for l in all_levels():
		var a := BoardModel.new(l, 999)
		var b := BoardModel.new(l, 999)
		for p in l.solution:
			a.place_from_tray(p["type"], p["cell"])
			b.place_from_tray(p["type"], p["cell"])
		check(a.signature() == b.signature(), "%s aynı girdi aynı sonucu vermeli" % l.level_id)


func test_fail_when_out_of_moves() -> void:
	var l := simple_level()
	var m := BoardModel.new(l, 2)
	m.place_from_tray(TileDefs.Type.STRAIGHT, Vector2i(1, 2))
	check(not m.is_failed(), "henüz başarısız değil")
	m.rotate_tile(Vector2i(1, 2))
	check(m.moves_left() == 0 and m.is_failed(), "hamle bitince başarısız")
	check(not m.undo(), "başarısız bölümde geri alma yok")
	m.add_moves(3)
	check(not m.is_failed() and m.moves_left() == 3, "ek hamle ile devam")


func test_save_roundtrip_and_recovery() -> void:
	var sm = load("res://scripts/autoload/save_manager.gd").new()
	sm.save_path = "user://test_save.json"
	for p in [sm.save_path, sm.backup_path(), sm.tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var d: Dictionary = sm.load_data()
	check(d["last_completed_level"] == 0, "varsayılan kayıt")
	check(str(d["player_id_local"]).length() == 32, "yerel oyuncu kimliği")
	d["last_completed_level"] = 3
	d["level_stars"] = {"1": 3, "2": 2, "3": 1}
	check(sm.save_data(d), "kayıt yazıldı")
	var r: Dictionary = sm.load_data()
	check(r["last_completed_level"] == 3 and r["level_stars"]["2"] == 2, "kayıt geri okundu")
	check(r["player_id_local"] == d["player_id_local"], "oyuncu kimliği korundu")
	d["last_completed_level"] = 4
	check(sm.save_data(d), "ikinci kayıt")
	check(FileAccess.file_exists(sm.backup_path()), "yedek oluştu")
	# Aktif kaydı boz: yedekten (3) açılmalı.
	var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	check(sm.load_data()["last_completed_level"] == 3, "bozuk kayıtta yedek açıldı")
	# Checksum uyuşmazlığı da bozuk sayılır.
	f = FileAccess.open(sm.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 1, "checksum": "x", "payload": "{\"save_version\":1}"}))
	f.close()
	check(sm.load_data()["last_completed_level"] == 3, "checksum hatasında yedek açıldı")
	# Bozuk aktif kayıt üstüne yazılırken sağlam yedek ezilmemeli.
	d["last_completed_level"] = 5
	check(sm.save_data(d), "bozuk kayıt üzerine yazma")
	check(sm.load_data()["last_completed_level"] == 5, "yeni kayıt açılır")
	for p in [sm.save_path, sm.backup_path(), sm.tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sm.free()
