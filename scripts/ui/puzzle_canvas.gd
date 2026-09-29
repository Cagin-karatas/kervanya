class_name PuzzleCanvas
extends Control
## Tahta + parça tepsisi çizimi ve tek parmak girişi.
## Model yalnız parmak kaldırıldığında değişir; sürükleme iptal olursa (uygulama arka plana
## geçer, ikinci parmak vb.) hiçbir parça kaybolmaz veya çoğalmaz.

signal board_changed
signal rejected(reason: String)

const COL_BOARD := Color("#3a332d")
const COL_CELL := Color("#e9dfcf")
const COL_CELL_ALT := Color("#e2d6c3")
const COL_BLOCKED := Color("#5d554d")
const COL_ROAD := Color("#8a7a66")
const COL_ROAD_ON := Color("#e0a93b")
const COL_START := Color("#4caf7a")
const COL_GOAL := Color("#d9534f")
const COL_POI := Color("#4a90d9")
const COL_OK := Color(0.30, 0.75, 0.45, 0.45)
const COL_BAD := Color(0.85, 0.30, 0.30, 0.55)
const COL_HINT := Color(0.29, 0.56, 0.85, 0.35)
const COL_TRAY := Color("#4a423a")

var model: BoardModel
var hint: Array[Dictionary] = []
var show_hint := false
var input_locked := false

var _cell := 64.0
var _origin := Vector2.ZERO
var _tray_rect := Rect2()
var _slot_rects: Dictionary = {}  # type -> Rect2
var _press: Dictionary = {}
var _drag: Dictionary = {}

## Öğretim ipuçları: "drag" = tahta boşken tepsiden kareye giden el animasyonu,
## "rotate" = yanlış yöne bakan parçada "dokun ve döndür" halkası (ilk döndürmeye kadar).
var tutorial_mode := ""
var _rotated_once := false
var _hint_until_ms := 0
const HINT_CYCLE_MS := 1600


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func setup(p_model: BoardModel) -> void:
	model = p_model
	model.acted.connect(func(kind: String) -> void:
		if kind == "rotate":
			_rotated_once = true)
	_layout()
	queue_redraw()


func cancel_interaction() -> void:
	_press.clear()
	_drag.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_MOUSE_EXIT_SELF:
		if what != NOTIFICATION_MOUSE_EXIT_SELF or _press.is_empty():
			cancel_interaction()


# ---------------------------------------------------------------- yerleşim

func _layout() -> void:
	if model == null:
		return
	var tray_h := clampf(size.y * 0.2, 180.0, 300.0)
	var board_area := Vector2(size.x, size.y - tray_h - 24.0)
	_cell = floorf(minf(board_area.x / model.level.grid_width, board_area.y / model.level.grid_height))
	var board_size := Vector2(_cell * model.level.grid_width, _cell * model.level.grid_height)
	_origin = Vector2((size.x - board_size.x) / 2.0, (board_area.y - board_size.y) / 2.0)
	_tray_rect = Rect2(0, size.y - tray_h, size.x, tray_h)
	_slot_rects.clear()
	var types := TileDefs.TYPE_NAMES.keys()
	var slot_w := minf(size.x / types.size() - 24.0, 360.0)
	var total := slot_w * types.size() + 24.0 * (types.size() - 1)
	var x := (size.x - total) / 2.0
	for t in types:
		_slot_rects[t] = Rect2(x, _tray_rect.position.y + 12.0, slot_w, tray_h - 24.0)
		x += slot_w + 24.0
	queue_redraw()


func cell_at(pos: Vector2) -> Vector2i:
	var local := (pos - _origin) / _cell
	var c := Vector2i(floori(local.x), floori(local.y))
	return c if model != null and model.in_bounds(c) else Vector2i(-1, -1)


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


func tray_type_at(pos: Vector2) -> int:
	for t in _slot_rects:
		if _slot_rects[t].has_point(pos):
			return t
	return -1


func ghost_offset() -> Vector2:
	# Parça parmağın biraz üstünde durur ki parmak altındaki kareyi kapatmasın.
	return Vector2(0, -_cell * 0.55)


# ---------------------------------------------------------------- giriş

