class_name RhythmJudge
extends RefCounted

const PERFECT := 0.055
const GOOD := 0.115
const WINDOW := 0.180

static func grade(error: float) -> String:
	var distance := absf(error)
	if distance <= PERFECT:
		return "PERFECT"
	if distance <= GOOD:
		return "GOOD"
	if distance <= WINDOW:
		return "OK"
	return ""

static func nearest(notes: Array, lane: int, time: float) -> int:
	var closest := WINDOW + 0.000001
	var found := -1
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if note["done"] or note.get("active", false) or int(note["lane"]) != lane:
			continue
		if note.get("kind", "tap") == "roll" and time >= float(note["time"]) - WINDOW and time <= float(note["end_time"]):
			var roll_distance := maxf(0.0, float(note["time"]) - time)
			if roll_distance < closest:
				closest = roll_distance
				found = i
			continue
		var distance := absf(float(note["time"]) - time)
		if distance <= WINDOW and distance < closest:
			closest = distance
			found = i
	return found
