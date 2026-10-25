extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check_chart(chart: Array, info: Dictionary) -> void:
	assert(chart.size() == int(info["note_count"]) and chart.size() > 100)
	var beat := 60.0 / float(info["bpm"])
	var previous := -1.0
	var last := [-1.0, -1.0]
	var types := {"tap": 0, "hold": 0, "roll": 0}
	var presses := 0
	var doubles := 0
	for i in chart.size():
		var n: Dictionary = chart[i]
		var t := float(n["time"])
		var lane := int(n["lane"])
		assert(lane in [0, 1] and t >= previous)
		assert(t >= 2 and t < float(info["duration"]) - 2)
		var grid := (t - float(info["grid_offset_seconds"])) / (beat / 4)
		assert(absf(grid - roundf(grid)) < 0.00004)
		assert(t - last[lane] >= beat / 4 - 0.00001)
		last[lane] = float(n.get("end_time", t))
		assert(last[lane] < float(info["duration"]) - 1)
		assert(n["kind"] in types)
		if n["kind"] != "tap":
			assert(float(n["end_time"]) > t)
		types[n["kind"]] += 1
		presses += int(n.get("required_hits", 1))
		if i > 0 and t == float(chart[i - 1]["time"]):
			assert(lane != int(chart[i - 1]["lane"]))
			if n["kind"] == "tap" and chart[i - 1]["kind"] == "tap":
				doubles += 1
		previous = t
	for kind in types:
		assert(types[kind] == int(info["note_types"][kind]))
	assert(presses == int(info["required_presses"]))
	assert(doubles == int(info["double_accents"]))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(info["audio"]))
	assert(hash.finish().hex_encode() == info["audio_sha256"])

func _touch(scene: Node, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = pos
	event.pressed = true
	scene._input(event)
	event.pressed = false
	scene._input(event)

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.offset_ms = 0
	scene.bindings.reset()
	assert(scene.playlist.size() == 4 and scene.song_index == 0)
	# Back wraps to the last track; forward wraps back to the first.
	_touch(scene, Vector2(435, 130))
	assert(scene.song_index == 3)
	_touch(scene, Vector2(840, 130))
	assert(scene.song_index == 0 and scene.chart_index == 1)
	for index in range(1, 4):
		_touch(scene, Vector2(840, 130))
		assert(scene.song_index == index and scene.chart_index == 0)
		assert(scene.session.sources.is_empty() and not scene.music.playing)
		var info: Dictionary = scene.song
		assert(scene.music.stream.resource_path == info["audio"])
		assert(absf(scene.music.stream.get_length() - float(info["duration"])) < 0.1)
		assert(not scene.music.stream.loop)
		assert(absf(scene.beat_seconds - 60.0 / float(info["bpm"])) < 0.000001)
		var entry: Dictionary = scene.playlist[index]["charts"][0]
		var chart: Array = JSON.parse_string(FileAccess.get_file_as_string(entry["chart"]))
		_check_chart(chart, info)
		# Single-chart songs safely ignore difficulty cycling.
		_touch(scene, Vector2(160, 278))
		assert(scene.chart_index == 0 and scene.song == info)
		for keyboard in [false, true]:
			scene._start()
			assert(scene.music.playing)
			scene._select_song(index + 1)
			assert(scene.song_index == index)
			scene.music.stop()
			preload("res://tests/autoplay.gd").play(scene, keyboard)
			assert(scene.score == chart.size() * 1000 and scene.combo == chart.size())
			assert(scene.counts["MISS"] == 0 and scene.session.sources.is_empty())
			scene._finish()
			assert(scene.mode == "result")
			# Retry loads this same song, not the first track's chart.
			_touch(scene, Vector2(640, 550))
			assert(scene.mode == "intro" and not scene.music.playing)
			scene._advance_intro(3.0)
			assert(scene.song_index == index and scene.score == 0 and scene.music.playing)
			scene._pause()
			_touch(scene, Vector2(640, 450))
			assert(scene.mode == "menu" and not scene.music.playing)
		print("PASS track: %s; %d objects; touch and keyboard perfect" % [info["title"], chart.size()])
	# Keyboard menu navigation and the remembered first song's difficulty.
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	scene._input(key)
	assert(scene.song_index == 0 and scene.chart_index == 1)
	_touch(scene, Vector2(160, 278))
	assert(scene.chart_index == 0)
	scene._select_song(1)
	scene._select_song(0)
	assert(scene.chart_index == 0)
	scene.music.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: playlist wrapping, song-specific audio/tempo/chart, grid/occupancy/hash, single-chart selection, remembered difficulty, retry and menu")
	quit()
