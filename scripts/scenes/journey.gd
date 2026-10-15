extends Control
## Yolculuk ekranı: bulmaca kazanıldıktan sonra kısa kervan yolculuğu, sonra sonuç ekranı.

const END_DELAY := 1.2

var model: JourneyModel
var view: JourneyView
var progress: ProgressBar
var hits_label: Label
var bonus_label: Label
var info_label: Label
var _level_number := 1
var _started_ms := 0
var _ending := false


func _ready() -> void:
	var r := GameState.last_result
	var idx: int = r.get("level_index", 0)
	_level_number = idx + 1
	var level: LevelData = GameState.levels[idx]
	var seed := hash(level.level_id)
	var diff := JourneyModel.difficulty_for(level, _level_number)
	model = JourneyModel.new(seed, maxi(level.minimum_solution_moves, 3), diff,
			TownModel.journey_tolerance(GameState.data))

	var box := UiKit.build_screen(self, 12)
	var top := HBoxContainer.new()
	var title := UiKit.label(tr("JOURNEY_TITLE"), 52, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var skip := UiKit.button(tr("SKIP"), _on_skip, 90)
	skip.size_flags_horizontal = Control.SIZE_FILL
	skip.custom_minimum_size.x = 180
	top.add_child(skip)
	box.add_child(top)

	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 24
	box.add_child(progress)

	var stats := HBoxContainer.new()
	hits_label = UiKit.label("", 36, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	hits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(hits_label)
	bonus_label = UiKit.label("", 36, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(bonus_label)
	box.add_child(stats)

	view = JourneyView.new()
	view.model = model
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.swiped.connect(func(dir: int) -> void:
		model.move(dir)
		AudioManager.play_sfx("journey_swipe", 0.08))
	view.tapped.connect(func() -> void:
		model.boost()
		AudioManager.play_sfx("journey_boost"))
	box.add_child(view)

	info_label = UiKit.label(tr("JOURNEY_HELP"), 32, UiKit.MUTED)
	box.add_child(info_label)

	_started_ms = Time.get_ticks_msec()
	AudioManager.play_music("journey")
	AnalyticsService.track("journey_start", {"level_number": _level_number, "difficulty": diff})
	_refresh()


func _process(delta: float) -> void:
	if _ending:
		return
	for e in model.step(minf(delta, 0.05)):
		match e["type"]:
			"coin":
				AudioManager.play_sfx("journey_coin", 0.05)
			"rare":
				AudioManager.play_sfx("journey_rare")
			"hit":
				AudioManager.play_sfx("journey_hit")
				AudioManager.vibrate(60)
		if e["type"] == "hit":
			view.flash = 1.0
			AnalyticsService.track("journey_hit", {"level_number": _level_number, "hits": model.hits})
	_refresh()
	if model.finished:
		_finish()


func _refresh() -> void:
	progress.value = model.progress()
	hits_label.text = tr("JOURNEY_HITS") % [model.hits, model.max_hits]
	bonus_label.text = tr("JOURNEY_BONUS") % (model.bonuses + model.rare)


func _on_skip() -> void:
	if not _ending:
		model.skip()
		_finish()


func _finish() -> void:
	_ending = true
	var res := model.result()
	AnalyticsService.track("journey_complete", {"level_number": _level_number, "hits": res["hits"],
			"bonuses": res["bonuses"], "completed": res["completed"], "skipped": res["skipped"],
			"duration_ms": Time.get_ticks_msec() - _started_ms})
	GameState.record_journey(res)
	info_label.text = tr("JOURNEY_TIRED") if res["hits"] >= model.max_hits else tr("JOURNEY_DONE")
	if res["skipped"]:
		SceneRouter.goto_result()
		return
	await get_tree().create_timer(END_DELAY).timeout
	SceneRouter.goto_result()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_skip()
