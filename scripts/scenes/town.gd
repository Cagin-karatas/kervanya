extends Control
## Kasaba ekranı (plan §4.3): binaları gör, altın ve ticaret malıyla geliştir.

const NAME_KEYS := {"kervansaray": "B_KERVANSARAY", "pazar": "B_PAZAR", "kuyu": "B_KUYU"}

var _wallet: Label
var _town_label: Label
var _cards: Dictionary = {}  # id -> {icon, level, effect, cost, button, reason}


func _ready() -> void:
	AnalyticsService.track("town_opened", {"town_level": TownModel.town_level(GameState.data)})
	AudioManager.play_music("town")
	var box := UiKit.build_screen(self, 18)
	var top := HBoxContainer.new()
	var title := UiKit.label(tr("TOWN"), 64, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := UiKit.button(tr("MENU"), SceneRouter.goto_menu, 90)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 200
	top.add_child(back)
	box.add_child(top)

	_town_label = UiKit.label("", 34, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_town_label)
	_wallet = UiKit.label("", 40, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_wallet)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	for b in TownModel.defs():
		list.add_child(_make_card(b["id"]))
	_refresh()


func _make_card(id: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.PANEL
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var icon := BuildingIcon.new(id, TownModel.level_of(GameState.data, id))
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(tr(NAME_KEYS[id]), 44, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var lv := UiKit.label("", 32, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(lv)
	var fx := UiKit.label("", 28, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(fx)
	var cost := UiKit.label("", 30, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(cost)
	var reason := UiKit.label("", 28, Color("#e07b6a"), HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(reason)
	var btn := UiKit.button("", _on_upgrade.bind(id), 96)
	col.add_child(btn)
	_cards[id] = {"icon": icon, "level": lv, "effect": fx, "cost": cost, "button": btn, "reason": reason}
	return panel


func _effect_text(id: String, lv: int) -> String:
	var b := TownModel.def(id)
	var vals: Array = b.get("values", [])
	var shown := lv if lv > 0 else 1
	match id:
		"pazar":
			return tr("B_PAZAR_FX") % int(vals[mini(shown, vals.size() - 1)])
		"kuyu":
			return tr("B_KUYU_FX") % int(vals[mini(shown, vals.size() - 1)])
	return tr("B_KERVANSARAY_FX")


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	if cost.has("gold"):
		parts.append(tr("GOLD_SHORT") % int(cost["gold"]))
	if cost.has("trade_goods"):
		parts.append(tr("GOODS_SHORT") % int(cost["trade_goods"]))
	return " + ".join(parts)


func _refresh() -> void:
	var d := GameState.data
	var cur: Dictionary = d["currencies"]
	_wallet.text = "%s   ·   %s" % [tr("GOLD_SHORT") % int(cur.get("gold", 0)), tr("GOODS_SHORT") % int(cur.get("trade_goods", 0))]
	_town_label.text = tr("TOWN_LEVEL") % TownModel.town_level(d)
	for id in _cards:
		var c: Dictionary = _cards[id]
		var b := TownModel.def(id)
		var lv := TownModel.level_of(d, id)
		var max_lv := int(b["max_level"])
		c["icon"].level = lv
		c["level"].text = tr("NOT_BUILT") if lv == 0 else tr("LEVEL_X") % [lv, max_lv]
		c["effect"].text = _effect_text(id, lv)
		var cost := TownModel.next_cost(d, id)
		c["cost"].text = "" if cost.is_empty() else tr("COST") % _cost_text(cost)
		var reason := TownModel.block_reason(d, id)
		var reason_text := ""
		match reason:
			"locked":
				reason_text = tr("R_LOCKED") % int(b["unlock_level"])
			"max":
				reason_text = tr("R_MAX")
			"town_level":
				reason_text = tr("R_TOWN_LEVEL")
			"gold":
				reason_text = tr("R_GOLD")
			"trade_goods":
				reason_text = tr("R_GOODS")
		c["reason"].text = reason_text
		c["reason"].visible = reason_text != ""
		var btn: Button = c["button"]
		btn.text = tr("BUILD") if lv == 0 else tr("UPGRADE")
		btn.disabled = reason != ""
		btn.visible = reason != "max"


func _on_upgrade(id: String) -> void:
	var was := TownModel.level_of(GameState.data, id)
	if not GameState.upgrade_building(id):
		return
	AudioManager.play_sfx("building_build" if was == 0 else "building_upgrade")
	var icon: BuildingIcon = _cards[id]["icon"]
	var tw := create_tween()
	icon.pulse = 1.0
	tw.tween_property(icon, "pulse", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
