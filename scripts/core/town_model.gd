class_name TownModel
extends RefCounted
## Kasaba kuralları (plan §4.3, §8): bina seviyeleri, açılma bölümü, maliyet ve etkiler.
## Kurallar:
##   - Kervansaray ilk oturumda açılır; seviyesi "kasaba seviyesi"dir (oyuncu seviyesi yerine).
##   - Diğer binalar kervansaray seviyesini geçemez.
##   - İlk anlamlı yükseltme yalnız oyun içi altınla alınabilir (reklam/ödeme gerekmez).
## Tüm fonksiyonlar kayıt sözlüğü (GameState.data) üzerinde çalışır; saf mantıktır.

const DATA_PATH := "res://data/buildings.json"

static var _defs: Array = []


static func defs() -> Array:
	if _defs.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_defs = d["buildings"] if typeof(d) == TYPE_DICTIONARY else []
	return _defs


static func def(id: String) -> Dictionary:
	for b in defs():
		if b["id"] == id:
			return b
	return {}


static func level_of(save: Dictionary, id: String) -> int:
	return int(save.get("building_levels", {}).get(id, 0))


static func is_unlocked(save: Dictionary, id: String) -> bool:
	return int(save.get("last_completed_level", 0)) >= int(def(id).get("unlock_level", 0))


static func next_cost(save: Dictionary, id: String) -> Dictionary:
	var b := def(id)
	var lv := level_of(save, id)
	if b.is_empty() or lv >= int(b["max_level"]):
		return {}
	return b["cost"][lv]


## Yükseltme engeli: "" (yükseltilebilir) veya neden: locked / max / town_level / gold / trade_goods
static func block_reason(save: Dictionary, id: String) -> String:
	var b := def(id)
	if b.is_empty():
		return "unknown"
	if not is_unlocked(save, id):
		return "locked"
	var lv := level_of(save, id)
	if lv >= int(b["max_level"]):
		return "max"
	if id != "kervansaray" and lv >= level_of(save, "kervansaray"):
		return "town_level"
	var cost := next_cost(save, id)
	var cur: Dictionary = save.get("currencies", {})
	for k in cost:
		if int(cur.get(k, 0)) < int(cost[k]):
			return k
	return ""


## Bedeli düşer ve seviyeyi artırır. Başarılıysa true.
static func upgrade(save: Dictionary, id: String) -> bool:
	if block_reason(save, id) != "":
		return false
	var cost := next_cost(save, id)
	var cur: Dictionary = save["currencies"]
	for k in cost:
		cur[k] = int(cur.get(k, 0)) - int(cost[k])
	if not save.has("building_levels"):
		save["building_levels"] = {}
	save["building_levels"][id] = level_of(save, id) + 1
	return true


static func _value(save: Dictionary, id: String) -> int:
	var b := def(id)
	var vals: Array = b.get("values", [])
	var lv := level_of(save, id)
	return int(vals[lv]) if lv < vals.size() else 0


## Bulmaca altın ödülüne yüzde ek (Pazar).
static func gold_bonus_percent(save: Dictionary) -> int:
	return _value(save, "pazar")


## Yolculukta ek çarpma hakkı (Kuyu).
static func journey_tolerance(save: Dictionary) -> int:
	return _value(save, "kuyu")


static func town_level(save: Dictionary) -> int:
	return level_of(save, "kervansaray")


static func any_upgrade_available(save: Dictionary) -> bool:
	for b in defs():
		if block_reason(save, b["id"]) == "":
			return true
	return false