func _gui_input(event: InputEvent) -> void:
	if model == null or input_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and not _press.is_empty():
		_on_motion(event.position)
		accept_event()


func _on_press(pos: Vector2) -> void:
	cancel_interaction()
	if model.is_finished():
		return
	var t := tray_type_at(pos)
	if t != -1:
		if model.tray_count(t) <= 0:
			rejected.emit("empty_tray")
			return
		_press = {"source": "tray", "type": t, "start": pos}
		_begin_drag(pos)
		return
	var c := cell_at(pos)
	if c.x >= 0 and model.has_tile(c):
		_press = {"source": "board", "cell": c, "start": pos}


func _on_motion(pos: Vector2) -> void:
	if _drag.is_empty() and _press.get("source") == "board":
		if pos.distance_to(_press["start"]) > _cell * 0.2:
			_begin_drag(pos)
	if not _drag.is_empty():
		_drag["pos"] = pos
		queue_redraw()


func _begin_drag(pos: Vector2) -> void:
	if _press["source"] == "tray":
		_drag = {"source": "tray", "type": _press["type"], "rot": 0, "pos": pos}
	else:
		var c: Vector2i = _press["cell"]
		_drag = {"source": "board", "cell": c, "type": model.tiles[c]["type"],
				"rot": model.tiles[c]["rot"], "pos": pos}
	queue_redraw()


func _on_release(pos: Vector2) -> void:
	var changed := false
	if not _drag.is_empty():
		var target := cell_at(pos + ghost_offset())
		if _drag["source"] == "tray":
			if target.x < 0 and pos.distance_to(_press.get("start", pos)) < _cell * 0.25:
				# Tepsiye sadece dokunuldu: sürüklemeyi göster.
				rejected.emit("tap_tray")
				play_drag_hint(2)
			elif target.x >= 0:
				changed = model.place_from_tray(_drag["type"], target)
				if not changed:
					rejected.emit("no_moves" if model.moves_left() <= 0 else "invalid_cell")
		else:
			var from: Vector2i = _drag["cell"]
			if target == from:
				pass
			elif target.x >= 0 and model.can_place(target):
				changed = model.move_tile(from, target)
				if not changed:
					rejected.emit("no_moves")
			elif target.x < 0:
				# Tahta dışına veya tepsiye bırakıldı: parça tepsiye döner.
				changed = model.return_to_tray(from)
			else:
				rejected.emit("invalid_cell")
	elif _press.get("source") == "board":
		changed = model.rotate_tile(_press["cell"])
		if not changed:
			rejected.emit("no_moves")
	cancel_interaction()
	if changed:
		_hint_until_ms = 0
		board_changed.emit()


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if model == null:
		return
	var lvl := model.level
	var board := Rect2(_origin, Vector2(lvl.grid_width, lvl.grid_height) * _cell)
	draw_rect(board.grow(10.0), COL_BOARD)
	var connected := model.reachable()
	var drag_from: Vector2i = _drag.get("cell", Vector2i(-1, -1)) if _drag.get("source") == "board" else Vector2i(-1, -1)

	for y in range(lvl.grid_height):
		for x in range(lvl.grid_width):
			var c := Vector2i(x, y)
			var r := cell_rect(c).grow(-3.0)
			if model.is_blocked(c):
				draw_rect(r, COL_BLOCKED)
				var k := r.grow(-r.size.x * 0.3)
				draw_line(k.position, k.end, Color(0, 0, 0, 0.25), 6.0)
				draw_line(Vector2(k.end.x, k.position.y), Vector2(k.position.x, k.end.y), Color(0, 0, 0, 0.25), 6.0)
			else:
				draw_rect(r, COL_CELL if (x + y) % 2 == 0 else COL_CELL_ALT)

	if show_hint:
		for h in hint:
			var hc: Vector2i = h["cell"]
			var placed_ok: bool = model.has_tile(hc) and model.cell_mask(hc) == TileDefs.mask_of(h["type"], h["rot"])
			if not placed_ok:
				_draw_road(cell_rect(hc), TileDefs.mask_of(h["type"], h["rot"]), COL_HINT)

	for c in model.tiles:
		if c == drag_from:
			continue
		var t: Dictionary = model.tiles[c]
		_draw_road(cell_rect(c), TileDefs.mask_of(t["type"], t["rot"]),
				COL_ROAD_ON if connected.has(c) else COL_ROAD)

	_draw_hub(lvl.start_cell, COL_START, "start", true)
	_draw_hub(lvl.goal_cell, COL_GOAL, "goal", connected.has(lvl.goal_cell))
	for p in lvl.points_of_interest:
		_draw_hub(p, COL_POI, "poi", connected.has(p))

	_draw_tray()
	_draw_tutorial()

	if not _drag.is_empty():
		var gpos: Vector2 = _drag["pos"] + ghost_offset()
		var target := cell_at(gpos)
		# Gölge, parça bırakılınca alacağı yönde çizilir; görülen ile olan aynı kalır.
		var ghost_rot: int = _drag["rot"]
		if target.x >= 0 and target != drag_from:
			var ok := model.can_place(target) and model.moves_left() > 0
			draw_rect(cell_rect(target).grow(-3.0), COL_OK if ok else COL_BAD)
			if not ok:
				# Geçersiz kare yalnız renkle değil, çarpı işaretiyle de gösterilir.
				var k := cell_rect(target).grow(-_cell * 0.3)
				draw_line(k.position, k.end, Color(0.55, 0.1, 0.1), 7.0)
				draw_line(Vector2(k.end.x, k.position.y), Vector2(k.position.x, k.end.y), Color(0.55, 0.1, 0.1), 7.0)
			if ok:
				ghost_rot = model.best_rotation(_drag["type"], target, drag_from)
		var ghost := Rect2(gpos - Vector2(_cell, _cell) * 0.5, Vector2(_cell, _cell))
		draw_rect(ghost.grow(-6.0), Color(1, 1, 1, 0.35))
		_draw_road(ghost, TileDefs.mask_of(_drag["type"], ghost_rot), COL_ROAD)


