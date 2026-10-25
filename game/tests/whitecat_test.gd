extends SceneTree

const Runner = preload("res://whitecat_runner.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner = Runner.new()
	for texture in runner.SHEETS.values():
		assert(texture.get_width() == 1792 and texture.get_height() == 1088)
	runner.step(0.1)
	assert(runner.actions[0] == "run" and runner.frame_index(0) == 1)
	runner.trigger(0)
	runner.step(0.06)
	assert(runner.actions[0] == "ground_attack")
	runner.trigger(1)
	assert(runner.echo_left > 0 and runner.primary_lane == 1)
	runner.step(0.1)
	assert(runner.height > 0.9 and runner.actions[1] == "air_attack")
	runner.trigger(0)
	runner.step(0.15)
	assert(runner.height < 0.08 and runner.land_left > 0)
	runner.trigger(0, "hold")
	runner.trigger(1, "hold")
	for i in range(80):
		runner.step(0.02, ["hold", "hold"], [true, true])
		if i > 8:
			assert(runner.frame_index(0) in [2,3,4,5] and runner.frame_index(1) in [2,3,4,5])
	assert(runner.sustaining[0] and runner.sustaining[1] and runner.height > 0.99)
	runner.step(0.01)
	assert(runner.frame_index(1) == 6)
	runner.step(0.07)
	assert(runner.frame_index(1) == 7)
	runner.step(0.06)
	assert(runner.actions[0] == "run" and runner.actions[1] == "run")
	runner.trigger(0, "roll")
	var first := runner.frame_index(0)
	runner.trigger(0, "roll")
	assert(first != runner.frame_index(0))
	runner.reset()
	assert(runner.height == 0 and runner.echo_left == 0 and runner.actions[0] == "run")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._start()
	scene.music.stop()
	scene.session.reset([])
	scene.song_time = 30
	scene._press("key", 1)
	assert(scene.runner.actions[1] == "air_attack" and scene.score == 0)
	var strikes: int = scene.runner.strikes[1]
	scene._press("key", 1)
	assert(scene.runner.strikes[1] == strikes)
	scene.session.release("key", 30)
	scene._press("key", 0)
	assert(scene.runner.actions[0] == "ground_attack")
	scene._pause()
	var elapsed: float = scene.runner.elapsed[0]
	scene._process(0.1)
	assert(scene.runner.elapsed[0] == elapsed)
	scene._start()
	assert(scene.runner.height == 0 and scene.runner.actions[0] == "run")
	scene.music.stop()
	scene.queue_free()
	await process_frame
	var lab = load("res://character_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab._press("left", 0, "hold")
	lab._press("right", 1, "hold")
	lab._process(0.2)
	assert(lab.runner.sustaining[0] and lab.runner.sustaining[1])
	lab._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(lab.sources.is_empty())
	lab.queue_free()
	await create_timer(0.1).timeout
	print("PASS: whitecat atlas/timing, run, interruptible ground/air, rise/fall/landing, dual hold enter/loop/exit, barrage variation, score isolation, pause/retry and lab focus release")
	quit()
