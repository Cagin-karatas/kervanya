class_name EditorGrid
extends Control
## Bölüm editörünün tahtası: dokunarak/sürükleyerek kare boyama ve çözüm önizlemesi.

signal edited

const COL_BOARD := Color("#3a332d")
const COL_CELL := Color("#e9dfcf")
const COL_CELL_ALT := Color("#e2d6c3")
const COL_BLOCKED := Color("#5d554d")
const COL_START := Color("#4caf7a")
const COL_GOAL := Color("#d9534f")
const COL_POI := Color("#4a90d9")
const COL_SOLUTION := Color(0.88, 0.66, 0.23, 0.8)

## Araçlar: "empty", "blocked", "start", "goal", "poi"
var tool := "blocked"
var data: Dictionary = {}
var solution: Array = []  # [{cell: Vector2i, type: int, rot: int}]

var _cell := 64.0
var _origin := Vector2.ZERO
var _painting := false
var _last_painted := Vector2i(-99, -99)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func w() -> int:
	return int(data.get("grid_width", 5))


func h() -> int:
	return int(data.get("grid_height", 5))


func _layout() -> void:
	_cell = floorf(minf(size.x / w(), size.y / h()))
	_origin = (size - Vector2(w(), h()) * _cell) / 2.0


func cell_at(pos: Vector2) -> Vector2i:
	_layout()
	var l := (pos - _origin) / _cell
	var c := Vector2i(floori(l.x), floori(l.y))
	return c if c.x >= 0 and c.y >= 0 and c.x < w() and c.y < h() else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = event.pressed
		_last_painted = Vector2i(-99, -99)
		if event.pressed:
			_paint(cell_at(event.position))
		accept_event()
	elif event is InputEventMouseMotion and _painting and (tool == "blocked" or tool == "empty"):
		_paint(cell_at(event.position))
		accept_event()


func _paint(c: Vector2i) -> void:
	if c.x < 0 or c == _last_painted:
		return
	_last_painted = c
	var arr := [c.x, c.y]
	_remove_from("blocked_cells", c)
	_remove_from("points_of_interest", c)
	match tool:
		"blocked":
			if not _is_hub(c):
				data["blocked_cells"].append(arr)
		"poi":
			if not _is_start_or_goal(c):
				data["points_of_interest"].append(arr)
		"start":
			if _vec(data["goal_cell"]) != c:
				data["start_cell"] = arr
		"goal":
			if _vec(data["start_cell"]) != c:
				data["goal_cell"] = arr
	solution = []
	queue_redraw()
	edited.emit()


func _remove_from(key: String, c: Vector2i) -> void:
	var keep := []
	for v in data.get(key, []):
		if _vec(v) != c:
			keep.append(v)
	data[key] = keep


func _is_start_or_goal(c: Vector2i) -> bool:
	return _vec(data["start_cell"]) == c or _vec(data["goal_cell"]) == c


func _is_hub(c: Vector2i) -> bool:
	if _is_start_or_goal(c):
		return true
	for v in data.get("points_of_interest", []):
		if _vec(v) == c:
			return true
	return false


static func _vec(v) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1])) if v is Array and v.size() >= 2 else Vector2i(-1, -1)


func _draw() -> void:
	if data.is_empty():
		return
	_layout()
	draw_rect(Rect2(_origin, Vector2(w(), h()) * _cell).grow(8.0), COL_BOARD)
	var blocked := {}
	for v in data.get("blocked_cells", []):
		blocked[_vec(v)] = true
	for y in range(h()):
		for x in range(w()):
			var c := Vector2i(x, y)
			var r := _rect(c).grow(-3.0)
			draw_rect(r, COL_BLOCKED if blocked.has(c) else (COL_CELL if (x + y) % 2 == 0 else COL_CELL_ALT))
	for p in solution:
		_draw_road(_rect(p["cell"]), TileDefs.mask_of(p["type"], p["rot"]), COL_SOLUTION)
	_draw_hub(_vec(data["start_cell"]), COL_START)
	_draw_hub(_vec(data["goal_cell"]), COL_GOAL)
	for v in data.get("points_of_interest", []):
		var c := _vec(v)
		var ctr := _rect(c).get_center()
		var rad := _cell * 0.34
		draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -rad), ctr + Vector2(rad, 0),
				ctr + Vector2(0, rad), ctr + Vector2(-rad, 0)]), COL_POI)


func _rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


func _draw_hub(c: Vector2i, col: Color) -> void:
	if c.x < 0 or c.x >= w() or c.y >= h():
		return
	draw_circle(_rect(c).get_center(), _cell * 0.34, col)


func _draw_road(rect: Rect2, mask: int, color: Color) -> void:
	var center := rect.get_center()
	var width := rect.size.x * 0.24
	for d in TileDefs.DIRS:
		if mask & d:
			draw_line(center, center + Vector2(TileDefs.dir_offset(d)) * rect.size.x * 0.5, color, width)
	draw_circle(center, width * 0.5, color)
