class_name RouteSolver
extends RefCounted
## Bölümün çözülebilir olduğunu ve en az kaç parçayla çözüldüğünü bulur.
##
## Çözüm bir ağaçtır: başlangıç, hedef ve tüm pazarlar (hub) birbirine bağlanır.
## - Düz/köşe parçası bir yolu sürdürür (2 açıklık).
## - Kavşak parçası yolu ikiye ayırır (3 açıklık); ikinci kol "bekleyen dal" olarak sıraya girer.
## - Hub'lar (köy, pazar, hedef) her yöne açıktır; bir hub'dan birden fazla dal çıkabilir.
## Yöntem: parça sayısı üzerinde yinelemeli derinleşen DFS (IDDFS). Her dal bir hub'da biter.
## Parça havuzu (düz/köşe/kavşak sayısı) aşılmaz. Sonuç en az parçalı ağaçtır.

const DEFAULT_MAX_TILES := 40
const NODE_BUDGET := 4000000
const HUB_REEMIT := -1

var _level: LevelData
var _required: Dictionary = {}
var _blocked: Dictionary = {}
var _visited: Dictionary = {}
var _masks: Dictionary = {}     # parça hücresi -> açıklık maskesi
var _pending: Array = []        # [hücre, yön]; yön HUB_REEMIT ise hub'dan yeni dal
var _used: Dictionary = {}
var _limit: int = 0
var _found: Dictionary = {}
var _order: Array[Vector2i] = []   # parçaların yerleştirilme sırası (oynanış sırası)
var _found_order: Array[Vector2i] = []
var nodes: int = 0


static func solve(level: LevelData, max_tiles: int = DEFAULT_MAX_TILES) -> Dictionary:
	var s := RouteSolver.new()
	return s._solve(level, max_tiles)


func _solve(level: LevelData, max_tiles: int) -> Dictionary:
	_level = level
	_required.clear()
	_required[level.goal_cell] = true
	for p in level.points_of_interest:
		_required[p] = true
	for b in level.blocked_cells:
		_blocked[b] = true
	# Ağaç, havuzdaki parça sayısından ve boş hücre sayısından büyük olamaz.
	var pool_total := 0
	for t in level.tile_pool:
		pool_total += int(level.tile_pool[t])
	var free_cells := level.grid_width * level.grid_height - _blocked.size() - 2 - level.points_of_interest.size()
	max_tiles = mini(max_tiles, mini(pool_total, free_cells))
	for limit in range(0, max_tiles + 1):
		_limit = limit
		_visited = {level.start_cell: true}
		_masks.clear()
		_order.clear()
		_pending.clear()
		_used = {}
		for t in TileDefs.TYPE_NAMES:
			_used[t] = 0
		if _dfs(level.start_cell, 0, 0, 0):
			var placements := placements_from_masks(_found, _found_order)
			return {
				"solvable": true,
				"min_moves": placements.size(),
				"path": _found.keys(),
				"placements": placements,
				"nodes": nodes,
			}
		if nodes > NODE_BUDGET:
			break
	return {"solvable": false, "min_moves": -1, "path": [], "placements": [], "nodes": nodes}


func _pool(t: int) -> int:
	return int(_level.tile_pool.get(t, 0))


