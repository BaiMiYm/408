extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chart: Array = JSON.parse_string(FileAccess.get_file_as_string("res://chart-hard.json"))
	var song: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://song-hard.json"))
	var normal_info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://song.json"))
	assert(chart.size() == int(song["note_count"]) and chart.size() > int(normal_info["note_count"]))
	var last := [-1.0, -1.0]
	var previous := -1.0
	var beat := 60.0 / float(song["bpm"])
	var types := {"tap": 0, "hold": 0, "roll": 0}
	var doubles := 0
	var fast_pairs := 0
	for i in chart.size():
		var n: Dictionary = chart[i]
		var t := float(n["time"])
		var lane := int(n["lane"])
		assert(t >= previous and lane in [0, 1])
		assert(t >= 2 and t < float(song["duration"]) - 2)
		var grid := (t - float(song["grid_offset_seconds"])) / (beat / 4)
		assert(absf(grid - roundf(grid)) < 0.00002)
		# No occupied-lane collisions, including a held note's tail. One touch
		# source per lane can complete the whole chart without a third finger.
		assert(t - last[lane] >= 0.095)
		if t - last[lane] < 0.12:
			fast_pairs += 1
		last[lane] = float(n.get("end_time", t))
		assert(last[lane] < float(song["duration"]) - 1)
		types[n["kind"]] += 1
		if i > 0 and t == float(chart[i - 1]["time"]):
			assert(lane != int(chart[i - 1]["lane"]))
			if n["kind"] == "tap" and chart[i - 1]["kind"] == "tap":
				doubles += 1
		previous = t
	for kind in types:
		assert(types[kind] == int(song["note_types"][kind]))
	assert(doubles == int(song["double_accents"]) and doubles > 0)
	assert(fast_pairs >= 20)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.offset_ms = 0
	scene.bindings.reset()
	assert(scene.chart_index == 1)
	for difficulty in [0, 1]:
		scene._select_chart(difficulty)
		for keyboard in [false, true]:
			scene._start()
			scene.music.stop()
			preload("res://tests/autoplay.gd").play(scene, keyboard)
			assert(scene.counts["MISS"] == 0 and scene.session.sources.is_empty())
			assert(scene.score == scene.notes.size() * 1000 and scene.combo == scene.notes.size())
			scene._finish()
			assert(scene.mode == "result")
			scene._pointer(Vector2(640, 550))
			assert(scene.chart_index == difficulty and scene.score == 0)
			scene.music.stop()
			scene.mode = "menu"
	# The visible menu control switches metadata and the chart used at start.
	scene._pointer(Vector2(160, 278))
	assert(scene.chart_index == 0 and int(scene.song["note_count"]) == int(normal_info["note_count"]))
	scene._pointer(Vector2(160, 278))
	assert(scene.chart_index == 1 and int(scene.song["note_count"]) == chart.size())
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: challenge metadata, sixteenth grid, fast pairs, doubles, lane occupancy; both difficulties on keyboard/two-touch input, retry, menu switch")
	quit()
