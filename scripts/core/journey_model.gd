class_name JourneyModel
extends RefCounted
## Yolculuk aşaması (plan §4.2) saf mantığı: 3 şerit, engel/bonus, hızlanma, hata toleransı.
## Birimler: mesafe "şerit genişliği" cinsinden; kervan her an `distance` noktasındadır.
## Aynı seed her cihazda aynı yolu üretir. Yolculuk hatası bulmaca kazanımını silmez;
## yalnız bonusu azaltır.

const LANES := 3
const MAX_HITS := 3
const BOOST_TIME := 1.0
const BOOST_FACTOR := 1.6

const DIFFICULTY := {
	"easy": {"speed": 3.0, "gap": 2.2, "rock": 0.45},
	"medium": {"speed": 3.6, "gap": 1.7, "rock": 0.55},
	"hard": {"speed": 4.2, "gap": 1.3, "rock": 0.65},
}

var difficulty := "easy"
var duration := 10.0
var speed := 3.0
var t := 0.0
var distance := 0.0
var lane := 1
var hits := 0
var bonuses := 0
var rare := 0
var finished := false
var skipped := false
var items: Array[Dictionary] = []  # {kind: "rock"|"coin"|"rare", lane: int, y: float, done: bool}

var _boost_until := 0.0


## route_tiles: bulmacadaki rota uzunluğu (yolculuk süresi buna bağlı).
func _init(seed: int, route_tiles: int, p_difficulty: String = "easy") -> void:
	difficulty = p_difficulty if DIFFICULTY.has(p_difficulty) else "easy"
	var p: Dictionary = DIFFICULTY[difficulty]
	duration = clampf(8.0 + route_tiles * 0.8, 10.0, 22.0)
	speed = p["speed"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var total := duration * speed * BOOST_FACTOR + 4.0
	var y := 4.0
	var last_lane := -1
	while y < total:
		var l := rng.randi_range(0, LANES - 1)
		if l == last_lane:
			l = (l + 1 + rng.randi_range(0, 1)) % LANES
		last_lane = l
		var kind := "rock"
		if rng.randf() >= p["rock"]:
			kind = "rare" if rng.randf() < 0.1 else "coin"
		items.append({"kind": kind, "lane": l, "y": y, "done": false})
		y += p["gap"] * rng.randf_range(0.8, 1.2)


## Planın kuralı: bulmaca zorluğu 7+ ise yolculuk en fazla orta olur.
static func difficulty_for(level: LevelData, level_number: int, explicit: String = "") -> String:
	var d := explicit
	if d.is_empty():
		d = "easy" if level_number <= 10 else "medium"
	if level.difficulty_score >= 7 and d == "hard":
		d = "medium"
	return d


func current_speed() -> float:
	return speed * (BOOST_FACTOR if t < _boost_until else 1.0)


func move(dir: int) -> void:
	if not finished:
		lane = clampi(lane + dir, 0, LANES - 1)


func boost() -> void:
	if not finished:
		_boost_until = t + BOOST_TIME


func skip() -> void:
	skipped = true
	finished = true


## Zamanı ilerletir; bu adımda olan olayları döndürür: [{type: "hit"|"coin"|"rare", lane}]
func step(dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished:
		return events
	t += dt
	distance += current_speed() * dt
	for it in items:
		if it["done"] or it["y"] > distance:
			continue
		it["done"] = true
		if it["lane"] != lane:
			continue
		match it["kind"]:
			"rock":
				hits += 1
				events.append({"type": "hit", "lane": lane})
			"coin":
				bonuses += 1
				events.append({"type": "coin", "lane": lane})
			"rare":
				rare += 1
				events.append({"type": "rare", "lane": lane})
	if t >= duration or hits >= MAX_HITS:
		finished = true
	return events


func progress() -> float:
	return clampf(t / duration, 0.0, 1.0)


## Ödül: her bonus 2 altın, her çarpma 2 altın düşürür (en az 0); nadir mal ticaret malı verir.
func result() -> Dictionary:
	return {
		"hits": hits, "bonuses": bonuses, "rare": rare,
		"completed": hits < MAX_HITS and not skipped, "skipped": skipped,
		"gold": maxi(0, bonuses * 2 - hits * 2), "trade_goods": rare,
		"difficulty": difficulty,
	}
