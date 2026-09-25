class_name UiKit
extends RefCounted
## Gri prototip için ortak arayüz yardımcıları: renkler, güvenli alan, butonlar.

const BG := Color("#2b2622")
const PANEL := Color("#3a332d")
const TEXT := Color("#f3ead9")
const MUTED := Color("#a79a88")
const ACCENT := Color("#e0a93b")


## Arka plan + güvenli alan kenar boşlukları + dikey kutu kurar, kutuyu döndürür.
static func build_screen(root: Control, separation: int = 24) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := safe_margins(root)
	margin.add_theme_constant_override("margin_left", 32 + int(safe.x))
	margin.add_theme_constant_override("margin_top", 32 + int(safe.y))
	margin.add_theme_constant_override("margin_right", 32 + int(safe.z))
	margin.add_theme_constant_override("margin_bottom", 32 + int(safe.w))
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


## Mobilde çentik/gezinme çubuğu boşlukları (sol, üst, sağ, alt) görünüm biriminde.
static func safe_margins(node: Control) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var vp := node.get_viewport_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	return Vector4(
		maxf(0.0, safe.position.x * sx),
		maxf(0.0, safe.position.y * sy),
		maxf(0.0, (win.x - safe.end.x) * sx),
		maxf(0.0, (win.y - safe.end.y) * sy))


static func button(text: String, on_pressed: Callable, min_height: int = 120) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 44)
	b.pressed.connect(on_pressed)
	return b


static func label(text: String, font_size: int = 40, color: Color = TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)
