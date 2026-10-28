extends RefCounted

const Judge = preload("res://judge.gd")
const RELEASE_TOLERANCE := 0.080
const RESUME_GRACE := 0.500
signal judged(note: Dictionary, grade: String)
signal prompted(lane: int, message: String)

var notes: Array = []
var sources: Dictionary = {}
var score := 0
var combo := 0
var best_combo := 0
var counts := {"PERFECT": 0, "GOOD": 0, "OK": 0, "MISS": 0}
var suspended := false

func reset(chart: Array) -> void:
	notes = chart.duplicate(true)
	for note in notes:
		note["done"] = false
		note["active"] = false
		note["hits"] = 0
		note["resume_until"] = -1.0
		note["head_grade"] = "PERFECT"
	sources.clear()
	score = 0
	combo = 0
	best_combo = 0
	suspended = false
	for key in counts:
		counts[key] = 0

func lane_held(lane: int) -> bool:
	return lane in sources.values()

func press(source: String, lane: int, time: float) -> void:
	if suspended or sources.has(source):
		return
	update(time)
	if suspended:
		return
	sources[source] = lane
	for note in notes:
		if note["done"] or not note["active"] or int(note["lane"]) != lane:
			continue
		if note.get("kind", "tap") == "hold":
			# Either key assigned to this lane may sustain the same hold.
			note["resume_until"] = -1.0
			return
		if note.get("kind", "tap") == "roll":
			_roll_hit(note)
			return
	var index: int = Judge.nearest(notes, lane, time)
	if index == -1:
		return
	var note: Dictionary = notes[index]
	var kind: String = note.get("kind", "tap")
	if kind == "roll":
		note["active"] = true
		_roll_hit(note)
	elif kind == "hold":
		note["active"] = true
		note["head_grade"] = Judge.grade(time - float(note["time"]))
		prompted.emit(lane, "HOLD")
	else:
		_resolve(note, Judge.grade(time - float(note["time"])))

func release(source: String, time: float) -> void:
	if not sources.has(source):
		return
	var lane: int = sources[source]
	sources.erase(source)
	if suspended or lane_held(lane):
		return
	for note in notes:
		if note["done"] or not note["active"] or int(note["lane"]) != lane or note.get("kind", "tap") != "hold":
			continue
		if time >= float(note["end_time"]) - RELEASE_TOLERANCE:
			var grade: String = note["head_grade"]
			if time < float(note["end_time"]) and grade == "PERFECT":
				grade = "GOOD"
			_resolve(note, grade)
		elif time > float(note["resume_until"]):
			_resolve(note, "MISS")

func _roll_hit(note: Dictionary) -> void:
	note["hits"] = mini(int(note["required_hits"]), int(note["hits"]) + 1)
	prompted.emit(int(note["lane"]), "连打 %d / %d" % [note["hits"], note["required_hits"]])

func update(time: float) -> void:
	if suspended:
		return
	for note in notes:
		if suspended:
			return
		if note["done"]:
			continue
		var kind: String = note.get("kind", "tap")
		if kind == "roll":
			if time > float(note["end_time"]):
				_resolve(note, "PERFECT" if int(note["hits"]) >= int(note["required_hits"]) else "MISS")
		elif kind == "hold" and note["active"]:
			var held := lane_held(int(note["lane"]))
			if held and time >= float(note["end_time"]):
				_resolve(note, note["head_grade"])
			elif not held and time > float(note["resume_until"]):
				_resolve(note, "MISS")
		elif time - float(note["time"]) > Judge.WINDOW:
			_resolve(note, "MISS")

func suspend() -> void:
	suspended = true
	sources.clear()

func resume(time: float) -> void:
	suspended = false
	sources.clear()
	for note in notes:
		if not note["done"] and note["active"] and note.get("kind", "tap") == "hold":
			note["resume_until"] = time + RESUME_GRACE
			prompted.emit(int(note["lane"]), "续按长条")

func finish(time: float) -> void:
	update(time)
	for note in notes:
		if suspended:
			return
		if not note["done"]:
			_resolve(note, "MISS")
	sources.clear()

func _resolve(note: Dictionary, grade: String) -> void:
	if note["done"]:
		return
	note["done"] = true
	note["active"] = false
	counts[grade] += 1
	if grade == "MISS":
		combo = 0
	else:
		combo += 1
		best_combo = maxi(best_combo, combo)
		score += {"PERFECT": 1000, "GOOD": 700, "OK": 300}[grade]
	judged.emit(note, grade)
