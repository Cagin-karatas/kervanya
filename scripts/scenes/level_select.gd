extends Control
## Prototip bölüm seçimi (ileride RegionMap sahnesiyle değişecek).


func _ready() -> void:
	var box := UiKit.build_screen(self, 32)
	box.add_child(UiKit.label("KERVANYA", 88, UiKit.ACCENT))
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
