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


func _ready() -> void:
	level_index = GameState.current_level_index
	level = GameState.levels[level_index]
	model = BoardModel.new(level)

	var box := UiKit.build_screen(self, 20)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var back := UiKit.button(tr("BACK"), SceneRouter.goto_menu, 100)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 200
	top.add_child(back)
	var title := UiKit.label(tr("LEVEL_N") % (level_index + 1), 48)
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
	canvas.show_hint = GameState.fail_count(level_index) >= level.assist_after_fail_count
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
	model.reset()
	_set_info_default()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
