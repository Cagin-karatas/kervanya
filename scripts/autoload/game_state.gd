extends Node
## Oyunun oturum durumu: bölüm kataloğu, kayıt verisi, seçili bölüm ve son sonuç.

const LEVEL_PATH := "res://levels/level_%03d.json"

var levels: Array[LevelData] = []
var data: Dictionary = {}
var current_level_index: int = 0
var last_result: Dictionary = {}
## Bölüm editöründen "Dene" ile açılan geçici bölüm; doluysa bulmaca ekranı bunu oynar.
var test_level: LevelData = null
## Bölüm editörünün üzerinde çalıştığı taslak (Dene'den dönünce korunur).
var editor_draft: Dictionary = {}
var _fail_counts: Dictionary = {}


func _ready() -> void:
	load_levels()
	data = SaveManager.load_data()
	SaveManager.save_data(data)


func load_levels() -> void:
	levels.clear()
	var i := 1
	while FileAccess.file_exists(LEVEL_PATH % i):
		var l := LevelData.load_file(LEVEL_PATH % i)
		if l == null or not l.validate().is_empty():
			push_error("Geçersiz bölüm atlandı: %d" % i)
		else:
			levels.append(l)
		i += 1


func level_count() -> int:
	return levels.size()


func is_unlocked(index: int) -> bool:
	return index <= int(data.get("last_completed_level", 0))


func stars_for_level(index: int) -> int:
	return int(data.get("level_stars", {}).get(str(index + 1), 0))


func fail_count(index: int) -> int:
	return int(_fail_counts.get(index, 0))


func record_win(index: int, moves_used: int) -> void:
	var l := levels[index]
	var stars := l.stars_for(moves_used)
	var key := str(index + 1)
	var level_stars: Dictionary = data["level_stars"]
	level_stars[key] = maxi(int(level_stars.get(key, 0)), stars)
	data["last_completed_level"] = maxi(int(data["last_completed_level"]), index + 1)
	_fail_counts[index] = 0
	SaveManager.save_data(data)
	last_result = {
		"level_index": index, "won": true, "stars": stars,
		"moves_used": moves_used, "move_limit": l.move_limit,
	}


## Test oturumları: aynı telefonda sıradaki testçiye geçerken ilerlemeyi sıfırlar.
func start_new_tester() -> void:
	data["test_tester"] = int(data.get("test_tester", 1)) + 1
	data["last_completed_level"] = 0
	data["level_stars"] = {}
	_fail_counts.clear()
	SaveManager.save_data(data)
	AnalyticsService.track("tester_start")


func record_fail(index: int, moves_used: int) -> void:
	_fail_counts[index] = fail_count(index) + 1
	last_result = {
		"level_index": index, "won": false, "stars": 0,
		"moves_used": moves_used, "move_limit": levels[index].move_limit,
	}
