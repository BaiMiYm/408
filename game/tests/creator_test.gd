extends SceneTree

const Store = preload("res://creator_store.gd")
const Timeline = preload("res://creator_timeline.gd")
var test_root: String

func _initialize() -> void:
	call_deferred("_run")

func _clean(path: String) -> void:
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clean(path.path_join(name))
	DirAccess.remove_absolute(path)

func _run() -> void:
	test_root = "user://creator-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var store = Store.new(test_root)
	assert(store.create_profile(" ") != "")
	assert(store.create_profile("谱师甲") == "")
	var first_id: String = store.active_id
	assert(store.create_profile("谱师甲") != "")
	assert(store.project_dir("../bad").is_empty())
	var project: Dictionary = store.new_project()
	assert(store.import_asset(project, "res://assets/ren_shi_mao.mp3", "audio") == "")
	project.title = "双轨测试作品"
	project.bpm = 120.0
	var timeline = Timeline.new()
	timeline.size = Vector2(1000, 200)
	timeline.project = project
	root.add_child(timeline)
	# 8 拍视窗 = 4 秒；对应 1、2、3 秒。
	timeline.place(Vector2(250, 150))
	timeline.tool = "hold"
	timeline.place(Vector2(500, 30))
	timeline.tool = "roll"
	timeline.place(Vector2(750, 150))
	assert(project.notes.size() == 3 and project.notes[1].kind == "hold")
	timeline.place(Vector2(750, 150))
	assert(project.notes.size() == 3)
	timeline.place(Vector2(750, 150), true)
	assert(project.notes.size() == 2)
	timeline.undo()
	assert(project.notes.size() == 3)
	timeline.redo()
	assert(project.notes.size() == 2)
	timeline.undo()
	assert(store.save_project(project) == "")
	var loaded = Store.new(test_root)
	assert(loaded.active_id == first_id and loaded.projects().size() == 1)
	var restored: Array = loaded.projects()[0].notes
	assert(restored.size() == project.notes.size())
	for i in restored.size():
		assert(float(restored[i].time) == float(project.notes[i].time))
		assert(int(restored[i].lane) == int(project.notes[i].lane) and restored[i].kind == project.notes[i].kind)
		assert(float(restored[i].get("end_time", 0)) == float(project.notes[i].get("end_time", 0)))
	assert(loaded.create_profile("谱师乙") == "")
	assert(loaded.projects().is_empty())
	assert(loaded.login(first_id) and loaded.projects().size() == 1)
	var invalid := project.duplicate(true)
	invalid.notes.append({"time": 2.1, "end_time": 2.7, "lane": 1, "kind": "hold"})
	assert(loaded.save_project(invalid) != "")
	assert(loaded.login("") and loaded.projects().is_empty())
	assert(loaded.save_project(project) != "")
	assert(loaded.login(first_id))
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.creator_panel.store = loaded
	scene._open_settings()
	assert(scene.mode == "creator" and scene.creator_panel.visible)
	scene.creator_panel.library_page()
	scene.creator_panel.project = loaded.projects()[0].duplicate(true)
	scene.creator_panel.editor_page()
	assert(scene.creator_panel.page == "editor")
	scene.creator_panel.hide()
	scene._try_custom_project(project.id)
	assert(scene.mode == "intro" and not scene.music.playing)
	scene._advance_intro(3.0)
	assert(scene.mode == "play" and scene.music.playing and scene.notes.size() == 3)
	assert(scene._difficulty_label() == "自制")
	await create_timer(0.2).timeout
	assert(scene.music.get_playback_position() > 0)
	scene.music.stop()
	scene.mode = "menu"
	assert(loaded.login(""))
	scene._refresh_playlist()
	assert(scene.playlist.size() == 4 and not scene.song.has("notes"))
	scene.queue_free()
	timeline.queue_free()
	await create_timer(0.1).timeout
	_clean(test_root)
	print("PASS: local profiles, isolation, raw import, timeline tap/hold/roll, collision guard, undo/redo, save/reopen, custom song playback and logout")
	quit()