## cur: bulunulan hücre; in_side: cur'a girilen kenar (hub için 0).
func _dfs(cur: Vector2i, in_side: int, tiles: int, req: int) -> bool:
	nodes += 1
	if nodes > NODE_BUDGET:
		return false
	var lb := maxi(_min_dist_to_remaining(cur) - 1, 0)
	if _level.is_hub(cur):
		if req == _required.size() and _pending.is_empty():
			_found = _masks.duplicate()
			_found_order = _order.duplicate()
			return true
		# a) Bu dal burada biter; bekleyen bir dala geç.
		if not _pending.is_empty():
			var br: Array = _pending.pop_back()
			var ok := false
			if br[1] == HUB_REEMIT:
				ok = _dfs(br[0], 0, tiles, req)
			else:
				ok = _go(br[0], br[1], tiles, req)
			if ok:
				return true
			_pending.push_back(br)
		if req == _required.size():
			return false
		if tiles + lb > _limit:
			return false
		# b) Hub'dan yeni yöne devam; istenirse hub'ı daha sonra yeniden dallanmak üzere sıraya koy.
		for d in TileDefs.DIRS:
			if _go(cur, d, tiles, req):
				return true
			_pending.push_back([cur, HUB_REEMIT])
			var ok2 := _go(cur, d, tiles, req)
			_pending.pop_back()
			if ok2:
				return true
		return false
	# Parça hücresi: tek çıkış (düz/köşe) veya iki çıkış (kavşak).
	if tiles + lb > _limit:
		return false
	for d in TileDefs.DIRS:
		if d == in_side:
			continue
		if _try_tile(cur, in_side | d, d, 0, tiles, req):
			return true
	if _used[TileDefs.Type.JUNCTION] < _pool(TileDefs.Type.JUNCTION):
		for i in range(TileDefs.DIRS.size()):
			var d1: int = TileDefs.DIRS[i]
			if d1 == in_side:
				continue
			for j in range(i + 1, TileDefs.DIRS.size()):
				var d2: int = TileDefs.DIRS[j]
				if d2 == in_side:
					continue
				if _try_tile(cur, in_side | d1 | d2, d1, d2, tiles, req):
					return true
	return false


func _try_tile(cur: Vector2i, mask: int, out1: int, out2: int, tiles: int, req: int) -> bool:
	var t := TileDefs.type_for_mask(mask)
	if t == -1 or _used[t] >= _pool(t):
		return false
	_used[t] += 1
	_masks[cur] = mask
	_order.append(cur)
	if out2 != 0:
		_pending.push_back([cur, out2])
	var ok := _go(cur, out1, tiles, req)
	if not ok:
		if out2 != 0:
			_pending.pop_back()
		_masks.erase(cur)
		_order.pop_back()
		_used[t] -= 1
	return ok


func _go(frm: Vector2i, d: int, tiles: int, req: int) -> bool:
	var n: Vector2i = frm + TileDefs.dir_offset(d)
	if not _level.in_bounds(n) or _blocked.has(n):
		return false
	var n_hub := _level.is_hub(n)
	if _visited.has(n):
		# Bir dal, zaten bağlı bir hub'a girerek bitebilir (parçadan gelmek şartıyla).
		if not n_hub or _level.is_hub(frm):
			return false
		return _dfs(n, TileDefs.opposite(d), tiles, req)
	var new_tiles := tiles + (0 if n_hub else 1)
	if new_tiles > _limit:
		return false
	_visited[n] = true
	var ok := _dfs(n, TileDefs.opposite(d), new_tiles, req + (1 if _required.has(n) else 0))
	if not ok:
		_visited.erase(n)
	return ok


func _min_dist_to_remaining(cur: Vector2i) -> int:
	var best := 1000000
	for r in _required:
		if _visited.has(r):
			continue
		best = mini(best, absi(r.x - cur.x) + absi(r.y - cur.y))
	return 0 if best == 1000000 else best


## Hücre->maske sözlüğünden parça yerleşimleri: [{cell, type, rot}], verilen sırayla
## (çözücünün ağacı kurduğu sıra; başlangıçtan dışarı doğru).
static func placements_from_masks(masks: Dictionary, order: Array = []) -> Array[Dictionary]:
	var cells: Array = order if order.size() == masks.size() else masks.keys()
	var out: Array[Dictionary] = []
	for c in cells:
		var t := TileDefs.type_for_mask(masks[c])
		out.append({"cell": c, "type": t, "rot": TileDefs.rotation_for_mask(t, masks[c])})
	return out
