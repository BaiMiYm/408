extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _touch(index: int, lane: int, down: bool, canceled := false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = Vector2(200 if lane == 0 else 900, 620)
	event.pressed = down
	event.canceled = canceled
	return event

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._start()
	scene.music.stop()
	scene.offset_ms = 0
	scene.session.reset([{"time": 2.0, "end_time": 3.0, "lane": 0, "kind": "hold"}, {"time": 2.4, "lane": 1, "kind": "tap"}])
	scene.song_time = 2.0
	scene._input(_touch(0, 0, true))
	scene.song_time = 2.4
	scene._input(_touch(1, 1, true))
	scene._input(_touch(1, 1, false))
	assert(scene.score == 1000 and scene.session.lane_held(0))
	scene.song_time = 2.6
	scene._input(_touch(0, 0, false, true))
	assert(scene.counts["MISS"] == 1 and not scene.session.lane_held(0))
	scene.session.reset([{"time": 2.0, "end_time": 3.0, "lane": 0, "kind": "hold"}])
	scene.song_time = 2.0
	scene._input(_touch(0, 0, true))
	scene.song_time = 2.4
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(scene.mode == "pause" and scene.session.suspended)
	scene._input(_touch(0, 0, false))
	scene._pause()
	scene.song_time = 2.6
	scene._input(_touch(0, 0, true))
	scene.song_time = 3.0
	scene.session.update(3.0)
	assert(scene.score == 1000 and scene.counts["MISS"] == 0)
	scene._input(_touch(0, 0, false))
	# Dragging a held touch across the center does not switch its assigned lane.
	scene.session.reset([{"time": 2.0, "end_time": 3.0, "lane": 0, "kind": "hold"}])
	scene.song_time = 2.0
	scene._input(_touch(0, 0, true))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(1000, 620)
	scene._input(drag)
	assert(scene.session.lane_held(0) and not scene.session.lane_held(1))
	scene.song_time = 3.0
	scene.session.update(3.0)
	scene._input(_touch(0, 1, false))
	assert(scene.score == 1000 and scene.session.sources.is_empty())
	scene.music.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: multi-touch hold with other-lane taps, canceled touch, focus loss/regrip, drag lane ownership")
	quit()
