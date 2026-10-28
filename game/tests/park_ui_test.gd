extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	assert(scene.park_ui.BACKGROUND.get_size() == Vector2(2636, 1870))
	assert(scene.park_ui.RING.get_size() == Vector2(186, 186))
	assert(scene.runner.PORTRAIT.get_size() == Vector2(430, 572))
	assert(scene.park_ui.progress(-1, 120) == 0)
	assert(scene.park_ui.progress(30, 120) == 0.25)
	assert(scene.park_ui.progress(240, 120) == 1)
	assert(scene.park_ui.progress(20, 0) == 0)
	scene._start()
	await create_timer(0.08).timeout
	assert(scene.health == 100 and not scene.result_failed)
	scene.music.stop()
	scene.session.reset([])
	scene.song_time = 0
	scene._hit(0)
	assert(scene.health == 100 and scene.score == 0)
	# 同一帧积压很多漏击时，也在第十个MISS处停止；不把未来音符全算漏击。
	var chart: Array = []
	for i in range(25):
		chart.append({"time": float(i + 1), "lane": i % 2, "kind": "tap"})
	scene.session.reset(chart)
	scene.music.play()
	await create_timer(0.08).timeout
	scene.song_time = 30
	scene.session.press("late_input", 0, 30)
	assert(scene.health == 0 and scene.result_failed and scene.mode == "result")
	assert(not scene.music.playing and scene.session.suspended)
	assert(scene.counts.MISS == 10 and scene.session.sources.is_empty())
	assert(scene.notes.filter(func(n): return n.done).size() == 10)
	scene.session.update(100)
	scene._finish()
	assert(scene.counts.MISS == 10 and scene.result_failed)
	# 重玩先准备，并清除失败状态；暂停不掉血；PSD蓝色返回形按钮打开暂停菜单。
	scene._pointer(Vector2(640, 550))
	assert(scene.mode == "intro" and scene.health == 100 and not scene.result_failed)
	scene._advance_intro(3)
	await create_timer(0.08).timeout
	scene._pointer(Vector2(1200, 50))
	assert(scene.mode == "pause" and scene.music.stream_paused)
	scene._process(1)
	assert(scene.health == 100)
	scene._pointer(Vector2(640, 360))
	assert(scene.mode == "play")
	scene.music.stop()
	# 正常完美结束仍为完成，不触发失败；进度到达100%。
	scene.session.reset([{"time":1.0,"lane":0,"kind":"tap"}])
	scene.session.press("hit",0,1)
	scene.session.release("hit",1.01)
	assert(scene.health == 100 and scene.score == 1000)
	scene._finish()
	assert(scene.mode == "result" and not scene.result_failed)
	assert(scene.park_ui.progress(scene.song_time, float(scene.song.duration)) == 1)
	scene.music.stop()
	scene.music.stream = null
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: PSD assets/layout, progress bounds, empty-input HP isolation, immediate death, backlog stop, retry, pause and successful completion")
	call_deferred("quit")
