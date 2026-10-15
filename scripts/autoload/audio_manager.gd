extends Node
## Ses yöneticisi (plan §5 AudioManager, §12 ses planı).
## - Müzik ve efekt ayrı kanallarda (Music / SFX bus); her kanal ve titreşim ayarlardan ayrı kapatılır.
## - Müzik parçaları arasında yumuşak geçiş; uygulama arka plana geçince müzik durur.
## - Efektler küçük bir oynatıcı havuzundan çalar; aynı efekt art arda gelirse hafif perde farkı.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const POOL_SIZE := 8
const FADE_TIME := 0.8

## Efekt başına ses düzeyi (dB) — sentez seviyelerini dengelemek için.
const SFX_DB := {
	"tile_invalid": -9.0, "level_fail": -5.0, "hint": -6.0, "ui_tap": -8.0,
	"tile_pick": -4.0, "tile_place": -2.0, "journey_swipe": -6.0, "journey_boost": -4.0,
}
const SFX_NAMES := [
	"ui_tap", "tile_pick", "tile_place", "tile_rotate", "tile_return", "tile_invalid", "undo",
	"route_connect", "level_win", "level_fail", "star_1", "star_2", "star_3", "hint",
	"journey_coin", "journey_rare", "journey_hit", "journey_swipe", "journey_boost",
	"building_build", "building_upgrade",
]
const MUSIC_NAMES := ["puzzle_world1", "town", "journey"]

var current_music := ""
var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _music_paused_by_focus := false
var played_log: Array[String] = []  # testler için son çalınan efektler


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_active_music = _music_a
	for n in SFX_NAMES:
		var path := SFX_PATH % n
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	apply_settings()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _settings() -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	return gs.data.get("settings", {}) if gs != null else {}


func is_enabled(key: String) -> bool:
	return bool(_settings().get(key, true))


## Ayar değişince kanalları sustur/aç.
func apply_settings() -> void:
	_set_bus_mute("Music", not is_enabled("music"))
	_set_bus_mute("SFX", not is_enabled("sfx"))


func _set_bus_mute(bus: String, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, mute)


func has_sfx(sfx_name: String) -> bool:
	return _sfx.has(sfx_name)


func play_sfx(sfx_name: String, pitch_jitter: float = 0.0) -> void:
	played_log.append(sfx_name)
	if played_log.size() > 64:
		played_log.pop_front()
	if not _sfx.has(sfx_name) or not is_enabled("sfx"):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = float(SFX_DB.get(sfx_name, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(track: String) -> void:
	if track == current_music:
		return
	current_music = track
	var path := MUSIC_PATH % track
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var incoming := _music_b if _active_music == _music_a else _music_a
	var outgoing := _active_music
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, FADE_TIME)
	tw.tween_property(outgoing, "volume_db", -60.0, FADE_TIME)
	tw.chain().tween_callback(outgoing.stop)
	_active_music = incoming


func stop_music() -> void:
	current_music = ""
	var tw := create_tween()
	tw.tween_property(_active_music, "volume_db", -60.0, FADE_TIME)
	tw.tween_callback(_active_music.stop)


func vibrate(ms: int = 40) -> void:
	if is_enabled("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func is_music_playing() -> bool:
	return _active_music.playing and not _active_music.stream_paused


## Plan §12: uygulama arka plana geçince müzik durur, öne gelince devam eder.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _active_music.playing:
				_active_music.stream_paused = true
				_music_paused_by_focus = true
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _music_paused_by_focus:
				_active_music.stream_paused = false
				_music_paused_by_focus = false
