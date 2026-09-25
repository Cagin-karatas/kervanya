class_name LevelData
extends RefCounted
## Bir bölüm dosyasının (levels/level_XXX.json) okunmuş hali.
## Oyun sırasında bu veri değiştirilmez; oyuncu durumu BoardModel'dedir.

const MIN_GRID := 3
const MAX_GRID := 10

var level_id: String = ""
var content_version: int = 1
var world_id: int = 1
var chapter_id: int = 1
var grid_width: int = 5
var grid_height: int = 5
var start_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var blocked_cells: Array[Vector2i] = []
var points_of_interest: Array[Vector2i] = []
var tile_pool: Dictionary = {}  # TileDefs.Type -> int
var move_limit: int = 0
var minimum_solution_moves: int = 0
var star_thresholds: Array[int] = []  # [3 yıldız için en fazla hamle, 2 yıldız için en fazla hamle]
var difficulty_score: int = 1
var rhythm: String = ""
var template_id: String = ""
var tutorial_key: String = ""
var assist_after_fail_count: int = 3
var solution: Array[Dictionary] = []  # [{cell: Vector2i, type: int, rot: int}]


static func load_file(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		push_error("Bölüm dosyası yok: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bölüm JSON okunamadı: %s" % path)
		return null
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.level_id = str(d.get("level_id", ""))
	l.content_version = int(d.get("content_version", 1))
	l.world_id = int(d.get("world_id", 1))
	l.chapter_id = int(d.get("chapter_id", 1))
	l.grid_width = int(d.get("grid_width", 5))
	l.grid_height = int(d.get("grid_height", 5))
	l.start_cell = _vec(d.get("start_cell", [0, 0]))
	l.goal_cell = _vec(d.get("goal_cell", [0, 0]))
	for c in d.get("blocked_cells", []):
		l.blocked_cells.append(_vec(c))
	for c in d.get("points_of_interest", []):
		l.points_of_interest.append(_vec(c))
	var pool: Dictionary = d.get("tile_pool", {})
	for key in pool:
		var t := TileDefs.type_from_name(str(key))
		if t != -1:
			l.tile_pool[t] = int(pool[key])
	for t in TileDefs.TYPE_NAMES:
		if not l.tile_pool.has(t):
			l.tile_pool[t] = 0
	l.move_limit = int(d.get("move_limit", 0))
	l.minimum_solution_moves = int(d.get("minimum_solution_moves", 0))
	for v in d.get("star_thresholds", []):
		l.star_thresholds.append(int(v))
	l.difficulty_score = int(d.get("difficulty_score", 1))
	l.rhythm = str(d.get("rhythm", ""))
	l.template_id = str(d.get("template_id", ""))
	l.tutorial_key = str(d.get("tutorial_key", ""))
	l.assist_after_fail_count = int(d.get("assist_after_fail_count", 3))
	for s in d.get("solution", []):
		l.solution.append({
			"cell": _vec(s.get("cell", [0, 0])),
			"type": TileDefs.type_from_name(str(s.get("type", ""))),
			"rot": int(s.get("rot", 0)),
		})
	return l


static func _vec(v) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_width and c.y < grid_height


func is_hub(c: Vector2i) -> bool:
	return c == start_cell or c == goal_cell or points_of_interest.has(c)


func stars_for(moves_used: int) -> int:
	if star_thresholds.size() >= 2:
		if moves_used <= star_thresholds[0]:
			return 3
		if moves_used <= star_thresholds[1]:
			return 2
	return 1


## Şema doğrulaması. Boş dizi dönerse bölüm geçerlidir.
func validate() -> PackedStringArray:
	var e := PackedStringArray()
	if level_id.is_empty():
		e.append("level_id boş")
	if grid_width < MIN_GRID or grid_width > MAX_GRID or grid_height < MIN_GRID or grid_height > MAX_GRID:
		e.append("ızgara boyutu %dx%d aralık dışı" % [grid_width, grid_height])
	if not in_bounds(start_cell):
		e.append("start_cell ızgara dışında")
	if not in_bounds(goal_cell):
		e.append("goal_cell ızgara dışında")
	if start_cell == goal_cell:
		e.append("başlangıç ve hedef aynı")
	var seen := {}
	for c in blocked_cells:
		if not in_bounds(c):
			e.append("kapalı hücre ızgara dışında: %s" % c)
		if is_hub(c):
			e.append("kapalı hücre hedefle çakışıyor: %s" % c)
		if seen.has(c):
			e.append("kapalı hücre tekrar ediyor: %s" % c)
		seen[c] = true
	for c in points_of_interest:
		if not in_bounds(c):
			e.append("ilgi noktası ızgara dışında: %s" % c)
		if c == start_cell or c == goal_cell:
			e.append("ilgi noktası başlangıç/hedefle çakışıyor: %s" % c)
	for t in tile_pool:
		if tile_pool[t] < 0:
			e.append("negatif parça sayısı")
	if move_limit <= 0:
		e.append("move_limit pozitif olmalı")
	if star_thresholds.size() != 2:
		e.append("star_thresholds iki değer içermeli")
	elif star_thresholds[0] > star_thresholds[1] or star_thresholds[1] > move_limit:
		e.append("star_thresholds sırası hatalı")
	if minimum_solution_moves > move_limit:
		e.append("minimum_solution_moves hamle limitini aşıyor")
	return e
