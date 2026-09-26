class_name TestReport
extends RefCounted
## Analitik olaylarından testçi bazlı Kapı 1 özeti üretir (saf mantık, test edilir).

const TERMINAL := ["level_complete", "level_fail", "level_quit", "level_restart"]


## Her testçi için: {tester, start, end, duration_s, reached_level3_s, furthest, levels: {n: {...}}}
static func build(events: Array) -> Array[Dictionary]:
	var by_tester: Dictionary = {}
	var order: Array = []
	for ev in events:
		var t := int(ev.get("tester", 1))
		if not by_tester.has(t):
			by_tester[t] = _new_tester(t, float(ev.get("event_time", 0.0)))
			order.append(t)
		_apply(by_tester[t], ev)
	var out: Array[Dictionary] = []
	for t in order:
		var r: Dictionary = by_tester[t]
		r["duration_s"] = int(r["end"] - r["start"])
		out.append(r)
	return out


static func _new_tester(t: int, time: float) -> Dictionary:
	return {"tester": t, "start": time, "end": time, "duration_s": 0,
			"reached_level3_s": -1, "furthest": 0, "levels": {}}


static func _level(r: Dictionary, n: int) -> Dictionary:
	if not r["levels"].has(n):
		r["levels"][n] = {"attempts": 0, "completes": 0, "fails": 0, "first_try": null,
				"first_complete_s": -1.0, "best_moves": -1, "stars": 0, "placed": 0,
				"rotations": 0, "undos": 0, "assist": false}
	return r["levels"][n]


static func _apply(r: Dictionary, ev: Dictionary) -> void:
	var time := float(ev.get("event_time", r["end"]))
	r["end"] = maxf(r["end"], time)
	var name := str(ev.get("event", ""))
	if not ev.has("level_number"):
		return
	var n := int(ev["level_number"])
	var l := _level(r, n)
	match name:
		"level_start":
			l["attempts"] += 1
			r["furthest"] = maxi(r["furthest"], n)
			if n >= 3 and r["reached_level3_s"] < 0:
				r["reached_level3_s"] = int(time - r["start"])
		"level_restart":
			l["attempts"] += 1
		"level_complete":
			l["completes"] += 1
			var mv := int(ev.get("moves_used", -1))
			l["best_moves"] = mv if l["best_moves"] < 0 else mini(l["best_moves"], mv)
			l["stars"] = maxi(l["stars"], int(ev.get("stars", 0)))
			if l["first_complete_s"] < 0:
				l["first_complete_s"] = float(ev.get("duration_ms", 0)) / 1000.0
		"level_fail":
			l["fails"] += 1
		"tile_placed":
			l["placed"] += 1
		"tile_rotated":
			l["rotations"] += 1
		"tile_undo":
			l["undos"] += 1
		"assist_triggered":
			l["assist"] = true
	if TERMINAL.has(name) and l["first_try"] == null:
		l["first_try"] = name == "level_complete"


static func gate(testers: Array) -> Dictionary:
	var reached := 0
	for r in testers:
		if r["reached_level3_s"] >= 0:
			reached += 1
	return {"testers": testers.size(), "reached_level3": reached}


static func fmt_time(seconds: float) -> String:
	if seconds < 0:
		return "-"
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## Panoya kopyalanacak düz metin rapor.
static func to_text(testers: Array) -> String:
	var g := gate(testers)
	var lines := PackedStringArray()
	lines.append("KERVANYA TEST RAPORU")
	lines.append("3. bölüme ulaşan testçi: %d / %d (hedef: 5 testçiden en az 4)" % [g["reached_level3"], g["testers"]])
	for r in testers:
		lines.append("")
		lines.append("Testçi %d | toplam %s | 3. bölüme ulaşma: %s | en uzak bölüm: %d" % [
			r["tester"], fmt_time(r["duration_s"]), fmt_time(r["reached_level3_s"]), r["furthest"]])
		lines.append("bölüm | deneme | ilk denemede | ilk bitiş süresi | en iyi hamle | yıldız | döndürme | geri al | ipucu")
		var keys: Array = r["levels"].keys()
		keys.sort()
		for n in keys:
			var l: Dictionary = r["levels"][n]
			lines.append("%d | %d | %s | %s | %s | %d | %d | %d | %s" % [
				n, l["attempts"], _yes_no(l["first_try"]), fmt_time(l["first_complete_s"]),
				"-" if l["best_moves"] < 0 else str(l["best_moves"]), l["stars"],
				l["rotations"], l["undos"], "evet" if l["assist"] else "-"])
	return "\n".join(lines)


static func _yes_no(v) -> String:
	if v == null:
		return "-"
	return "evet" if v else "hayır"
