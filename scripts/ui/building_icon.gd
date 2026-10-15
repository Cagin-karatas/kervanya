class_name BuildingIcon
extends Control
## Gri prototip bina çizimi: her binanın 0-3 seviyesi için ayrı görünüm (plan §4.3 "üç görsel seviye").

var building_id := "kervansaray"
var level := 0:
	set(v):
		level = v
		queue_redraw()
var pulse := 0.0:
	set(v):
		pulse = v
		queue_redraw()

const SAND := Color("#cdb892")
const WALL := Color("#b98d5a")
const WALL_DARK := Color("#8a6640")
const ROOF := Color("#a24b3a")
const TENT := Color("#e0a93b")
const TENT2 := Color("#4a90d9")
const WATER := Color("#4a90d9")
const STONE := Color("#8a8178")
const GHOST := Color(1, 1, 1, 0.25)


func _init(id: String = "kervansaray", lv: int = 0) -> void:
	building_id = id
	level = lv
	custom_minimum_size = Vector2(220, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var grow := 1.0 + pulse * 0.12
	draw_set_transform(c, 0.0, Vector2(grow, grow))
	# Zemin: yassı elips
	var ground := PackedVector2Array()
	for i in range(32):
		var a := TAU * i / 32.0
		ground.append(Vector2(cos(a) * s * 0.46, s * 0.3 + sin(a) * s * 0.12))
	draw_colored_polygon(ground, SAND.darkened(0.15))
	match building_id:
		"kervansaray":
			_kervansaray(s)
		"pazar":
			_pazar(s)
		"kuyu":
			_kuyu(s)
	draw_set_transform(Vector2.ZERO)


func _outline(r: Rect2) -> void:
	draw_rect(r, GHOST, false, 4.0)


func _kervansaray(s: float) -> void:
	var w := s * 0.62
	var h := s * (0.3 + 0.07 * level)
	var base := Rect2(-w / 2, s * 0.3 - h, w, h)
	if level == 0:
		_outline(base)
		return
	draw_rect(base, WALL)
	# kemerli kapı
	var dw := w * 0.22
	draw_rect(Rect2(-dw / 2, s * 0.3 - h * 0.55, dw, h * 0.55), WALL_DARK)
	draw_circle(Vector2(0, s * 0.3 - h * 0.55), dw / 2, WALL_DARK)
	# mazgallar
	var n := 5
	for i in range(n):
		var x := -w / 2 + w * (i + 0.25) / n
		draw_rect(Rect2(x, base.position.y - s * 0.05, w / n * 0.5, s * 0.05), WALL)
	if level >= 2:
		for sx in [-1, 1]:
			var tw := s * 0.12
			draw_rect(Rect2(sx * w / 2 - tw / 2, base.position.y - s * 0.12, tw, h + s * 0.12), WALL.darkened(0.08))
	if level >= 3:
		var p := Vector2(0, base.position.y - s * 0.05)
		draw_line(p, p + Vector2(0, -s * 0.2), WALL_DARK, 4.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 0.2), p + Vector2(s * 0.12, -s * 0.16), p + Vector2(0, -s * 0.12)]), ROOF)


func _pazar(s: float) -> void:
	var count := maxi(level, 1)
	var tw := s * 0.24
	for i in range(3):
		var x := (i - 1) * tw * 1.15
		var r := Rect2(x - tw / 2, s * 0.1, tw, s * 0.2)
		if i >= level:
			_outline(r)
			continue
		draw_rect(r, Color("#e9dfcf"))
		var col := TENT if i % 2 == 0 else TENT2
		draw_colored_polygon(PackedVector2Array([Vector2(x - tw * 0.6, s * 0.1), Vector2(x + tw * 0.6, s * 0.1), Vector2(x, -s * 0.12)]), col)
	if level == 0 and count == 1:
		return


func _kuyu(s: float) -> void:
	var r := s * 0.18
	var p := Vector2(0, s * 0.22)
	if level == 0:
		draw_arc(p, r, 0, TAU, 32, GHOST, 4.0)
		return
	draw_circle(p, r, STONE)
	draw_circle(p, r * 0.7, WATER.darkened(0.2 if level < 2 else 0.0))
	if level >= 2:
		for sx in [-1, 1]:
			draw_line(p + Vector2(sx * r, 0), p + Vector2(sx * r, -s * 0.32), WALL_DARK, 6.0)
		draw_line(p + Vector2(-r, -s * 0.3), p + Vector2(r, -s * 0.3), WALL_DARK, 6.0)
	if level >= 3:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.4, -s * 0.3), p + Vector2(r * 1.4, -s * 0.3), p + Vector2(0, -s * 0.48)]), ROOF)
		draw_line(p + Vector2(0, -s * 0.3), p + Vector2(0, -s * 0.12), Color("#5d554d"), 3.0)
		draw_rect(Rect2(p + Vector2(-s * 0.03, -s * 0.12), Vector2(s * 0.06, s * 0.06)), STONE.darkened(0.3))
