extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	assert(scene.mode == "menu")
	scene._pointer(Vector2(640, 420))
	assert(scene.mode == "intro" and not scene.music.playing)
	scene._advance_intro(3.0)
	assert(scene.mode == "play")
	assert(scene.music.playing)
	scene._pointer(Vector2(1170, 60))
	assert(scene.mode == "pause" and scene.music.stream_paused)
	scene._pointer(Vector2(640, 360))
	assert(scene.mode == "play" and not scene.music.stream_paused)
	scene.music.stop()
	scene.offset_ms = 0
	scene.song_time = float(scene.notes[0]["time"])
	scene._hit(int(scene.notes[0]["lane"]))
	assert(scene.combo == 1 and scene.score == 1000)
	assert(scene.counts["PERFECT"] == 1)
	scene._hit(int(scene.notes[0]["lane"]))
	assert(scene.combo == 1 and scene.score == 1000)
	scene._finish()
	assert(scene.mode == "result")
	assert(scene.result_failed and scene.health == 0 and scene.counts["MISS"] == 10)
	scene._pointer(Vector2(640, 550))
	assert(scene.mode == "intro" and not scene.music.playing)
	scene._advance_intro(3.0)
	assert(scene.mode == "play" and scene.score == 0)
	# Simulate every touch at its chart timestamp through the actual input path.
	scene.music.stop()
	scene.offset_ms = 0
	assert(absf(scene.music.stream.get_length() - float(scene.song["duration"])) < 0.1)
	assert(not scene.music.stream.loop)
	preload("res://tests/autoplay.gd").play(scene)
	assert(scene.combo == scene.notes.size())
	assert(scene.score == scene.notes.size() * 1000)
	assert(scene.counts["PERFECT"] == scene.notes.size())
	assert(scene.counts["MISS"] == 0)
	scene._finish()
	assert(scene.mode == "result")
	scene._pointer(Vector2(640, 550))
	scene._advance_intro(3.0)
	assert(scene.mode == "play" and scene.score == 0)
	scene._pause()
	scene._pointer(Vector2(640, 450))
	assert(scene.mode == "menu" and not scene.music.playing)
	print("PASS: audio duration, no loop, complete touch chart, pause, result, retry, menu")
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
