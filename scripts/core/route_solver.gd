class_name RouteSolver
extends RefCounted
## Bölümün çözülebilir olduğunu ve en az kaç parçayla çözüldüğünü bulur.
## Yöntem: parça sayısı üzerinde yinelemeli derinleşen DFS (IDDFS), parça havuzu sınırlı.
## Rota; başlangıçtan çıkıp tüm ilgi noktalarından ve hedeften geçen basit bir yoldur.
## Hedef noktaları (köy/pazar) her yöne açık olduğundan rota bunların içinden dönebilir.

const DEFAULT_MAX_TILES := 40
const NODE_BUDGET := 3000000

var _level: LevelData
var _required: Dictionary = {}
var _blocked: Dictionary = {}
var _visited: Dictionary = {}
var _path: Array[Vector2i] = []
var _used: Dictionary = {}
var _limit: int = 0
var _found: Array[Vector2i] = []
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
	for limit in range(0, max_tiles + 1):
		_limit = limit
		_visited = {level.start_cell: true}
		_path = [level.start_cell]
		_used = {TileDefs.Type.STRAIGHT: 0, TileDefs.Type.CORNER: 0}
		if _dfs(level.start_cell, 0, 0):
			var placements := placements_for_path(level, _found)
			return {
				"solvable": true,
				"min_moves": placements.size(),
				"path": _found,
				"placements": placements,
				"nodes": nodes,
			}
		if nodes > NODE_BUDGET:
			break
	return {"solvable": false, "min_moves": -1, "path": [], "placements": [], "nodes": nodes}


func _dfs(cur: Vector2i, tiles_used: int, req_count: int) -> bool:
	nodes += 1
	if nodes > NODE_BUDGET:
		return false
	var cur_is_hub := _level.is_hub(cur)
	if cur_is_hub and req_count == _required.size():
		_found = _path.duplicate()
		return true
	var lb := _min_dist_to_remaining(cur) - 1
	if tiles_used + maxi(lb, 0) > _limit:
		return false
	for d in TileDefs.DIRS:
		var n: Vector2i = cur + TileDefs.dir_offset(d)
		if not _level.in_bounds(n) or _blocked.has(n) or _visited.has(n):
			continue
		var t := -1
		if not cur_is_hub:
			var prev: Vector2i = _path[_path.size() - 2]
			t = TileDefs.type_for_mask(TileDefs.dir_between(cur, prev) | d)
			if _used[t] >= int(_level.tile_pool.get(t, 0)):
				continue
			_used[t] += 1
		var n_is_hub := _level.is_hub(n)
		var new_tiles := tiles_used + (0 if n_is_hub else 1)
		if new_tiles <= _limit:
			_visited[n] = true
			_path.append(n)
			if _dfs(n, new_tiles, req_count + (1 if _required.has(n) else 0)):
				return true
			_path.pop_back()
			_visited.erase(n)
		if t != -1:
			_used[t] -= 1
	return false


func _min_dist_to_remaining(cur: Vector2i) -> int:
	var best := 1000000
	for r in _required:
		if _visited.has(r):
			continue
		best = mini(best, absi(r.x - cur.x) + absi(r.y - cur.y))
	return 0 if best == 1000000 else best


## Rota hücre listesinden parça yerleşimlerini çıkarır: [{cell, type, rot}]
static func placements_for_path(level: LevelData, path: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, path.size() - 1):
		var c: Vector2i = path[i]
		if level.is_hub(c):
			continue
		var mask := TileDefs.dir_between(c, path[i - 1]) | TileDefs.dir_between(c, path[i + 1])
		var t := TileDefs.type_for_mask(mask)
		out.append({"cell": c, "type": t, "rot": TileDefs.rotation_for_mask(t, mask)})
	return out
