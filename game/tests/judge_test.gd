extends SceneTree

const Judge = preload("res://judge.gd")

func _initialize() -> void:
	assert(Judge.grade(0.0) == "PERFECT")
	assert(Judge.grade(-0.055) == "PERFECT")
	assert(Judge.grade(0.08) == "GOOD")
	assert(Judge.grade(-0.16) == "OK")
	assert(Judge.grade(0.181) == "")
	var notes: Array = [{"time": 1.0, "lane": 0, "done": false}, {"time": 1.0, "lane": 1, "done": false}]
	assert(Judge.nearest(notes, 0, 1.01) == 0)
	assert(Judge.nearest(notes, 1, 1.01) == 1)
	notes[0]["done"] = true
	assert(Judge.nearest(notes, 0, 1.01) == -1)
	assert(Judge.nearest(notes, 1, 1.3) == -1)
	var chart: Array = JSON.parse_string(FileAccess.get_file_as_string("res://chart.json"))
	var song: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://song.json"))
	assert(chart.size() == int(song["note_count"]))
	assert(float(song["bpm"]) == 148.0)
	var beat := 60.0 / float(song["bpm"])
	var last_lane := [-1.0, -1.0]
	var previous := -1.0
	for note in chart:
		assert(float(note["time"]) >= previous)
		assert(int(note["lane"]) in [0, 1])
		assert(float(note["time"]) >= 2.0)
		assert(float(note["time"]) < float(song["duration"]) - 2.0)
		var halfbeat := (float(note["time"]) - float(song["grid_offset_seconds"])) / (beat / 2.0)
		assert(absf(halfbeat - roundf(halfbeat)) < 0.00001)
		var lane := int(note["lane"])
		assert(float(note["time"]) - last_lane[lane] >= 0.1599)
		last_lane[lane] = float(note.get("end_time", note["time"]))
		assert(note["kind"] in ["tap", "hold", "roll"])
		if note["kind"] != "tap":
			assert(float(note["end_time"]) > float(note["time"]))
			assert(float(note["end_time"]) < float(song["duration"]))
		if note["kind"] == "roll":
			assert(int(note["required_hits"]) >= 3)
		previous = float(note["time"])
	# Full-chart simulated perfect inputs: each note is consumed exactly once,
	# including simultaneous notes on different lanes.
	var play_notes: Array = chart.duplicate(true)
	for note in play_notes:
		note["done"] = false
	var consumed := 0
	for note in chart:
		var index: int = Judge.nearest(play_notes, int(note["lane"]), float(note["time"]))
		assert(index >= 0)
		play_notes[index]["done"] = true
		consumed += 1
	assert(consumed == chart.size())
	print("PASS: judgment boundaries, full chart, 148 BPM grid, song bounds, per-lane spacing; %d notes" % consumed)
	quit()
