class_name BoardModel
extends RefCounted
## Bulmaca tahtasının saf mantık modeli. Görsel katmandan bağımsızdır ve testlerle doğrulanır.
##
## Hamle kuralları:
##   - Tepsiden parça yerleştirme: 1 hamle
##   - Yerleşik parçayı döndürme: 1 hamle
##   - Yerleşik parçayı başka kareye taşıma: 1 hamle
##   - Parçayı tepsiye geri koyma: 0 hamle
##   - Geri alma son işlemi ve harcadığı hamleyi iade eder
## Değişmez: her parça türü için (tepsideki + tahtadaki) = bölümdeki başlangıç havuzu.

signal changed

var level: LevelData
var move_limit: int = 0
var tiles: Dictionary = {}  # Vector2i -> {"type": int, "rot": int}
var tray: Dictionary = {}   # TileDefs.Type -> int
var moves_used: int = 0

var _history: Array[Dictionary] = []
var _blocked: Dictionary = {}


func _init(p_level: LevelData, p_move_limit: int = -1) -> void:
	level = p_level
	move_limit = p_move_limit if p_move_limit >= 0 else level.move_limit
	for c in level.blocked_cells:
		_blocked[c] = true
	reset()


func reset() -> void:
	tiles.clear()
	tray.clear()
	for t in TileDefs.TYPE_NAMES:
		tray[t] = int(level.tile_pool.get(t, 0))
	moves_used = 0
	_history.clear()
	changed.emit()


# ---------------------------------------------------------------- sorgular

func in_bounds(c: Vector2i) -> bool:
	return level.in_bounds(c)


func is_blocked(c: Vector2i) -> bool:
	return _blocked.has(c)


func is_hub(c: Vector2i) -> bool:
	return level.is_hub(c)


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)


func can_place(c: Vector2i) -> bool:
	return in_bounds(c) and not is_blocked(c) and not is_hub(c) and not tiles.has(c)


func moves_left() -> int:
	return move_limit - moves_used


func tray_count(type: int) -> int:
	return int(tray.get(type, 0))


func placed_count(type: int) -> int:
	var n := 0
	for c in tiles:
		if tiles[c]["type"] == type:
			n += 1
	return n


func can_undo() -> bool:
	return not _history.is_empty() and not is_finished()


## Hücrenin açık yön maskesi. Hedef noktaları (köy, pazar) her yöne açıktır.
func cell_mask(c: Vector2i, ignore := Vector2i(-1, -1)) -> int:
	if c == ignore:
		return 0
	if is_hub(c):
		return TileDefs.ALL
	if tiles.has(c):
		return TileDefs.mask_of(tiles[c]["type"], tiles[c]["rot"])
	return 0


## Başlangıçtan karşılıklı bağlantılarla ulaşılabilen tüm hücreler.
func reachable() -> Dictionary:
	var seen := {level.start_cell: true}
	var queue: Array[Vector2i] = [level.start_cell]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var m := cell_mask(cur)
		for d in TileDefs.DIRS:
			if m & d == 0:
				continue
			var n: Vector2i = cur + TileDefs.dir_offset(d)
			if seen.has(n) or not in_bounds(n):
				continue
			if cell_mask(n) & TileDefs.opposite(d):
				seen[n] = true
				queue.append(n)
	return seen


func is_complete() -> bool:
	var r := reachable()
	if not r.has(level.goal_cell):
		return false
	for p in level.points_of_interest:
		if not r.has(p):
			return false
	return true


func is_failed() -> bool:
	return moves_left() <= 0 and not is_complete()


func is_finished() -> bool:
	return is_complete() or is_failed()


## Bırakılan parçayı komşularına en iyi bağlanacak yöne çevirir (deterministik).
func best_rotation(type: int, c: Vector2i, ignore := Vector2i(-1, -1)) -> int:
	var best_r := 0
	var best_score := -1000000
	for r in range(TileDefs.rotation_count(type)):
		var m := TileDefs.mask_of(type, r)
		var score := 0
		for d in TileDefs.DIRS:
			if m & d == 0:
				continue
			var n: Vector2i = c + TileDefs.dir_offset(d)
			if not in_bounds(n) or is_blocked(n):
				score -= 1
				continue
			if cell_mask(n, ignore) & TileDefs.opposite(d):
				score += 10
		if score > best_score:
			best_score = score
			best_r = r
	return best_r


# ---------------------------------------------------------------- işlemler

func place_from_tray(type: int, c: Vector2i) -> bool:
	if is_finished() or moves_left() <= 0 or tray_count(type) <= 0 or not can_place(c):
		return false
	var rot := best_rotation(type, c)
	tiles[c] = {"type": type, "rot": rot}
	tray[type] -= 1
	_commit({"a": "place", "cell": c, "type": type, "rot": rot, "cost": 1})
	return true


func rotate_tile(c: Vector2i) -> bool:
	if is_finished() or moves_left() <= 0 or not tiles.has(c):
		return false
	var t: Dictionary = tiles[c]
	var old_rot: int = t["rot"]
	var new_rot := (old_rot + 1) % TileDefs.rotation_count(t["type"])
	t["rot"] = new_rot
	_commit({"a": "rotate", "cell": c, "old": old_rot, "new": new_rot, "cost": 1})
	return true


func move_tile(from: Vector2i, to: Vector2i) -> bool:
	if is_finished() or moves_left() <= 0 or not tiles.has(from) or from == to or not can_place(to):
		return false
	var t: Dictionary = tiles[from]
	var old_rot: int = t["rot"]
	var new_rot := best_rotation(t["type"], to, from)
	tiles.erase(from)
	tiles[to] = {"type": t["type"], "rot": new_rot}
	_commit({"a": "move", "from": from, "to": to, "old": old_rot, "new": new_rot, "cost": 1})
	return true


func return_to_tray(c: Vector2i) -> bool:
	if is_finished() or not tiles.has(c):
		return false
	var t: Dictionary = tiles[c]
	tiles.erase(c)
	tray[t["type"]] += 1
	_commit({"a": "remove", "cell": c, "type": t["type"], "rot": t["rot"], "cost": 0})
	return true


func undo() -> bool:
	if not can_undo():
		return false
	var h: Dictionary = _history.pop_back()
	match h["a"]:
		"place":
			tiles.erase(h["cell"])
			tray[h["type"]] += 1
		"rotate":
			tiles[h["cell"]]["rot"] = h["old"]
		"move":
			var t: Dictionary = tiles[h["to"]]
			tiles.erase(h["to"])
			tiles[h["from"]] = {"type": t["type"], "rot": h["old"]}
		"remove":
			tiles[h["cell"]] = {"type": h["type"], "rot": h["rot"]}
			tray[h["type"]] -= 1
	moves_used -= int(h["cost"])
	changed.emit()
	return true


## Reklamla devam gibi durumlar için ek hamle (ileride AdsService bağlanacak).
func add_moves(n: int) -> void:
	move_limit += n
	changed.emit()


## Testler ve hata ayıklama için durum özeti.
func signature() -> String:
	var keys := tiles.keys()
	keys.sort()
	var parts := PackedStringArray()
	for c in keys:
		parts.append("%d,%d:%d/%d" % [c.x, c.y, tiles[c]["type"], tiles[c]["rot"]])
	return "%s|%s|%d" % [";".join(parts), str(tray), moves_used]


func _commit(entry: Dictionary) -> void:
	moves_used += int(entry["cost"])
	_history.append(entry)
	changed.emit()
