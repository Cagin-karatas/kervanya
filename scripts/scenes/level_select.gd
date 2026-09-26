extends Control
## Prototip bölüm seçimi (ileride RegionMap sahnesiyle değişecek).


const REPORT_TAPS := 5
const REPORT_TAP_WINDOW_MS := 3000

var _title_taps: Array[int] = []


func _ready() -> void:
	var box := UiKit.build_screen(self, 32)
	var title := UiKit.label("KERVANYA", 88, UiKit.ACCENT)
	# Gizli test raporu girişi: başlığa 3 saniye içinde 5 kez dokun.
	if ProjectSettings.get_setting("kervanya/test_tools", false):
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.gui_input.connect(_on_title_input)
	box.add_child(title)
	box.add_child(UiKit.label(tr("MENU_SUBTITLE"), 36, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for i in range(GameState.level_count()):
		grid.add_child(_level_tile(i))


func _level_tile(i: int) -> Control:
	var unlocked := GameState.is_unlocked(i)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UiKit.button(str(i + 1), SceneRouter.goto_level.bind(i), 170)
	b.disabled = not unlocked
	if not unlocked:
		b.modulate.a = 0.35  # kilitli bölümler açıkça soluk görünsün
	v.add_child(b)
	var stars := StarRow.new(GameState.stars_for_level(i), 36.0)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stars.visible = unlocked
	v.add_child(stars)
	return v


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		_title_taps.append(now)
		while not _title_taps.is_empty() and now - _title_taps[0] > REPORT_TAP_WINDOW_MS:
			_title_taps.pop_front()
		if _title_taps.size() >= REPORT_TAPS:
			_title_taps.clear()
			SceneRouter.goto_test_report()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