func _draw_road(rect: Rect2, mask: int, color: Color) -> void:
	var center := rect.get_center()
	var w := rect.size.x * 0.28
	for d in TileDefs.DIRS:
		if mask & d:
			var end := center + Vector2(TileDefs.dir_offset(d)) * rect.size.x * 0.5
			draw_line(center, end, color, w)
	draw_circle(center, w * 0.5, color)


func _draw_hub(c: Vector2i, color: Color, kind: String, lit: bool) -> void:
	var r := cell_rect(c)
	var center := r.get_center()
	var rad := r.size.x * 0.36
	var col := color if lit else color.darkened(0.35)
	match kind:
		"start":
			draw_circle(center, rad, col)
			draw_circle(center, rad * 0.45, Color.WHITE)
		"goal":
			draw_circle(center, rad, col)
			var f := rad * 0.5
			draw_line(center + Vector2(-f * 0.6, f), center + Vector2(-f * 0.6, -f), Color.WHITE, 5.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-f * 0.6, -f), center + Vector2(f, -f * 0.5), center + Vector2(-f * 0.6, 0)]), Color.WHITE)
		"poi":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -rad), center + Vector2(rad, 0),
				center + Vector2(0, rad), center + Vector2(-rad, 0)]), col)
			draw_circle(center, rad * 0.3, Color.WHITE)


func _draw_tray() -> void:
	var font := get_theme_default_font()
	for t in _slot_rects:
		var r: Rect2 = _slot_rects[t]
		var count := model.tray_count(t)
		var dragging_this: bool = _drag.get("source") == "tray" and _drag.get("type") == t
		var shown := count - (1 if dragging_this else 0)
		draw_rect(r, COL_TRAY if count > 0 else COL_TRAY.darkened(0.4))
		var icon_size := minf(r.size.y * 0.7, r.size.x * 0.5)
		var icon := Rect2(r.position + Vector2(r.size.x * 0.08, (r.size.y - icon_size) / 2.0), Vector2(icon_size, icon_size))
		draw_rect(icon, COL_CELL if shown > 0 else COL_CELL.darkened(0.5))
		_draw_road(icon, TileDefs.mask_of(t, 0), COL_ROAD if shown > 0 else COL_ROAD.darkened(0.5))
		var text_pos := Vector2(icon.end.x + 20.0, r.get_center().y + 22.0)
		draw_string(font, text_pos, "× %d" % shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 64,
				UiKit.TEXT if shown > 0 else UiKit.MUTED)


