extends Control
## Test raporu (yalnız test araçları açıkken): bu cihazdaki testçilerin Kapı 1 özeti.
## Menüde başlığa 3 saniye içinde 5 kez dokunarak açılır.

var _new_tester_armed := false
var _new_btn: Button
var _status: Label


func _ready() -> void:
	AnalyticsService.track("report_opened")
	var testers := TestReport.build(AnalyticsService.read_events())
	var g := TestReport.gate(testers)
	var box := UiKit.build_screen(self, 20)
	box.add_child(UiKit.label("Test raporu", 64, UiKit.ACCENT))
	var ok: bool = g["reached_level3"] >= 4
	box.add_child(UiKit.label("3. bölüme ulaşan testçi: %d / %d\nKapı 1 hedefi: 5 testçiden en az 4" % [g["reached_level3"], g["testers"]],
			40, UiKit.TEXT if not ok else Color("#7fd18b")))
	box.add_child(UiKit.label("Şu anki testçi: %d" % int(GameState.data.get("test_tester", 1)), 34, UiKit.MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for r in testers:
		_add_tester(list, r)
	if testers.is_empty():
		list.add_child(UiKit.label("Henüz kayıt yok.", 36, UiKit.MUTED))

	_status = UiKit.label("", 32, UiKit.MUTED)
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiKit.button("Kopyala", _on_copy.bind(testers), 110))
	_new_btn = UiKit.button("Yeni testçi", _on_new_tester, 110)
	row.add_child(_new_btn)
	row.add_child(UiKit.button("Menü", SceneRouter.goto_menu, 110))
	box.add_child(row)


func _add_tester(list: VBoxContainer, r: Dictionary) -> void:
	list.add_child(UiKit.label("Testçi %d  ·  toplam %s  ·  3. bölüm: %s  ·  en uzak: %d" % [
		r["tester"], TestReport.fmt_time(r["duration_s"]), TestReport.fmt_time(r["reached_level3_s"]), r["furthest"]],
		36, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	for h in ["Bölüm", "Deneme", "İlk den.", "Süre", "Hamle", "Döndür."]:
		grid.add_child(_cell(h, UiKit.MUTED))
	var keys: Array = r["levels"].keys()
	keys.sort()
	for n in keys:
		var l: Dictionary = r["levels"][n]
		var first = l["first_try"]
		for v in [str(n), str(l["attempts"]), "-" if first == null else ("evet" if first else "hayır"),
				TestReport.fmt_time(l["first_complete_s"]),
				"-" if l["best_moves"] < 0 else str(l["best_moves"]), str(l["rotations"])]:
			grid.add_child(_cell(v, UiKit.TEXT))
	list.add_child(grid)


func _cell(text: String, color: Color) -> Label:
	var l := UiKit.label(text, 30, color, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _on_copy(testers: Array) -> void:
	DisplayServer.clipboard_set(TestReport.to_text(testers))
	_status.text = "Rapor panoya kopyalandı."


func _on_new_tester() -> void:
	if not _new_tester_armed:
		_new_tester_armed = true
		_new_btn.text = "Emin misin?"
		_status.text = "Tekrar dokunursan ilerleme sıfırlanır ve sıradaki testçi başlar."
		return
	GameState.start_new_tester()
	SceneRouter.goto_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.goto_menu()
