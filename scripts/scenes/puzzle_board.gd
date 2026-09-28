extends Control
## Bulmaca ekranı: üst bilgi çubuğu, tahta/tepsi tuvali ve alt eylem çubuğu.

const END_DELAY := 0.7

var level_index: int
var level: LevelData
var model: BoardModel
var canvas: PuzzleCanvas
var moves_label: Label
var info_label: Label
var undo_button: Button
var _ending := false
var _started_ms := 0
var _is_test := false


func _ready() -> void:
	_is_test = GameState.test_level != null
	level_index = GameState.current_level_index
	level = GameState.test_level if _is_test else GameState.levels[level_index]
	model = BoardModel.new(level)

	var box := UiKit.build_screen(self, 20)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var back := UiKit.button(tr("BACK"), _on_back, 100)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 200
	top.add_child(back)
	var title := UiKit.label("Editör testi" if _is_test else tr("LEVEL_N") % (level_index + 1), 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	moves_label = UiKit.label("", 48, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	moves_label.custom_minimum_size.x = 260
	top.add_child(moves_label)
	box.add_child(top)

	info_label = UiKit.label("", 36, UiKit.MUTED)
	info_label.custom_minimum_size.y = 110
	box.add_child(info_label)

	canvas = PuzzleCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.hint = level.solution
	canvas.show_hint = not _is_test and GameState.fail_count(level_index) >= level.assist_after_fail_count
	box.add_child(canvas)
	canvas.setup(model)
	canvas.board_changed.connect(_on_board_changed)
	canvas.rejected.connect(_on_rejected)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	undo_button = UiKit.button(tr("UNDO"), _on_undo)
	bottom.add_child(undo_button)
	bottom.add_child(UiKit.button(tr("RESTART"), _on_restart))
	box.add_child(bottom)

	_set_info_default()
	_refresh()
	model.acted.connect(_on_model_acted)
	_started_ms = Time.get_ticks_msec()
	if _is_test:
		return
	if level_index == 0 and int(GameState.data.get("last_completed_level", 0)) == 0:
		AnalyticsService.track("tutorial_start", _ev())
	AnalyticsService.track("level_start", _ev())
	if canvas.show_hint:
		AnalyticsService.track("assist_triggered", _ev())


## Bu bölüme ait olayların ortak parametreleri.
func _ev(extra: Dictionary = {}) -> Dictionary:
	var d := {"level_id": level.level_id, "level_number": level_index + 1}
	d.merge(extra)
	return d


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _started_ms


func _on_model_acted(kind: String) -> void:
	if _is_test:
		return
	var names := {"place": "tile_placed", "rotate": "tile_rotated", "move": "tile_moved",
			"remove": "tile_returned", "undo": "tile_undo"}
	if names.has(kind):
		AnalyticsService.track(names[kind], _ev({"moves_left": model.moves_left()}))


func _set_info_default() -> void:
	if canvas.show_hint:
		info_label.text = tr("HINT_SHOWN")
	elif not level.tutorial_key.is_empty():
		info_label.text = tr(level.tutorial_key)
	else:
		info_label.text = ""


func _refresh() -> void:
	moves_label.text = tr("MOVES_LEFT") % model.moves_left()
	undo_button.disabled = not model.can_undo()
	canvas.queue_redraw()


func _on_board_changed() -> void:
	_refresh()
	if _ending:
		return
	if model.is_complete():
		_finish(true)
	elif model.is_failed():
		_finish(false)


func _finish(won: bool) -> void:
	_ending = true
	canvas.input_locked = true
	undo_button.disabled = true
	if _is_test:
		info_label.text = "Tamamlandı: %d hamle" % model.moves_used if won else "Hamle bitti"
		await get_tree().create_timer(END_DELAY * 2).timeout
		_leave_test()
		return
	var result := _ev({"moves_used": model.moves_used, "move_limit": model.move_limit,
			"duration_ms": _elapsed_ms()})
	if won:
		result["stars"] = level.stars_for(model.moves_used)
		AnalyticsService.track("level_complete", result)
		if level_index == 2:
			AnalyticsService.track("tutorial_complete", _ev())
	else:
		AnalyticsService.track("level_fail", result)
	await get_tree().create_timer(END_DELAY).timeout
	if won:
		GameState.record_win(level_index, model.moves_used)
	else:
		GameState.record_fail(level_index, model.moves_used)
	SceneRouter.goto_result()


func _on_rejected(reason: String) -> void:
	if reason == "no_moves":
		info_label.text = tr("NO_MOVES")
	var tw := create_tween()
	moves_label.modulate = Color(1, 0.4, 0.4)
	tw.tween_property(moves_label, "modulate", Color.WHITE, 0.4)


func _on_undo() -> void:
	if _ending:
		return
	canvas.cancel_interaction()
	model.undo()
	_set_info_default()
	_refresh()


func _on_restart() -> void:
	if _ending:
		return
	canvas.cancel_interaction()
	if not _is_test:
		AnalyticsService.track("level_restart", _ev({"moves_used": model.moves_used, "duration_ms": _elapsed_ms()}))
	_started_ms = Time.get_ticks_msec()
	model.reset()
	_set_info_default()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _on_back() -> void:
	if _is_test:
		_leave_test()
		return
	if not _ending:
		_ending = true
		AnalyticsService.track("level_quit", _ev({"moves_used": model.moves_used, "duration_ms": _elapsed_ms()}))
	SceneRouter.goto_menu()


func _leave_test() -> void:
	GameState.test_level = null
	SceneRouter.goto_level_editor()
