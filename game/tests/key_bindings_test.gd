extends SceneTree

const Bindings = preload("res://key_bindings.gd")

func _initialize() -> void:
	call_deferred("_run")

func _key(code: int, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code as Key
	event.pressed = true
	event.echo = echo
	return event

func _run() -> void:
	var model = Bindings.new()
	assert(model.lane_for(KEY_J) == 0)
	assert(model.lane_for(KEY_F) == 1)
	assert(model.lane_for(KEY_LEFT) == 0 and model.lane_for(KEY_RIGHT) == 1)
	assert(not model.assign(0, 0, KEY_F).is_empty())
	assert(model.lane_for(KEY_J) == 0)
	assert(not model.assign(0, 0, KEY_LEFT).is_empty())
	assert(not model.assign(0, 0, KEY_ESCAPE).is_empty())
	assert(not model.assign(0, 0, KEY_ENTER).is_empty())
	assert(model.assign(0, 0, KEY_A).is_empty())
	assert(model.assign(1, 0, KEY_SPACE).is_empty())
	var cfg := ConfigFile.new()
	model.store_in(cfg)
	assert(cfg.save("user://keybindings-test.cfg") == OK)
	var saved := ConfigFile.new()
	assert(saved.load("user://keybindings-test.cfg") == OK)
	var restored = Bindings.new()
	restored.load_from(saved)
	assert(restored.lane_for(KEY_A) == 0 and restored.lane_for(KEY_SPACE) == 1)
	assert(restored.lane_for(KEY_J) == -1 and restored.lane_for(KEY_F) == -1)
	saved.set_value("input", "keys", [[KEY_A, KEY_LEFT], [KEY_A, KEY_RIGHT]])
	var invalid = Bindings.new()
	invalid.load_from(saved)
	assert(invalid.keys == Bindings.DEFAULT_KEYS)
	saved.set_value("input", "keys", [["broken", KEY_LEFT], [KEY_F, KEY_RIGHT]])
	invalid.load_from(saved)
	assert(invalid.keys == Bindings.DEFAULT_KEYS)
	DirAccess.remove_absolute("user://keybindings-test.cfg")
	# Exercise the settings screen and keyboard routing through real game input.
	var old_settings := FileAccess.get_file_as_bytes("user://settings.cfg") if FileAccess.file_exists("user://settings.cfg") else PackedByteArray()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.bindings.reset()
	scene._pointer(Vector2(140, 190))
	assert(scene.mode == "bindings")
	scene._pointer(Vector2(560, 320))
	assert(scene.binding_lane == 0 and scene.binding_slot == 0)
	scene._input(_key(KEY_F))
	assert(scene.bindings.lane_for(KEY_J) == 0 and scene.binding_lane == 0)
	scene._input(_key(KEY_A))
	assert(scene.bindings.lane_for(KEY_A) == 0 and scene.binding_lane == -1)
	scene._pointer(Vector2(560, 430))
	scene._input(_key(KEY_ESCAPE))
	assert(scene.mode == "bindings" and scene.binding_lane == -1)
	scene._pointer(Vector2(800, 570))
	assert(scene.mode == "menu")
	scene._start()
	scene.music.stop()
	scene.offset_ms = 0
	var ground_index: int = scene.notes.find_custom(func(note): return int(note["lane"]) == 0)
	scene.song_time = float(scene.notes[ground_index]["time"])
	scene._input(_key(KEY_J))
	assert(scene.score == 0)
	scene._input(_key(KEY_A, true))
	assert(scene.score == 0)
	scene._input(_key(KEY_A))
	assert(scene.score == 1000 and scene.notes[ground_index]["done"])
	scene.music.play()
	scene._pause()
	scene._pointer(Vector2(640, 540))
	assert(scene.mode == "bindings" and scene.music.stream_paused)
	scene._pointer(Vector2(450, 570))
	assert(scene.bindings.lane_for(KEY_J) == 0 and scene.bindings.lane_for(KEY_F) == 1)
	scene._input(_key(KEY_ESCAPE))
	assert(scene.mode == "pause" and scene.music.stream_paused)
	# A complete chart with the new default keyboard layout, including double hits.
	scene._start()
	scene.music.stop()
	preload("res://tests/autoplay.gd").play(scene, true)
	assert(scene.score == scene.notes.size() * 1000 and scene.combo == scene.notes.size())
	scene.music.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.1).timeout
	if old_settings.is_empty():
		DirAccess.remove_absolute("user://settings.cfg")
	else:
		var output := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		output.store_buffer(old_settings)
		output.close()
	print("PASS: J ground / F air, rebind, conflicts, persistence, corrupt config, cancel, pause, echo, full keyboard chart")
	quit()
