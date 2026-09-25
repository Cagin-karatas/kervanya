extends Control
## Basit sonuç ekranı: kazanma/kaybetme, yıldız, hamle ve sonraki adım.


func _ready() -> void:
	var r := GameState.last_result
	var idx: int = r.get("level_index", 0)
	var won: bool = r.get("won", false)
	var box := UiKit.build_screen(self, 36)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(UiKit.label(tr("LEVEL_N") % (idx + 1), 44, UiKit.MUTED))
	box.add_child(UiKit.label(tr("WIN_TITLE") if won else tr("FAIL_TITLE"), 80, UiKit.ACCENT if won else UiKit.TEXT))
	if won:
		var stars := StarRow.new(r.get("stars", 0), 110.0)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(stars)
	box.add_child(UiKit.label(tr("MOVES_USED") % r.get("moves_used", 0), 40, UiKit.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 60
	box.add_child(spacer)
	if won:
		if idx + 1 < GameState.level_count():
			box.add_child(UiKit.button(tr("NEXT"), SceneRouter.goto_level.bind(idx + 1), 140))
		else:
			box.add_child(UiKit.label(tr("ALL_DONE"), 52, UiKit.ACCENT))
	box.add_child(UiKit.button(tr("RETRY"), SceneRouter.goto_level.bind(idx), 140))
	box.add_child(UiKit.button(tr("MENU"), SceneRouter.goto_menu, 140))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
