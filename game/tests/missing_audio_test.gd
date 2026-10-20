extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for index in range(scene.playlist.size()):
		scene._select_song(index)
		assert(scene.music.stream == null)
		scene._start()
		assert(scene.mode == "menu" and not scene.music.playing)
	scene.queue_free()
	await process_frame
	print("PASS: missing audio keeps all four songs in a usable menu")
	quit()
