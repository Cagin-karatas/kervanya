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
		"test_analytics_log_and_privacy",
		"test_report_builder",
		"test_level_baker",
		"test_generator_deterministic_and_solvable",
		"test_sequence_rules",
		"test_journey_model",
		"test_economy",
		"test_generated_levels_properties",
		"test_town_model",
		"test_junction",
		"test_audio_assets",
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


func test_analytics_log_and_privacy() -> void:
	var an = load("res://scripts/autoload/analytics_service.gd").new()
	an.log_path = "user://test_analytics/events.jsonl"
	an.clear()
	check(an.track("level_start", {"level_id": "w1_c1_l001", "level_number": 1}), "geçerli olay")
	check(not an.track("bilinmeyen_olay"), "bilinmeyen olay reddedilir")
	an.track("level_complete", {"level_number": 1, "moves_used": 3, "note": "Ali Veli 0555 123",
			"email": "a@b.com", "nested": {"x": 1}, "Bad Key": 1})
	var evs: Array = an.read_events()
	check(evs.size() == 2, "iki olay kaydedildi (%d)" % evs.size())
	if evs.size() == 2:
		var e: Dictionary = evs[1]
		check(e["event"] == "level_complete" and int(e["moves_used"]) == 3, "olay alanları")
		check(not e.has("note") and not e.has("email") and not e.has("nested") and not e.has("Bad Key"),
				"serbest metin / kişisel veri / iç içe veri kaydedilmez")
		for k in ["event_time", "app_version", "platform", "country", "session_id", "local_player_id",
				"content_pack_version", "experiment_group", "tester"]:
			check(e.has(k), "ortak alan: " + k)
	# Dönüşüm: büyük kayıt eski dosyaya taşınır, okunurken ikisi de gelir.
	var f := FileAccess.open(an.log_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"event": "pad", "pad": "x".repeat(an.MAX_BYTES + 10)}) + "\n")
	f.close()
	an.track("level_start", {"level_number": 2})
	check(FileAccess.file_exists(an.old_log_path()), "büyük kayıt döndürüldü")
	check(an.read_events().size() == 2, "eski ve yeni dosya birlikte okunur")
	an.clear()
	an.free()


func test_report_builder() -> void:
	var t0 := 1000.0
	var evs := [
		{"event": "app_open", "tester": 1, "event_time": t0},
		{"event": "level_start", "tester": 1, "event_time": t0 + 5, "level_number": 1},
		{"event": "tile_placed", "tester": 1, "event_time": t0 + 8, "level_number": 1},
		{"event": "tile_rotated", "tester": 1, "event_time": t0 + 9, "level_number": 1},
		{"event": "level_complete", "tester": 1, "event_time": t0 + 30, "level_number": 1, "moves_used": 4, "stars": 3, "duration_ms": 25000},
		{"event": "level_start", "tester": 1, "event_time": t0 + 35, "level_number": 2},
		{"event": "level_fail", "tester": 1, "event_time": t0 + 60, "level_number": 2, "moves_used": 9},
		{"event": "level_start", "tester": 1, "event_time": t0 + 62, "level_number": 2},
		{"event": "level_complete", "tester": 1, "event_time": t0 + 90, "level_number": 2, "moves_used": 6, "stars": 3, "duration_ms": 28000},
		{"event": "level_start", "tester": 1, "event_time": t0 + 95, "level_number": 3},
		{"event": "tester_start", "tester": 2, "event_time": t0 + 200},
		{"event": "level_start", "tester": 2, "event_time": t0 + 210, "level_number": 1},
		{"event": "level_quit", "tester": 2, "event_time": t0 + 400, "level_number": 1},
	]
	var r := TestReport.build(evs)
	check(r.size() == 2, "iki testçi")
	if r.size() != 2:
		return
	check(r[0]["reached_level3_s"] == 95 and r[0]["furthest"] == 3, "testçi 1: 3. bölüme 95 sn'de ulaştı")
	var l1: Dictionary = r[0]["levels"][1]
	var l2: Dictionary = r[0]["levels"][2]
	check(l1["first_try"] == true and l1["rotations"] == 1 and l1["best_moves"] == 4, "bölüm 1 özeti")
	check(l2["first_try"] == false and l2["attempts"] == 2 and is_equal_approx(l2["first_complete_s"], 28.0), "bölüm 2 özeti")
	check(r[1]["reached_level3_s"] == -1 and r[1]["levels"][1]["first_try"] == false, "testçi 2: çıktı, 3. bölüme ulaşmadı")
	var g := TestReport.gate(r)
	check(g["testers"] == 2 and g["reached_level3"] == 1, "kapı özeti")
	var txt := TestReport.to_text(r)
	check(txt.contains("3. bölüme ulaşan testçi: 1 / 2") and txt.contains("Testçi 2"), "metin rapor")


