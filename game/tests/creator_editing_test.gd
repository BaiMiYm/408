extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _key(code: int, ctrl: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._open_settings()
	var panel = scene.creator_panel
	panel.set_process(false)
	panel.project = panel.store.new_project()
	panel.project.audio = "res://assets/ren_shi_mao.mp3"
	panel.project.duration = 136.216217
	panel.project.bpm = 120
	panel.project.grid_offset_seconds = 0.2
	panel.editor_page()
	var timeline = panel.timeline
	panel.locate(5.3)
	panel._input(_key(KEY_R))
	assert(is_equal_approx(timeline.cursor, 4.2) and not panel.player.playing)
	panel.locate(5.3)
	panel._input(_key(KEY_SPACE))
	assert(panel.player.playing and not panel.player.stream_paused)
	await create_timer(0.2).timeout
	panel._input(_key(KEY_SPACE))
	var stopped: float = timeline.cursor
	assert(panel.player.stream_paused and stopped >= 5.3)
	await create_timer(0.2).timeout
	assert(is_equal_approx(timeline.cursor, stopped))
	panel._input(_key(KEY_R))
	assert(panel.player.stream_paused and is_equal_approx(timeline.cursor, 4.2))
	panel._input(_key(KEY_SPACE))
	await create_timer(0.15).timeout
	assert(panel.player.playing and not panel.player.stream_paused)
	assert(panel.player.get_playback_position() >= 4.2 and panel.player.get_playback_position() < 4.7)
	panel.return_to_bar()
	assert(not panel.player.stream_paused and is_equal_approx(timeline.cursor, 4.2))
	panel.set_loop(true)
	panel.advance_playhead(8.3)
	assert(is_equal_approx(timeline.cursor, 4.3) and not panel.player.stream_paused)
	panel._pause_audio()
	panel.set_loop(false)
	panel.locate(0.1)
	panel.return_to_bar()
	assert(timeline.cursor == 0)
	panel.count_in_enabled = true
	panel._stop_audio()
	panel.locate(1.2)
	panel._play(false)
	assert(panel.countdown > 0 and not panel.player.playing)
	panel._play(false)
	assert(panel.countdown < 0 and not panel.player.playing)
	panel._play(false)
	panel._process(0.6)
	assert(panel.player.playing)
	panel._pause_audio()
	panel.count_in_enabled = false
	# 文本与 SpinBox 的 LineEdit 获得焦点时，空格、R 和录谱键均不拦截。
	var input := LineEdit.new()
	panel.content.add_child(input)
	input.grab_focus()
	var before: float = timeline.cursor
	panel._input(_key(KEY_SPACE))
	panel._input(_key(KEY_R))
	assert(panel.player.stream_paused and timeline.cursor == before)
	input.release_focus()
	input.queue_free()
	# 标尺定位不生成音符。
	panel.locate(0.2)
	timeline.begin_pointer(Vector2(timeline.size.x / 2, 10))
	assert(is_equal_approx(timeline.cursor, 2.2) and panel.project.notes.is_empty())
	panel.project.grid_offset_seconds = 0
	panel.locate(0)
	timeline.record_tap(1, 0)
	timeline.tool = "hold"
	timeline.place(Vector2(timeline.size.x / 2, timeline.lane_y(1)))
	timeline.tool = "roll"
	timeline.place(Vector2(timeline.size.x * 0.75, timeline.lane_y(0)))
	assert(panel.project.notes.size() == 3)
	# 移动到另一轨，以及拖动长按尾部。
	timeline.begin_pointer(Vector2(timeline.size.x * 0.25, timeline.lane_y(0)))
	timeline.update_drag(Vector2(timeline.size.x * 0.375, timeline.lane_y(1)))
	timeline.end_drag()
	assert(is_equal_approx(panel.project.notes[0].time, 1.5) and panel.project.notes[0].lane == 1)
	timeline.begin_pointer(Vector2(timeline.size.x * 0.625, timeline.lane_y(1)))
	timeline.update_drag(Vector2(timeline.size.x * 0.6875, timeline.lane_y(1)))
	timeline.end_drag()
	assert(is_equal_approx(panel.project.notes[1].end_time, 2.75))
	# 重叠的拖动回滚，保留原音符。
	timeline.begin_pointer(Vector2(timeline.size.x * 0.375, timeline.lane_y(1)))
	timeline.update_drag(Vector2(timeline.size.x * 0.5, timeline.lane_y(1)))
	timeline.end_drag()
	assert(is_equal_approx(panel.project.notes[0].time, 1.5))
	timeline.selected.assign([0])
	timeline.apply_selected("roll", 0.5, 4)
	assert(panel.project.notes[0].kind == "roll" and panel.project.notes[0].required_hits == 4)
	panel._input(_key(KEY_Z, true))
	assert(panel.project.notes[0].kind == "tap")
	panel._input(_key(KEY_Y, true))
	assert(panel.project.notes[0].kind == "roll")
	timeline.cursor = 0
	timeline.duplicate_bar()
	assert(panel.project.notes.size() == 6)
	timeline.selected.assign([0])
	panel._input(_key(KEY_C, true))
	timeline.cursor = 10
	panel._input(_key(KEY_V, true))
	assert(panel.project.notes.size() == 7)
	panel._input(_key(KEY_DELETE))
	assert(panel.project.notes.size() == 6)
	# 录谱使用音频时钟并吸附；暂停和按键自动重复不录入。
	panel.locate(12)
	panel.recording = true
	panel._play(false)
	panel._input(_key(KEY_J))
	assert(panel.project.notes.size() == 7 and panel.project.notes[-1].lane == 0)
	var repeat := _key(KEY_F)
	repeat.echo = true
	panel._input(repeat)
	assert(panel.project.notes.size() == 7)
	panel._pause_audio()
	panel._input(_key(KEY_F))
	assert(panel.project.notes.size() == 7)
	panel.locate(10)
	for i in range(22):
		await process_frame
	assert(timeline.waveform.size() == 256 and Array(timeline.waveform).max() > 0.01)
	panel._more_tools()
	await process_frame
	assert(panel.metronome_enabled == false)
	for node in panel.get_children():
		if node is AcceptDialog:
			for child in node.get_children():
				if child is VBoxContainer:
					child.get_child(0).button_pressed = true
					assert(panel.metronome_enabled and not panel.count_in_enabled)
					child.get_child(1).button_pressed = true
					assert(panel.count_in_enabled)
					child.get_child(2).button_pressed = false
					assert(not timeline.waveform_enabled)
					child.get_child(3).button_pressed = false
					assert(not panel.recording)
	scene.queue_free()
	await create_timer(0.1).timeout
	print("PASS: space pause/resume, R segment start, offset/intro, loop wrap, count-in, text guard, ruler seek, drag/resize/collision, edit, clipboard, undo/redo, live recording and decoded waveform")
	quit()
