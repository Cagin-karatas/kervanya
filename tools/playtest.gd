extends SceneTree
## Otomatik oyun testi: oyunu açılıştan başlatır, telefondaki gibi dokunma olayları
## (InputEventScreenTouch / ScreenDrag -> fare taklidi) gönderir, ekran görüntüsü alır.
##
## Kullanım (görüntü için sanal ekran gerekir):
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 \
##       -s tools/playtest.gd -- <çıktı_klasörü> <mod>
## Modlar:
##   full     : temiz kayıtla tüm senaryolar (kenar durumları, 10 bölüm, başarısızlık+ipucu, Türkçe)
##   persist  : önceki "full" koşusunun kaydı yeni süreçte korunmuş mu
##   layout   : bu çözünürlükte menü / bölüm 1 / bölüm 10 yerleşim kontrolü

var out_dir := "user://playtest"
var mode := "full"
var passed := 0
var failed := 0
var notes: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Input.use_accumulated_input = false
	_main.call_deferred()


func _main() -> void:
	await frames(3)
	match mode:
		"full":
			await run_full()
		"persist":
			await run_persist()
		"layout":
			await run_layout()
		"editor":
			await run_editor()
	print("\nSONUÇ [%s] %d geçti, %d başarısız" % [mode, passed, failed])
	for n in notes:
		print("  not: " + n)
	quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ yardımcılar

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  BAŞARISIZ: " + msg)


func frames(n: int = 1) -> void:
	for i in range(n):
		await process_frame


func shot(file_name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))


func gs() -> Node:
	return root.get_node("GameState")