func test_level_baker() -> void:
	var d := {"level_id": "t", "grid_width": 5, "grid_height": 5, "start_cell": [0, 2], "goal_cell": [4, 2],
			"blocked_cells": [], "points_of_interest": [], "tile_pool": {"straight": 3, "corner": 0}, "move_slack": 4}
	var r := LevelBaker.bake(d)
	check(r["ok"] and r["min_moves"] == 3 and int(r["data"]["move_limit"]) == 7, "düz rota pişirildi")
	check(r["data"]["solution"].size() == 3, "çözüm yazıldı")
	d["tile_pool"] = {"straight": 2, "corner": 0}
	check(not LevelBaker.bake(d)["ok"], "yetersiz havuz çözümsüz")
	d["tile_pool"] = {"straight": 3, "corner": 0}
	d["blocked_cells"] = [[2, 2]]
	check(not LevelBaker.bake(d)["ok"], "kapalı kareyle çözümsüz")
	d["goal_cell"] = [0, 2]
	check(not LevelBaker.bake(d)["ok"], "şema hatası yakalandı")
	# Mevcut bölümler pişirildiği haliyle aynı olmalı (bake_levels çalıştırılmış mı).
	var levels := all_levels()
	for i in range(levels.size()):
		var l := levels[i]
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH % (i + 1)))
		var again := LevelBaker.bake(raw)
		check(again["ok"] and int(again["data"]["move_limit"]) == l.move_limit, "%s pişirme güncel" % l.level_id)


func test_generator_deterministic_and_solvable() -> void:
	for seed in [1, 7, 42, 1234]:
		var a := LevelBaker.generate(seed, 6, 6, {"blocked": 0.2, "pois": 1})
		var b := LevelBaker.generate(seed, 6, 6, {"blocked": 0.2, "pois": 1})
		check(a["ok"], "seed %d üretildi" % seed)
		if not a["ok"]:
			continue
		check(JSON.stringify(a["data"]) == JSON.stringify(b["data"]), "seed %d deterministik" % seed)
		var l := LevelData.from_dict(a["data"])
		check(l.validate().is_empty(), "seed %d şema geçerli" % seed)
		var m := BoardModel.new(l, 999)
		for p in l.solution:
			m.place_from_tray(p["type"], p["cell"])
			var g := 0
			while m.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and g < 4:
				m.rotate_tile(p["cell"])
				g += 1
		check(m.is_complete(), "seed %d oyunda çözülüyor" % seed)
	var c := LevelBaker.generate(7, 6, 6, {"blocked": 0.2})
	var e := LevelBaker.generate(8, 6, 6, {"blocked": 0.2})
	check(c["ok"] and e["ok"] and JSON.stringify(c["data"]["blocked_cells"]) != JSON.stringify(e["data"]["blocked_cells"]), "farklı seed farklı tahta")


func test_sequence_rules() -> void:
	var levels := all_levels()
	check(LevelBaker.check_sequence(levels).is_empty(), "mevcut bölümler tekrar kurallarına uyuyor: %s" % LevelBaker.check_sequence(levels))
	var dup: Array = [levels[0], levels[1], levels[0]]
	var w := LevelBaker.check_sequence(dup)
	check(" ".join(w).contains("birebir aynı") and " ".join(w).contains("şablon"), "tekrar eden tahta ve şablon yakalandı")
	var hard_a := LevelData.from_dict({"level_id": "a", "difficulty_score": 8, "start_cell": [0, 0], "goal_cell": [4, 4], "template_id": "x"})
	var hard_b := LevelData.from_dict({"level_id": "b", "difficulty_score": 9, "start_cell": [0, 1], "goal_cell": [4, 3], "template_id": "y"})
	check(" ".join(LevelBaker.check_sequence([hard_a, hard_b])).contains("iki zor"), "arka arkaya zor bölüm yakalandı")


## Rakip taşlardan önceden kaçan "mükemmel oyuncu".
func _dodge(m: JourneyModel) -> void:
	for it in m.items:
		if it["done"] or it["kind"] != "rock":
			continue
		if it["y"] - m.distance < 1.0 and it["lane"] == m.lane:
			m.move(1 if m.lane < JourneyModel.LANES - 1 else -1)
		return


