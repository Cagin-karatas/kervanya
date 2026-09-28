extends Control
## Bölüm editörü (planın 18. görevi): yeni bölüm kod yazmadan, çözücü kontrolüyle üretilir.
## Godot editöründe çalışırken levels/ klasörüne kaydeder; telefonda/web'de yalnız dener.

const LEVEL_PATH := "res://levels/level_%03d.json"
const TOOLS := [["Boş", "empty"], ["Kapalı", "blocked"], ["Başlangıç", "start"], ["Hedef", "goal"], ["Pazar", "poi"]]

var grid: EditorGrid
var status: Label
var spins: Dictionary = {}
var number_spin: SpinBox
var _syncing := false


static func default_draft() -> Dictionary:
	return {
		"level_id": "taslak", "content_version": 1, "world_id": 1, "chapter_id": 1,
		"grid_width": 5, "grid_height": 5, "start_cell": [0, 2], "goal_cell": [4, 2],
		"blocked_cells": [], "points_of_interest": [],
		"tile_pool": {"straight": 4, "corner": 4}, "move_slack": 4,
		"difficulty_score": 2, "rhythm": "", "template_id": "", "tutorial_key": "",
		"assist_after_fail_count": 3,
	}


func _ready() -> void:
	if GameState.editor_draft.is_empty():
		GameState.editor_draft = default_draft()
	var box := UiKit.build_screen(self, 14)

	var top := HBoxContainer.new()
	var title := UiKit.label("Bölüm editörü", 52, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var menu := UiKit.button("Menü", SceneRouter.goto_menu, 90)
	menu.size_flags_horizontal = Control.SIZE_FILL
	menu.custom_minimum_size.x = 180
	top.add_child(menu)
	box.add_child(top)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for t in TOOLS:
		var b := UiKit.button(t[0], _set_tool.bind(t[1]), 90)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t[1] == "blocked"
		b.add_theme_font_size_override("font_size", 32)
		tools.add_child(b)
	box.add_child(tools)

	grid = EditorGrid.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.data = GameState.editor_draft
	grid.edited.connect(_on_grid_edited)
	box.add_child(grid)

	_syncing = true
	var params := GridContainer.new()
	params.columns = 6
	params.add_theme_constant_override("h_separation", 10)
	params.add_theme_constant_override("v_separation", 8)
	for p in [["Genişlik", "w", 3, 10], ["Yükseklik", "h", 3, 10], ["Zorluk", "difficulty", 1, 10],
			["Düz", "straight", 0, 40], ["Köşe", "corner", 0, 40], ["Hamle payı", "slack", 0, 20],
			["Seed", "seed", 1, 999999], ["Kapalı %", "density", 0, 40], ["Pazar", "pois", 0, 3]]:
		var l := UiKit.label(p[0], 28, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		params.add_child(l)
		var s := SpinBox.new()
		s.min_value = p[2]
		s.max_value = p[3]
		s.custom_minimum_size = Vector2(170, 76)
		s.get_line_edit().add_theme_font_size_override("font_size", 32)
		s.value_changed.connect(_on_param_changed.unbind(1))
		params.add_child(s)
		spins[p[1]] = s
	box.add_child(params)

	status = UiKit.label("", 28, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	status.custom_minimum_size.y = 120
	box.add_child(status)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	row1.add_child(UiKit.button("Rastgele", _on_random, 100))
	row1.add_child(UiKit.button("Çöz", _on_solve, 100))
	row1.add_child(UiKit.button("Dene", _on_try, 100))
	box.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	var num_label := UiKit.label("Bölüm", 30, UiKit.MUTED)
	num_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row2.add_child(num_label)
	number_spin = SpinBox.new()
	number_spin.min_value = 1
	number_spin.max_value = GameState.level_count() + 1
	number_spin.value = GameState.level_count() + 1
	number_spin.custom_minimum_size = Vector2(200, 90)
	number_spin.get_line_edit().add_theme_font_size_override("font_size", 34)
	row2.add_child(number_spin)
	row2.add_child(UiKit.button("Yükle", _on_load, 100))
	row2.add_child(UiKit.button("Kaydet", _on_save, 100))
	row2.add_child(UiKit.button("Yeni", _on_new, 100))
	box.add_child(row2)

	spins["seed"].value = 1
	spins["density"].value = 15
	_syncing = false
	_sync_spins_from_draft()
	status.text = "Kare boyamak için araç seç ve tahtaya dokun. Sonra Çöz, Dene veya Kaydet."


func draft() -> Dictionary:
	return GameState.editor_draft


func _set_tool(t: String) -> void:
	grid.tool = t


func _sync_spins_from_draft() -> void:
	_syncing = true
	var d := draft()
	spins["w"].value = d["grid_width"]
	spins["h"].value = d["grid_height"]
	spins["straight"].value = d["tile_pool"].get("straight", 0)
	spins["corner"].value = d["tile_pool"].get("corner", 0)
	spins["slack"].value = d.get("move_slack", 4)
	spins["difficulty"].value = d.get("difficulty_score", 1)
	_syncing = false
	grid.data = d
	grid.queue_redraw()


func _on_param_changed() -> void:
	if _syncing:
		return
	var d := draft()
	d["grid_width"] = int(spins["w"].value)
	d["grid_height"] = int(spins["h"].value)
	d["tile_pool"] = {"straight": int(spins["straight"].value), "corner": int(spins["corner"].value)}
	d["move_slack"] = int(spins["slack"].value)
	d["difficulty_score"] = int(spins["difficulty"].value)
	_clip_to_grid(d)
	grid.solution = []
	grid.queue_redraw()


## Izgara küçülünce dışarıda kalan kareleri temizle, başlangıç/hedefi içeri çek.
func _clip_to_grid(d: Dictionary) -> void:
	var gw: int = d["grid_width"]
	var gh: int = d["grid_height"]
	for key in ["blocked_cells", "points_of_interest"]:
		var keep := []
		for v in d[key]:
			if int(v[0]) < gw and int(v[1]) < gh:
				keep.append(v)
		d[key] = keep
	for key in ["start_cell", "goal_cell"]:
		d[key] = [mini(int(d[key][0]), gw - 1), mini(int(d[key][1]), gh - 1)]


func _on_grid_edited() -> void:
	status.text = ""


func _bake() -> Dictionary:
	var r := LevelBaker.bake(draft())
	if r["ok"]:
		var sol: Array = []
		for p in r["data"]["solution"]:
			sol.append({"cell": Vector2i(p["cell"][0], p["cell"][1]),
					"type": TileDefs.type_from_name(p["type"]), "rot": int(p["rot"])})
		grid.solution = sol
		var d: Dictionary = r["data"]
		status.text = "Çözülebilir. En kısa rota: %d parça · Hamle limiti: %d · 3 yıldız: en fazla %d hamle" % [
			r["min_moves"], d["move_limit"], d["star_thresholds"][0]]
	else:
		grid.solution = []
		status.text = "Sorun: " + "; ".join(r["errors"])
	grid.queue_redraw()
	return r


func _on_solve() -> void:
	_bake()


func _on_random() -> void:
	var seed := int(spins["seed"].value)
	var r := LevelBaker.generate(seed, int(spins["w"].value), int(spins["h"].value), {
		"blocked": spins["density"].value / 100.0, "pois": int(spins["pois"].value),
		"move_slack": int(spins["slack"].value)})
	if not r["ok"]:
		status.text = "Seed %d: %s" % [seed, "; ".join(r["errors"])]
		return
	var d: Dictionary = r["data"]
	d["difficulty_score"] = int(spins["difficulty"].value)
	d["template_id"] = "gen"
	GameState.editor_draft = d
	_sync_spins_from_draft()
	_bake()
	status.text = "Seed %d üretildi. " % seed + status.text
	spins["seed"].value = seed + 1


func _on_try() -> void:
	var r := _bake()
	if r["ok"]:
		SceneRouter.play_test_level(LevelData.from_dict(r["data"]))


func _on_new() -> void:
	GameState.editor_draft = default_draft()
	number_spin.value = GameState.level_count() + 1
	_sync_spins_from_draft()
	grid.solution = []
	status.text = "Yeni bölüm."


func _on_load() -> void:
	var n := int(number_spin.value)
	var path := LEVEL_PATH % n
	if not FileAccess.file_exists(path):
		status.text = "Bölüm %d bulunamadı." % n
		return
	GameState.editor_draft = JSON.parse_string(FileAccess.get_file_as_string(path))
	_sync_spins_from_draft()
	_bake()
	status.text = "Bölüm %d yüklendi. " % n + status.text


func _on_save() -> void:
	var r := _bake()
	if not r["ok"]:
		return
	var n := int(number_spin.value)
	var d: Dictionary = r["data"]
	d["world_id"] = (n - 1) / 100 + 1
	d["chapter_id"] = ((n - 1) % 100) / 20 + 1
	d["level_id"] = "w%d_c%d_l%03d" % [d["world_id"], d["chapter_id"], n]

	# Tekrar kurallarını yeni bölümle birlikte denetle.
	var seq: Array = []
	for l in GameState.levels:
		seq.append(l)
	var nl := LevelData.from_dict(d)
	if n <= seq.size():
		seq[n - 1] = nl
	else:
		seq.append(nl)
	var warns := LevelBaker.check_sequence(seq)

	var in_editor := OS.has_feature("editor")
	var path := LEVEL_PATH % n if in_editor else "user://levels/level_%03d.json" % n
	if not in_editor:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://levels"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		status.text = "Kaydedilemedi: %s" % path
		return
	f.store_string(JSON.stringify(d, "  ", false) + "\n")
	f.close()
	GameState.editor_draft = d
	if in_editor:
		GameState.load_levels()
		number_spin.max_value = GameState.level_count() + 1
		status.text = "Bölüm %d kaydedildi (%s). " % [n, path.get_file()]
	else:
		status.text = "Taslak cihaza kaydedildi; oyuna eklemek için Godot editöründe kaydet. "
	if not warns.is_empty():
		status.text += "\nUyarı: " + " · ".join(warns)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
