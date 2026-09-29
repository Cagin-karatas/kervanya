class_name JourneyView
extends Control
## Yolculuğun çizimi ve girişi: yatay kaydırma şerit değiştirir, dokunma hızlandırır.

signal swiped(dir: int)
signal tapped

const COL_GROUND := Color("#cdb892")
const COL_ROAD := Color("#e9dfcf")
const COL_LINE := Color("#b9a582")
const COL_ROCK := Color("#5d554d")
const COL_COIN := Color("#e0a93b")
const COL_RARE := Color("#4a90d9")
const COL_CAMEL := Color("#8a5a33")

const VISIBLE_AHEAD := 6.0   # kervanın önünde görünen mesafe (şerit birimi)
const CARAVAN_Y := 0.78      # kervanın ekrandaki dikey konumu (oran)

var model: JourneyModel
var flash := 0.0            # çarpma kızarıklığı
var _press_pos := Vector2.ZERO
var _pressing := false
var _swiped_this_press := false
var _lane_visual := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func lane_x(l: float) -> float:
	var road_w := minf(size.x * 0.86, size.y * 0.6)
	var left := (size.x - road_w) / 2.0
	return left + road_w * (l + 0.5) / JourneyModel.LANES


func unit() -> float:
	return size.y * CARAVAN_Y / VISIBLE_AHEAD


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_swiped_this_press = false
			_press_pos = event.position
		else:
			if _pressing and not _swiped_this_press:
				tapped.emit()
			_pressing = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing and not _swiped_this_press:
		var dx: float = event.position.x - _press_pos.x
		if absf(dx) > size.x * 0.06:
			_swiped_this_press = true
			swiped.emit(1 if dx > 0 else -1)
		accept_event()


func _process(delta: float) -> void:
	if model != null:
		_lane_visual = move_toward(_lane_visual, model.lane, delta * 10.0)
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COL_GROUND)
	var road_w := minf(size.x * 0.86, size.y * 0.6)
	var left := (size.x - road_w) / 2.0
	draw_rect(Rect2(left, 0, road_w, size.y), COL_ROAD)
	var u := unit()
	var cy := size.y * CARAVAN_Y
	# Kayan şerit çizgileri
	var offset := fmod(model.distance, 1.0) * u
	for l in range(1, JourneyModel.LANES):
		var x := left + road_w * l / JourneyModel.LANES
		var y := -u + offset
		while y < size.y:
			draw_line(Vector2(x, y), Vector2(x, y + u * 0.45), COL_LINE, 8.0)
			y += u
	# Nesneler
	for it in model.items:
		var ahead: float = it["y"] - model.distance
		if ahead < -1.0 or ahead > VISIBLE_AHEAD + 1.0:
			continue
		if it["done"] and it["kind"] != "rock":
			continue
		var p := Vector2(lane_x(it["lane"]), cy - ahead * u)
		var r := u * 0.28
		match it["kind"]:
			"rock":
				draw_circle(p, r, COL_ROCK.lightened(0.15) if it["done"] else COL_ROCK)
				draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.15))
			"coin":
				draw_circle(p, r * 0.8, COL_COIN)
				draw_circle(p, r * 0.45, COL_COIN.lightened(0.35))
			"rare":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0),
						p + Vector2(0, r), p + Vector2(-r, 0)]), COL_RARE)
	# Kervan (deve): gövde + boyun + baş + yük
	var c := Vector2(lane_x(_lane_visual), cy)
	var s := u * 0.5
	var body := COL_CAMEL if flash <= 0.0 else COL_CAMEL.lerp(Color(0.9, 0.2, 0.2), flash)
	draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.2), Vector2(s * 1.1, s * 1.3)), body)
	draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.9), Vector2(s * 0.36, s * 0.8)), body)
	draw_circle(c + Vector2(0, -s * 0.95), s * 0.28, body)
	draw_rect(Rect2(c + Vector2(-s * 0.7, s * 0.2), Vector2(s * 1.4, s * 0.45)), Color("#4a90d9").darkened(0.2))
	if model.current_speed() > model.speed:
		for k in range(3):
			var y := c.y + s * (1.3 + k * 0.35)
			draw_line(Vector2(c.x - s * 0.4, y), Vector2(c.x + s * 0.4, y), Color(1, 1, 1, 0.5), 5.0)
