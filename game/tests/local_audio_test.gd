extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	# user:// 文件不经过编辑器导入，覆盖复制 MP3 后立即运行的情况。
	var temporary := "user://local_audio_test.mp3"
	for index in scene.playlist.size():
		scene.mode = "menu"
		scene._select_song(index)
		var original: String = scene.song.audio
		var file := FileAccess.open(temporary, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(original))
		file.close()
		file = null
		scene.song.audio = temporary
		scene._load_selected_audio()
		assert(scene.music.stream is AudioStreamMP3)
		assert(absf(scene.music.stream.get_length() - float(scene.song.duration)) < 0.1)
		scene._start()
		await create_timer(0.3).timeout
		assert(scene.mode == "play" and scene.music.playing)
		assert(scene.music.get_playback_position() > 0.0)
		scene.music.stop()
		DirAccess.remove_absolute(temporary)
		scene.song.audio = "user://missing_local_audio_test.mp3"
		scene._load_selected_audio()
		scene.mode = "menu"
		scene._start()
		assert(scene.mode == "menu" and scene.music.stream == null)
	scene.queue_free()
	await process_frame
	print("PASS: four raw MP3 files start playback without import cache; missing audio stays in menu")
	quit()
