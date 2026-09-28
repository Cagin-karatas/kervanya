extends Node
## Sahne geçişlerinin tek noktası. Oyun ekranları birbirini doğrudan yüklemez.

const LEVEL_SELECT := "res://scenes/level_select.tscn"
const PUZZLE := "res://scenes/puzzle_board.tscn"
const RESULT := "res://scenes/result_screen.tscn"
const TEST_REPORT := "res://scenes/test_report.tscn"
const LEVEL_EDITOR := "res://scenes/level_editor.tscn"


func goto_menu() -> void:
	_change(LEVEL_SELECT)


func goto_level(index: int) -> void:
	GameState.current_level_index = clampi(index, 0, GameState.level_count() - 1)
	_change(PUZZLE)


func goto_result() -> void:
	_change(RESULT)


func goto_test_report() -> void:
	_change(TEST_REPORT)


func goto_level_editor() -> void:
	_change(LEVEL_EDITOR)


## Editördeki bölümü kayıt ve analitiğe dokunmadan oynatır.
func play_test_level(level: LevelData) -> void:
	GameState.test_level = level
	_change(PUZZLE)


func _change(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
