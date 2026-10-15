extends Control
## Ayarlar (plan §12): müzik, efekt ve titreşim ayrı kapatılır; dil seçimi (Türkçe / İngilizce / sistem).

const LANGS := [["", "LANG_SYSTEM"], ["tr", "LANG_TR"], ["en", "LANG_EN"]]

var _toggles: Dictionary = {}
var _lang_buttons: Dictionary = {}


func _ready() -> void:
	var box := UiKit.build_screen(self, 24)
	var top := HBoxContainer.new()
	var title := UiKit.label(tr("SETTINGS"), 64, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := UiKit.button(tr("MENU"), SceneRouter.goto_menu, 90)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 200
	top.add_child(back)
	box.add_child(top)

	for key in ["music", "sfx", "vibration"]:
		var row := HBoxContainer.new()
		var l := UiKit.label(tr(key.to_upper()), 44, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		# Telefonda kolay dokunulsun diye büyük Açık/Kapalı düğmesi (varsayılan anahtar çok küçük).
		var cb := UiKit.button("", func() -> void: pass, 100)
		cb.toggle_mode = true
		cb.size_flags_horizontal = Control.SIZE_FILL
		cb.custom_minimum_size.x = 260
		cb.button_pressed = AudioManager.is_enabled(key)
		_style_toggle(cb)
		cb.toggled.connect(_on_toggled.bind(key))
		row.add_child(cb)
		box.add_child(row)
		_toggles[key] = cb

	box.add_child(UiKit.label(tr("LANGUAGE"), 40, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	var current := str(GameState.data["settings"].get("language", ""))
	for l in LANGS:
		var b := UiKit.button(tr(l[1]), _on_language.bind(l[0]), 110)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = l[0] == current
		langs.add_child(b)
		_lang_buttons[l[0]] = b
	box.add_child(langs)


func _style_toggle(b: Button) -> void:
	b.text = tr("ON") if b.button_pressed else tr("OFF")
	b.add_theme_color_override("font_color", UiKit.ACCENT if b.button_pressed else UiKit.MUTED)
	b.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", UiKit.ACCENT)


func _on_toggled(on: bool, key: String) -> void:
	_style_toggle(_toggles[key])
	GameState.set_setting(key, on)
	if key == "vibration" and on:
		AudioManager.vibrate(60)


func _on_language(code: String) -> void:
	GameState.set_setting("language", code)
	# Metinler sahne kurulurken çevrildiği için ekranı yeniden aç.
	SceneRouter.goto_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