func test_journey_model() -> void:
	var a := JourneyModel.new(123, 8, "medium")
	var b := JourneyModel.new(123, 8, "medium")
	check(JSON.stringify(a.items) == JSON.stringify(b.items), "aynı seed aynı yol")
	check(JSON.stringify(a.items) != JSON.stringify(JourneyModel.new(124, 8, "medium").items), "farklı seed farklı yol")
	check(is_equal_approx(a.duration, 14.4), "süre rota uzunluğundan: %s" % a.duration)
	check(JourneyModel.new(1, 100, "easy").duration == 22.0 and JourneyModel.new(1, 0, "easy").duration == 10.0, "süre sınırları")
	# Her sırada tek nesne: her an en az iki şerit açık
	var ys := {}
	for it in a.items:
		check(not ys.has(it["y"]), "aynı hizada iki nesne yok")
		ys[it["y"]] = true
	# Hiç hareket etmeyen oyuncu çarpar; en fazla 3 çarpmada biter
	var idle := JourneyModel.new(7, 10, "hard")
	while not idle.finished:
		idle.step(1.0 / 60.0)
	check(idle.hits > 0 and idle.hits <= idle.max_hits, "hareketsiz oyuncu çarpar (%d)" % idle.hits)
	# Mükemmel oyuncu hiç çarpmaz ve süre dolunca biter
	for diff in ["easy", "medium", "hard"]:
		var m := JourneyModel.new(99, 10, diff)
		while not m.finished:
			_dodge(m)
			m.step(1.0 / 60.0)
		check(m.hits == 0 and m.result()["completed"], "%s: kaçan oyuncu çarpmadan bitirir (çarpma %d)" % [diff, m.hits])
		check(absf(m.t - m.duration) < 0.05, "%s: süre doldu" % diff)
	# Hızlanma daha çok yol aldırır
	var slow := JourneyModel.new(5, 10, "easy")
	var fast := JourneyModel.new(5, 10, "easy")
	for i in range(60):
		if i % 30 == 0:
			fast.boost()
		slow.step(1.0 / 60.0)
		fast.step(1.0 / 60.0)
	check(fast.distance > slow.distance * 1.3, "hızlanma mesafeyi artırır")
	# Atlama ve ödül
	var sk := JourneyModel.new(5, 10, "easy")
	sk.skip()
	var r := sk.result()
	check(r["skipped"] and not r["completed"] and r["gold"] == 0, "atlama bonus vermez")
	var gm := JourneyModel.new(5, 10, "easy")
	gm.bonuses = 3
	gm.hits = 5
	check(gm.result()["gold"] == 0, "altın negatife düşmez")
	# Plan kuralı: bulmaca zorluğu 7+ ise yolculuk en fazla orta
	var hard_level := LevelData.from_dict({"level_id": "h", "difficulty_score": 8})
	check(JourneyModel.difficulty_for(hard_level, 50, "hard") == "medium", "zor bulmacada yolculuk en fazla orta")
	check(JourneyModel.difficulty_for(hard_level, 5) == "easy" and JourneyModel.difficulty_for(hard_level, 15) == "medium", "varsayılan yolculuk zorluğu")


func test_economy() -> void:
	var l := LevelData.from_dict({"level_id": "e", "difficulty_score": 3})
	check(GameState_puzzle_gold(l, true, 3, 0) == 21, "ilk tamamlanma + 3 yıldız: 10+6+5")
	check(GameState_puzzle_gold(l, false, 3, 3) == 3, "tekrar oynama 3 altın")
	check(GameState_puzzle_gold(l, false, 3, 2) == 8, "sonradan 3 yıldız +5")
	check(GameState_puzzle_gold(l, true, 2, 0) == 16, "ilk tamamlanma 2 yıldız")


func GameState_puzzle_gold(l: LevelData, first: bool, stars: int, prev: int) -> int:
	return load("res://scripts/autoload/game_state.gd").puzzle_gold(l, first, stars, prev)


