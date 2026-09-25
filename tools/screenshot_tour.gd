extends SceneTree
## Ekran görüntüsü turu (görsel QA). xvfb-run ile:
##   godot --path . --rendering-driver opengl3 -s tools/screenshot_tour.gd -- <çıktı_klasörü>

var out_dir := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("kaydedildi: ", name)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.data["last_completed_level"] = 7
	gs.data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 3, "5": 1, "6": 3, "7": 2}
	change_scene_to_file("res://scenes/level_select.tscn")
	await _shot("01_menu")

	gs.current_level_index = 0
	change_scene_to_file("res://scenes/puzzle_board.tscn")
	await _shot("02_level1_empty")

	gs.current_level_index = 7
	change_scene_to_file("res://scenes/puzzle_board.tscn")
	await process_frame
	await process_frame
	var board = current_scene
	var sol: Array = board.level.solution
	for i in range(5):
		board.model.place_from_tray(sol[i]["type"], sol[i]["cell"])
	board._refresh()
	var canvas: PuzzleCanvas = board.canvas
	var target: Vector2i = sol[6]["cell"]
	canvas._drag = {"source": "tray", "type": sol[6]["type"], "rot": 0,
			"pos": canvas.cell_rect(target).get_center() - canvas.ghost_offset()}
	canvas.queue_redraw()
	await _shot("03_level8_drag")
	canvas.cancel_interaction()

	gs.record_win(7, 11)
	change_scene_to_file("res://scenes/result_screen.tscn")
	await _shot("04_result")
	quit()