# ---------------------------------------------------------------- öğretim ipuçları

func play_drag_hint(cycles: int = 2) -> void:
	_hint_until_ms = Time.get_ticks_msec() + cycles * HINT_CYCLE_MS
	queue_redraw()


func _process(_delta: float) -> void:
	if model != null and (_drag_hint_active() or _rotate_hint_cell().x >= 0):
		queue_redraw()


func _drag_hint_active() -> bool:
	if model == null or input_locked or not _drag.is_empty() or model.is_finished():
		return false
	if Time.get_ticks_msec() < _hint_until_ms:
		return true
	return tutorial_mode == "drag" and model.tiles.is_empty()


## Öğretilecek hedef: çözümde olup henüz doğru yerleşmemiş ilk kare ve türü.
func _next_hint_step() -> Dictionary:
	for h in hint:
		var hc: Vector2i = h["cell"]
		if model.cell_mask(hc) == TileDefs.mask_of(h["type"], h["rot"]):
			continue
		if model.has_tile(hc) or model.tray_count(h["type"]) <= 0:
			continue
		return h
	return {}


func _rotate_hint_cell() -> Vector2i:
	if tutorial_mode != "rotate" or _rotated_once or model.is_finished() or not _drag.is_empty():
		return Vector2i(-1, -1)
	for h in hint:
		var hc: Vector2i = h["cell"]
		if model.has_tile(hc) and model.tiles[hc]["type"] == h["type"] \
				and model.cell_mask(hc) != TileDefs.mask_of(h["type"], h["rot"]):
			return hc
	return Vector2i(-1, -1)


func _draw_tutorial() -> void:
	var now := Time.get_ticks_msec()
	if _drag_hint_active():
		var step := _next_hint_step()
		if not step.is_empty():
			var t := float(now % HINT_CYCLE_MS) / HINT_CYCLE_MS
			var a: Vector2 = _slot_rects[step["type"]].get_center()
			var b: Vector2 = cell_rect(step["cell"]).get_center()
			var k := smoothstep(0.15, 0.75, t)
			var pos := a.lerp(b, k)
			var alpha := clampf(minf(t / 0.1, (1.0 - t) / 0.15), 0.0, 1.0)
			var r := Rect2(pos - Vector2(_cell, _cell) * 0.45, Vector2(_cell, _cell) * 0.9)
			draw_rect(r, Color(1, 1, 1, 0.3 * alpha))
			_draw_road(r, TileDefs.mask_of(step["type"], step["rot"]), Color(COL_ROAD_ON, 0.8 * alpha))
			# Parmak: parçanın biraz altında içi boş daire
			var finger := pos + Vector2(_cell * 0.25, _cell * 0.45)
			draw_circle(finger, _cell * 0.16, Color(1, 1, 1, 0.55 * alpha))
			draw_arc(finger, _cell * 0.16, 0, TAU, 32, Color(0.2, 0.18, 0.16, 0.8 * alpha), 4.0)
	var rc := _rotate_hint_cell()
	if rc.x >= 0:
		var c := cell_rect(rc).get_center()
		var pulse := 0.5 + 0.5 * sin(now / 180.0)
		draw_arc(c, _cell * (0.44 + 0.04 * pulse), 0, TAU, 48, Color(COL_POI, 0.55 + 0.4 * pulse), 8.0)
		# Saat yönünde dönen ok (gölgeli, kare içinde)
		var rad := _cell * 0.26
		var a0 := -PI * 0.85 + pulse * 0.3
		var a1 := PI * 0.35 + pulse * 0.3
		draw_arc(c, rad, a0, a1, 24, Color(0, 0, 0, 0.45), 11.0)
		draw_arc(c, rad, a0, a1, 24, Color.WHITE, 7.0)
		var tip := c + Vector2(cos(a1), sin(a1)) * rad
		var tangent := Vector2(-sin(a1), cos(a1))
		var normal := Vector2(cos(a1), sin(a1))
		var head := PackedVector2Array([tip + tangent * 16.0, tip - normal * 12.0, tip + normal * 12.0])
		draw_colored_polygon(head, Color.WHITE)