func test_generated_levels_properties() -> void:
	var levels := all_levels()
	check(levels.size() >= 20, "en az 20 bölüm (%d)" % levels.size())
	for i in range(10, mini(20, levels.size())):
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH % (i + 1)))
		check(raw.has("seed"), "bölüm %d seed kaydı var" % (i + 1))
		check(int(raw["difficulty_score"]) == LevelBaker.difficulty_score(raw), "bölüm %d zorluk puanı güncel" % (i + 1))
		if raw.get("rhythm", "") in ["Alternatif çözüm", "Zor bölüm", "Fasıl finali"]:
			check(LevelBaker.has_alternative(raw), "bölüm %d en az iki çözüm" % (i + 1))
		var regen := LevelBaker.generate(int(raw["seed"]), int(raw["grid_width"]), int(raw["grid_height"]), {
			"blocked": 0.0, "pois": 0})
		check(regen["ok"], "bölüm %d seed yeniden üretilebilir" % (i + 1))


func test_town_model() -> void:
	var save := {"last_completed_level": 0, "currencies": {"gold": 0, "trade_goods": 0}, "building_levels": {}}
	check(TownModel.defs().size() == 3, "üç bina tanımlı")
	for b in TownModel.defs():
		check(b["cost"].size() == int(b["max_level"]), "%s: her seviye için bedel" % b["id"])
	check(TownModel.is_unlocked(save, "kervansaray"), "kervansaray ilk oturumda açık")
	check(TownModel.block_reason(save, "kervansaray") == "gold", "altın yoksa kurulamaz")
	check(TownModel.block_reason(save, "pazar") == "locked", "pazar 5. bölüme kadar kilitli")
	# İlk anlamlı yükseltme yalnız bulmaca altınıyla: 2 bölüm (ilk tamamlanma) yetmeli
	var l1 := LevelData.from_dict({"level_id": "a", "difficulty_score": 1})
	var two_levels: int = 2 * load("res://scripts/autoload/game_state.gd").puzzle_gold(l1, true, 2, 0)
	check(two_levels >= int(TownModel.next_cost(save, "kervansaray")["gold"]), "ilk bina 2 bölüm altınıyla kurulur (%d)" % two_levels)
	save["currencies"]["gold"] = 1000
	save["currencies"]["trade_goods"] = 10
	check(TownModel.upgrade(save, "kervansaray") and TownModel.level_of(save, "kervansaray") == 1, "kervansaray kuruldu")
	check(int(save["currencies"]["gold"]) == 980, "bedel düşüldü")
	save["last_completed_level"] = 8
	check(TownModel.upgrade(save, "pazar"), "pazar kuruldu")
	check(TownModel.block_reason(save, "pazar") == "town_level", "pazar kervansaray seviyesini geçemez")
	check(TownModel.gold_bonus_percent(save) == 10, "pazar 1: +%10")
	check(TownModel.upgrade(save, "kuyu") and TownModel.journey_tolerance(save) == 1, "kuyu 1: +1 çarpma hakkı")
	var before := JSON.stringify(save)
	save["currencies"]["trade_goods"] = 0
	check(TownModel.block_reason(save, "kervansaray") == "trade_goods" and not TownModel.upgrade(save, "kervansaray"), "ticaret malı yetmezse yükseltme yok")
	save["currencies"]["trade_goods"] = 10
	for i in range(5):
		TownModel.upgrade(save, "kervansaray")
	check(TownModel.level_of(save, "kervansaray") == 3 and TownModel.block_reason(save, "kervansaray") == "max", "en fazla 3. seviye")
	save["currencies"]["gold"] = int(save["currencies"]["gold"]) + 1000
	check(TownModel.upgrade(save, "pazar") and TownModel.upgrade(save, "pazar") and TownModel.gold_bonus_percent(save) == 30, "pazar 3: +%30")
	check(int(save["currencies"]["gold"]) >= 0 and int(save["currencies"]["trade_goods"]) >= 0, "para birimi eksiye düşmez")
	# Yolculuk toleransı modele geçer
	var jm := JourneyModel.new(1, 8, "easy", TownModel.journey_tolerance(save))
	check(jm.max_hits == JourneyModel.MAX_HITS + TownModel.journey_tolerance(save), "kuyu toleransı yolculukta")