func to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func touch(p: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = to_window(p)
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await frames(2)


func drag_path(a: Vector2, b: Vector2, release := true, steps := 8) -> void:
	await touch(a, true)
	var prev := a
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = to_window(p)
		ev.relative = to_window(p) - to_window(prev)
		Input.parse_input_event(ev)
		prev = p
		await frames(1)
	if release:
		await touch(b, false)


func tap(p: Vector2, jitter := Vector2.ZERO) -> void:
	await touch(p, true)
	if jitter != Vector2.ZERO:
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = to_window(p + jitter)
		ev.relative = to_window(p + jitter) - to_window(p)
		Input.parse_input_event(ev)
		await frames(1)
	await touch(p + jitter, false)


func find_button(text: String) -> Button:
	for b in current_scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func tap_button(text: String) -> bool:
	var b := find_button(text)
	if b == null:
		check(false, "buton bulunamadı: " + text)
		return false
	await tap(b.get_global_rect().get_center())
	return true


func wait_scene(scene_name: String, max_frames := 240) -> bool:
	for i in range(max_frames):
		if current_scene != null and current_scene.name == scene_name:
			await frames(2)
			return true
		await process_frame
	check(false, "sahne açılmadı: " + scene_name + " (şu an: %s)" % (current_scene.name if current_scene else "yok"))
	return false


func t(key: String) -> String:
	return TranslationServer.translate(key)


# Tuval içi noktaları kök görünüm koordinatına çevir.
func slot_pos(canvas: PuzzleCanvas, type: int) -> Vector2:
	return canvas.get_global_transform() * canvas._slot_rects[type].get_center()


func cell_pos(canvas: PuzzleCanvas, c: Vector2i) -> Vector2:
	return canvas.get_global_transform() * canvas.cell_rect(c).get_center()


## Parmağın bırakılacağı nokta: sürüklenen parça parmağın üstünde durduğu için
## oyuncu gölgeyi kareye hizalar, parmak karenin biraz altında kalır.
func drop_pos(canvas: PuzzleCanvas, c: Vector2i) -> Vector2:
	return canvas.get_global_transform() * (canvas.cell_rect(c).get_center() - canvas.ghost_offset())


func open_level_from_menu(n: int) -> bool:
	if not await wait_scene("LevelSelect"):
		return false
	await tap_button(str(n))
	return await wait_scene("PuzzleBoard")


## Bölümü kayıtlı çözümle, gerçek dokunuşlarla oynar.
func play_solution(board: Node) -> void:
	var canvas: PuzzleCanvas = board.canvas
	for p in board.level.solution:
		await drag_path(slot_pos(canvas, p["type"]), drop_pos(canvas, p["cell"]))
		var guard := 0
		while board.model.has_tile(p["cell"]) and board.model.cell_mask(p["cell"]) != TileDefs.mask_of(p["type"], p["rot"]) and guard < 4 and not board.model.is_finished():
			await tap(cell_pos(canvas, p["cell"]))
			guard += 1


# ------------------------------------------------------------------ senaryolar

func run_full() -> void:
	var sm = root.get_node("SaveManager")
	for p in [sm.save_path, sm.backup_path(), sm.tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	gs().data = sm.load_data()
	root.get_node("AnalyticsService").clear()
	change_scene_to_file("res://scenes/level_select.tscn")
	await wait_scene("LevelSelect")
	await shot("01_menu_temiz")
	check(find_button("1") != null and not find_button("1").disabled, "bölüm 1 açık")
	check(find_button("2") != null and find_button("2").disabled, "bölüm 2 kilitli")

	# --- Kenar durumları (bölüm 1)
	await open_level_from_menu(1)
	var board: Node = current_scene
	var canvas: PuzzleCanvas = board.canvas
	var m: BoardModel = board.model
	var S := TileDefs.Type.STRAIGHT
	var lvl: LevelData = board.level

	await drag_path(slot_pos(canvas, S), drop_pos(canvas, lvl.start_cell))
	check(m.tray_count(S) == 3 and m.moves_used == 0, "başlangıç köyüne bırakma reddedilir")
	await drag_path(slot_pos(canvas, S), slot_pos(canvas, TileDefs.Type.CORNER))
	check(m.tray_count(S) == 3 and m.moves_used == 0, "tepsiye geri bırakma değişiklik yapmaz")
	await drag_path(slot_pos(canvas, S), drop_pos(canvas, Vector2i(1, 1)))
	check(m.has_tile(Vector2i(1, 1)) and m.tray_count(S) == 2 and m.moves_used == 1, "tepsiden yerleştirme")
	var rot_before: int = m.tiles[Vector2i(1, 1)]["rot"] if m.has_tile(Vector2i(1, 1)) else -1
	await tap(cell_pos(canvas, Vector2i(1, 1)), Vector2(6, 4))
	check(m.has_tile(Vector2i(1, 1)) and m.tiles[Vector2i(1, 1)]["rot"] != rot_before and m.moves_used == 2,
			"titrek dokunuş taşıma değil döndürme sayılır")
	await drag_path(cell_pos(canvas, Vector2i(1, 1)), drop_pos(canvas, Vector2i(3, 3)))
	check(m.has_tile(Vector2i(3, 3)) and not m.has_tile(Vector2i(1, 1)) and m.moves_used == 3, "parça taşıma")
	await drag_path(cell_pos(canvas, Vector2i(3, 3)), slot_pos(canvas, S))
	check(not m.has_tile(Vector2i(3, 3)) and m.tray_count(S) == 3 and m.moves_used == 3, "tepsiye geri sürükleme")
	await tap_button(t("UNDO"))
	check(m.has_tile(Vector2i(3, 3)) and m.tray_count(S) == 2, "geri al butonu")
	# Sürükleme sırasında uygulama arka plana geçer.
	await drag_path(slot_pos(canvas, S), drop_pos(canvas, Vector2i(2, 4)), false)
	canvas.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await touch(drop_pos(canvas, Vector2i(2, 4)), false)
	check(not m.has_tile(Vector2i(2, 4)) and m.tray_count(S) == 2, "arka plana geçişte sürükleme iptal, parça kaybı yok")
	# Sürüklerken ikinci parmak.
	await drag_path(slot_pos(canvas, S), drop_pos(canvas, Vector2i(2, 4)), false)
	await touch(cell_pos(canvas, Vector2i(0, 0)), true, 1)
	await touch(cell_pos(canvas, Vector2i(0, 0)), false, 1)
	await touch(drop_pos(canvas, Vector2i(2, 4)), false)
	check(m.tray_count(S) + m.placed_count(S) == 3, "ikinci parmak parça sayısını bozmaz")
	notes.append("ikinci parmakla sürükleme sonucu: kare (2,4) %s" % ("dolu" if m.has_tile(Vector2i(2, 4)) else "boş"))
	# Hızlı art arda dokunuşlar.
	var before := m.signature()
	for i in range(2):
		await touch(cell_pos(canvas, Vector2i(3, 3)), true)
		await touch(cell_pos(canvas, Vector2i(3, 3)), false)
	check(m.tray_count(S) + m.placed_count(S) == 3 and m.has_tile(Vector2i(3, 3)), "hızlı dokunuşlar parça kaybettirmez")
	check(m.signature() != before, "hızlı dokunuşlar döndürme olarak işlendi")
	await shot("02_bolum1_kenar_durumlari")
	await tap_button(t("RESTART"))
	check(m.moves_used == 0 and m.tiles.is_empty() and m.tray_count(S) == 3, "baştan butonu")
	board.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(await wait_scene("LevelSelect"), "geri tuşu menüye döner")

	# --- 10 bölümü baştan sona oyna
	await open_level_from_menu(1)
	var n_levels: int = gs().level_count()
	for i in range(n_levels):
		board = current_scene
		var t0 := Time.get_ticks_msec()
		await play_solution(board)
		var used: int = board.model.moves_used
		var limit: int = board.level.move_limit
		check(board.model.is_complete(), "bölüm %d dokunuşlarla tamamlandı" % (i + 1))
		if i == 0 or i == 7:
			await shot("03_bolum%d_tamam" % (i + 1))
		if not await wait_scene("ResultScreen"):
			return
		var r: Dictionary = gs().last_result
		check(r.get("won", false) and r.get("stars", 0) == 3, "bölüm %d: kazanıldı, 3 yıldız (yıldız=%s, hamle=%d)" % [i + 1, r.get("stars"), used])
		notes.append("bölüm %d: %d hamle / limit %d, %d yıldız, %d ms" % [i + 1, used, limit, r.get("stars", 0), Time.get_ticks_msec() - t0])
		if i == 0:
			await shot("04_sonuc_bolum1")
		if i < n_levels - 1:
			await tap_button(t("NEXT"))
			await wait_scene("PuzzleBoard")
	check(find_button(t("NEXT")) == null, "son bölümde 'sonraki' yok")
	await shot("05_sonuc_son_bolum")
	check(int(gs().data["last_completed_level"]) == n_levels, "kayıtta tüm bölümler bitti")
	await tap_button(t("MENU"))
	await wait_scene("LevelSelect")
	var all_open := true
	for i in range(n_levels):
		var b := find_button(str(i + 1))
		all_open = all_open and b != null and not b.disabled
	check(all_open, "tüm bölümler açıldı")
	await shot("06_menu_hepsi_acik")

	# --- Hamle bitimi, 3 başarısızlık ve ipucu (bölüm 5)
	await open_level_from_menu(5)
	for attempt in range(3):
		board = current_scene
		canvas = board.canvas
		m = board.model
		var c: Vector2i = board.level.solution[0]["cell"]
		await drag_path(slot_pos(canvas, board.level.solution[0]["type"]), drop_pos(canvas, c))
		var guard := 0
		while not m.is_finished() and guard < 30:
			await tap(cell_pos(canvas, c))
			guard += 1
		check(m.is_failed(), "deneme %d: hamle bitince başarısız" % (attempt + 1))
		await wait_scene("ResultScreen")
		check(not gs().last_result.get("won", true), "başarısız sonuç ekranı")
		if attempt == 0:
			await shot("07_hamle_bitti")
		await tap_button(t("RETRY"))
		await wait_scene("PuzzleBoard")
	board = current_scene
	check(board.canvas.show_hint, "3 başarısızlık sonrası ipucu görünür")
	await shot("08_ipucu")
	await play_solution(board)
	check(board.model.is_complete(), "ipucuyla bölüm 5 tamamlandı")
	await wait_scene("ResultScreen")

	# --- Türkçe
	await tap_button(t("MENU"))
	TranslationServer.set_locale("tr")
	await open_level_from_menu(8)
	board = current_scene
	check(find_button("Geri al") != null and find_button("Baştan") != null, "Türkçe butonlar")
	# Sürükleme anında ekran görüntüsü + kaba performans ölçümü
	canvas = board.canvas
	var sol0: Dictionary = board.level.solution[0]
	await drag_path(slot_pos(canvas, sol0["type"]), drop_pos(canvas, sol0["cell"]), false)
	await shot("09_turkce_surukleme")
	var t_start := Time.get_ticks_usec()
	for i in range(120):
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = to_window(drop_pos(canvas, sol0["cell"]) + Vector2(sin(i * 0.2) * 150.0, 0))
		Input.parse_input_event(ev)
		await process_frame
	var avg_ms := (Time.get_ticks_usec() - t_start) / 120.0 / 1000.0
	notes.append("sürükleme sırasında ortalama kare süresi (sanal ekran, yazılımsal GL): %.2f ms" % avg_ms)
	await touch(drop_pos(canvas, sol0["cell"]), false)

	# --- Analitik kaydı ve gizli test raporu
	current_scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await wait_scene("LevelSelect")
	var evs: Array = root.get_node("AnalyticsService").read_events()
	var counts := {}
	for e in evs:
		counts[e["event"]] = int(counts.get(e["event"], 0)) + 1
	notes.append("kaydedilen olaylar: %s" % JSON.stringify(counts))
	check(int(counts.get("level_complete", 0)) == 11, "10 bölüm + bölüm 5 tekrarı = 11 level_complete")
	check(int(counts.get("level_fail", 0)) == 3, "3 level_fail")
	check(counts.has("tile_placed") and counts.has("tile_rotated") and counts.has("tile_undo") and counts.has("level_restart") and counts.has("level_quit") and counts.has("assist_triggered") and counts.has("tutorial_complete"), "beklenen olay türleri kaydedildi")
	var title: Control = null
	for l in current_scene.find_children("*", "Label", true, false):
		if l.text == "KERVANYA":
			title = l
	for i in range(5):
		await tap(title.get_global_rect().get_center())
	check(await wait_scene("TestReport"), "başlığa 5 dokunuş test raporunu açar")
	await shot("11_test_raporu")
	var testers := TestReport.build(root.get_node("AnalyticsService").read_events())
	check(testers.size() == 1 and testers[0]["reached_level3_s"] >= 0, "rapor: testçi 1 3. bölüme ulaştı")
	await tap_button("Yeni testçi")
	check(current_scene.name == "TestReport", "ilk dokunuş sadece onay ister")
	await tap_button("Emin misin?")
	check(await wait_scene("LevelSelect"), "yeni testçi menüye döner")
	check(int(gs().data["test_tester"]) == 2 and int(gs().data["last_completed_level"]) == 0, "testçi 2, ilerleme sıfır")
	check(find_button("2") != null and find_button("2").disabled, "yeni testçide bölüm 2 kilitli")


func run_persist() -> void:
	var d: Dictionary = gs().data
	check(int(d["last_completed_level"]) == gs().level_count(), "yeniden açılışta ilerleme korundu (%s)" % d["last_completed_level"])
	var three := 0
	for k in d["level_stars"]:
		if int(d["level_stars"][k]) == 3:
			three += 1
	check(three == gs().level_count(), "yeniden açılışta yıldızlar korundu (%d x 3 yıldız)" % three)
	change_scene_to_file("res://scenes/level_select.tscn")
	await wait_scene("LevelSelect")
	await shot("10_yeniden_acilis_menu")


func run_layout() -> void:
	var vp := root.get_visible_rect()
	var tag := "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	notes.append("pencere %s -> mantıksal görünüm %dx%d" % [tag, vp.size.x, vp.size.y])
	change_scene_to_file("res://scenes/level_select.tscn")
	await wait_scene("LevelSelect")
	_check_controls_inside(vp, "menü")
	await shot("layout_%s_menu" % tag)
	for n in [1, 10]:
		gs().current_level_index = n - 1
		change_scene_to_file("res://scenes/puzzle_board.tscn")
		await wait_scene("PuzzleBoard")
		var canvas: PuzzleCanvas = current_scene.canvas
		var lvl: LevelData = current_scene.level
		var board_rect := Rect2(canvas._origin, Vector2(lvl.grid_width, lvl.grid_height) * canvas._cell)
		var local := Rect2(Vector2.ZERO, canvas.size)
		check(local.encloses(board_rect), "%s bölüm %d: tahta tuvalin içinde" % [tag, n])
		for s in canvas._slot_rects.values():
			check(local.encloses(s), "%s bölüm %d: tepsi tuvalin içinde" % [tag, n])
		check(not board_rect.intersects(canvas._tray_rect), "%s bölüm %d: tahta ve tepsi çakışmıyor" % [tag, n])
		_check_controls_inside(vp, "bölüm %d" % n)
		var cell_px: float = canvas._cell * root.get_final_transform().get_scale().x
		notes.append("%s bölüm %d: kare %.0f mantıksal birim = %.0f ekran pikseli" % [tag, n, canvas._cell, cell_px])
		check(canvas._cell >= 110.0, "%s bölüm %d: kare dokunma için yeterince büyük (%.0f)" % [tag, n, canvas._cell])
		await shot("layout_%s_bolum%d" % [tag, n])


func _check_controls_inside(vp: Rect2, where: String) -> void:
	for c in current_scene.find_children("*", "Control", true, false):
		if c is Button or c is Label:
			if c.is_visible_in_tree() and not vp.grow(1.0).encloses(c.get_global_rect()):
				check(false, "%s: '%s' ekran dışına taşıyor %s" % [where, c.get("text"), c.get_global_rect()])
				return
	check(true, where)


func run_editor() -> void:
	var an = root.get_node("AnalyticsService")
	var events_before: int = an.read_events().size()
	change_scene_to_file("res://scenes/level_editor.tscn")
	await wait_scene("LevelEditor")
	var ed: Node = current_scene
	var g: EditorGrid = ed.grid
	await shot("e1_editor_bos")
	# Kapalı kare boya: (2,1),(2,2),(2,3) sürükleyerek
	var gt := g.get_global_transform()
	g._layout()
	var p := func(c: Vector2i) -> Vector2: return gt * g._rect(c).get_center()
	await drag_path(p.call(Vector2i(2, 1)), p.call(Vector2i(2, 3)), true, 12)
	check(g.data["blocked_cells"].size() == 3, "sürükleyerek 3 kapalı kare boyandı (%d)" % g.data["blocked_cells"].size())
	await tap_button("Çöz")
	check(ed.status.text.begins_with("Çözülebilir"), "çöz: %s" % ed.status.text)
	check(g.solution.size() > 0, "çözüm önizlemesi çizildi")
	await shot("e2_editor_cozum")
	# Çözümsüz durum: tüm sütunu kapat
	await drag_path(p.call(Vector2i(2, 0)), p.call(Vector2i(2, 4)), true, 12)
	await tap_button("Çöz")
	check(ed.status.text.begins_with("Sorun"), "kapalı sütunla çözümsüz: %s" % ed.status.text)
	# Rastgele üretim
	ed.spins["w"].value = 6
	ed.spins["h"].value = 6
	ed.spins["pois"].value = 1
	ed.spins["seed"].value = 42
	await tap_button("Rastgele")
	check(ed.status.text.contains("Seed 42 üretildi") and ed.status.text.contains("Çözülebilir"), "rastgele: %s" % ed.status.text)
	var draft_json := JSON.stringify(gs().editor_draft)
	await shot("e3_editor_rastgele")
	# Dene: bölümü oyna ve editöre dön
	await tap_button("Dene")
	check(await wait_scene("PuzzleBoard"), "Dene bulmaca ekranını açar")
	await play_solution(current_scene)
	check(current_scene.model.is_complete(), "editör bölümü dokunuşlarla çözüldü")
	await shot("e4_editor_dene")
	check(await wait_scene("LevelEditor", 400), "Dene bitince editöre döner")
	check(gs().test_level == null, "test bölümü temizlendi")
	check(JSON.stringify(gs().editor_draft) == draft_json, "taslak korundu")
	check(an.read_events().size() == events_before, "editör testi analitiğe yazılmadı")
	# Kaydet: yeni numaraya yaz, sonra geri al
	ed = current_scene
	var n: int = gs().level_count() + 1
	ed.number_spin.value = n
	await tap_button("Kaydet")
	var path := "res://levels/level_%03d.json" % n
	check(FileAccess.file_exists(path) and gs().level_count() == n, "bölüm %d kaydedildi ve kataloğa eklendi" % n)
	if FileAccess.file_exists(path):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(saved["level_id"] == "w1_c1_l%03d" % n and saved.has("solution"), "kayıtlı bölüm kimliği ve çözümü")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		gs().load_levels()
	# Yükle
	ed.number_spin.value = 8
	await tap_button("Yükle")
	check(ed.status.text.begins_with("Bölüm 8 yüklendi") and gs().editor_draft["level_id"] == "w1_c1_l008", "bölüm 8 yüklendi")
	await shot("e5_editor_yukle")
