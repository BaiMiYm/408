extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	return event

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for index in scene.playlist.size():
		scene.mode = "menu"
		scene._select_song(index)
		scene._pointer(Vector2(640, 420))
		assert(scene.mode == "intro" and not scene.music.playing)
		scene._advance_intro(1.0)
		var remaining: float = scene.intro_left
		scene._input(_key(KEY_ENTER))
		scene._pointer(Vector2(640, 420))
		assert(scene.intro_left == remaining and not scene.music.playing)
		scene._input(_key(KEY_J))
		scene._pointer_down(Vector2(100, 500), "touch_0")
		assert(scene.session.sources.is_empty() and scene.score == 0)
		scene._advance_intro(1.99)
		assert(scene.mode == "intro" and not scene.music.playing)
		scene._advance_intro(0.02)
		assert(scene.mode == "play" and scene.music.playing)
		assert(scene.session.sources.is_empty() and scene.counts.MISS == 0)
		await create_timer(0.12).timeout
		assert(scene.music.get_playback_position() < 0.5)
		scene.music.stop()
		scene.mode = "menu"
		scene._input(_key(KEY_ENTER))
		assert(scene.mode == "intro")
		scene._input(_key(KEY_ESCAPE))
		scene._advance_intro(10)
		assert(scene.mode == "menu" and not scene.music.playing)
	scene._request_start()
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene._advance_intro(10)
	assert(scene.mode == "menu" and not scene.music.playing)
	scene._request_start()
	scene._pointer(Vector2(640, 650))
	assert(scene.mode == "menu")
	scene._request_start()
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(scene.mode == "menu")
	var stream = scene.music.stream
	scene.music.stream = null
	scene._request_start()
	assert(scene.mode == "menu")
	scene.music.stream = stream
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: four-song countdown, silent wait, blocked repeat start/attacks, audio starts at zero, Escape/touch/back/focus cancellation and missing audio")
	quit()