func test_junction() -> void:
	var TD := TileDefs
	check(TD.mask_of(TD.Type.JUNCTION, 0) == TD.N | TD.E | TD.S, "kavşak 0: K-D-G")
	check(TD.mask_of(TD.Type.JUNCTION, 1) == TD.E | TD.S | TD.W, "kavşak 1")
	for r in range(4):
		check(TD.type_for_mask(TD.mask_of(TD.Type.JUNCTION, r)) == TD.Type.JUNCTION, "kavşak maskesi tanınır %d" % r)
	var base := {"level_id": "j", "grid_width": 5, "grid_height": 5, "start_cell": [0, 2], "goal_cell": [4, 2],
			"points_of_interest": [[2, 0]], "blocked_cells": [], "move_limit": 99, "star_thresholds": [99, 99]}
	var no_j := base.duplicate(true)
	no_j["tile_pool"] = {"straight": 10, "corner": 10}
	var with_j := base.duplicate(true)
	with_j["tile_pool"] = {"straight": 10, "corner": 10, "junction": 1}
	var a := RouteSolver.solve(LevelData.from_dict(no_j))
	var b := RouteSolver.solve(LevelData.from_dict(with_j))
	check(a["solvable"] and a["min_moves"] == 6, "kavşaksız en az 6 parça (%d)" % a["min_moves"])
	check(b["solvable"] and b["min_moves"] == 4, "kavşakla 4 parça (%d)" % b["min_moves"])
	var used_j := false
	for p in b["placements"]:
		used_j = used_j or p["type"] == TD.Type.JUNCTION
	check(used_j, "çözüm kavşak kullanıyor")
	# Oyunda: kavşaklı çözüm iki hedefi de bağlar
	var l := LevelData.from_dict(with_j)
	var m := BoardModel.new(l, 999)
	for p in b["placements"]:
		check(m.place_from_tray(p["type"], p["cell"]), "yerleşti %s" % p["cell"])
		var g := 0
		while m.cell_mask(p["cell"]) != TD.mask_of(p["type"], p["rot"]) and g < 4:
			m.rotate_tile(p["cell"])
			g += 1
	check(m.is_complete(), "kavşaklı rota oyunda tamam")
	check(m.tray_count(TD.Type.JUNCTION) == 0, "kavşak tepsiden düştü")
	# Hub'dan dallanma: başlangıç iki yöne ayrılabilir (kavşak gerekmez)
	var hub := {"level_id": "h", "grid_width": 5, "grid_height": 5, "start_cell": [2, 2], "goal_cell": [4, 2],
			"points_of_interest": [[0, 2]], "blocked_cells": [], "tile_pool": {"straight": 4, "corner": 0},
			"move_limit": 99, "star_thresholds": [99, 99]}
	var h := RouteSolver.solve(LevelData.from_dict(hub))
	check(h["solvable"] and h["min_moves"] == 2, "başlangıçtan iki yöne dallanma: 2 parça (%d)" % h["min_moves"])
	# Seviye dosyalarında en az bir kavşak öğretim bölümü
	var found := false
	for lv in all_levels():
		if lv.tutorial_key == "TUT_JUNCTION":
			found = int(lv.tile_pool.get(TD.Type.JUNCTION, 0)) > 0
	check(found, "kavşak öğretim bölümü var ve kavşak içeriyor")


func test_audio_assets() -> void:
	var am = load("res://scripts/autoload/audio_manager.gd")
	for n in am.SFX_NAMES:
		check(ResourceLoader.exists(am.SFX_PATH % n), "efekt dosyası var: %s" % n)
	for n in am.MUSIC_NAMES:
		check(ResourceLoader.exists(am.MUSIC_PATH % n), "müzik dosyası var: %s" % n)
	# Koddaki her play_sfx / play_music çağrısı tanımlı bir sese gitmeli.
	var re := RegEx.create_from_string("play_(sfx|music)\\(\"([a-z0-9_]+)\"")
	var re_bind := RegEx.create_from_string("play_sfx\\.bind\\(\"([a-z0-9_]+)\"")
	var files := ["res://scripts/scenes/puzzle_board.gd", "res://scripts/scenes/journey.gd", "res://scripts/scenes/town.gd",
			"res://scripts/scenes/result_screen.gd", "res://scripts/scenes/level_select.gd", "res://scripts/ui/ui_kit.gd"]
	var seen := 0
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			seen += 1
			var list: Array = am.SFX_NAMES if m.get_string(1) == "sfx" else am.MUSIC_NAMES
			check(list.has(m.get_string(2)), "%s: tanımsız ses '%s'" % [f.get_file(), m.get_string(2)])
		for m in re_bind.search_all(src):
			seen += 1
			check(am.SFX_NAMES.has(m.get_string(1)), "%s: tanımsız ses '%s'" % [f.get_file(), m.get_string(1)])
	check(seen >= 10, "koddaki ses çağrıları bulundu (%d)" % seen)
	for k in am.SFX_DB:
		check(am.SFX_NAMES.has(k), "ses düzeyi tablosunda bilinmeyen efekt: %s" % k)
	check(FileAccess.file_exists("res://docs/lisanslar.md"), "lisans envanteri var")
