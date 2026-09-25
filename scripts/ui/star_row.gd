class_name StarRow
extends Control
## Yazı tipinden bağımsız çizilen 0-3 yıldız göstergesi.

var stars: int = 0:
	set(v):
		stars = v
		queue_redraw()
var star_size: float = 56.0


func _init(p_stars: int = 0, p_size: float = 56.0) -> void:
	stars = p_stars
	star_size = p_size
	custom_minimum_size = Vector2(p_size * 3.6, p_size * 1.1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var gap := star_size * 1.2
	var start_x := (size.x - gap * 2.0) / 2.0
	for i in range(3):
		var center := Vector2(start_x + gap * i, size.y / 2.0)
		var col := UiKit.ACCENT if i < stars else Color(1, 1, 1, 0.18)
		draw_colored_polygon(_star_points(center, star_size * 0.5, star_size * 0.22), col)


static func _star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(10):
		var r := outer if k % 2 == 0 else inner
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
