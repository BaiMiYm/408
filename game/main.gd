extends Node2D

const Judge = preload("res://judge.gd")
const KeyBindings = preload("res://key_bindings.gd")
const RhythmSession = preload("res://rhythm_session.gd")
const CreatorPanel = preload("res://creator_panel.gd")
const ParkRunner = preload("res://park_runner.gd")
const ParkUI = preload("res://park_game_ui.gd")
const CYAN := Color("5de7ee")
const PINK := Color("ff71ad")
const INK := Color("10152a")
const WHITE := Color("edf5ff")
const TRAVEL := 1.65
const HIT_X := 310.0
const LANES := [456.0, 334.0]
const INTRO_SECONDS := 3.0
const MAX_HEALTH := 100
const MISS_DAMAGE := 10

var font: Font
var song: Dictionary
var playlist: Array = []
var song_index := 0
var chart_choices: Dictionary = {0: 1}
var chart_index := 1
var beat_seconds := 60.0 / 148.0
var music: AudioStreamPlayer
var session = RhythmSession.new()
var notes: Array:
	get: return session.notes
var mode := "menu"
var song_time := 0.0
var visual_time := 0.0
var latency := 0.0
var offset_ms := 0
var score: int:
	get: return session.score
var combo: int:
	get: return session.combo
var best_combo: int:
	get: return session.best_combo
var counts: Dictionary:
	get: return session.counts
var feedback := ""
var feedback_left := 0.0
var flashes := [0.0, 0.0]
var sparks: Array = []
var muted := false
var frame_count := 0
var config := ConfigFile.new()
var bindings = KeyBindings.new()
var binding_return_mode := "menu"
var binding_lane := -1
var binding_slot := -1
var binding_message := "点击按键框，然后按下新的按键"
var creator_panel
var intro_left := 0.0
var runner = ParkRunner.new()
var park_ui = ParkUI.new()
var health := MAX_HEALTH
var shown_health := float(MAX_HEALTH)
var result_failed := false

func _ready() -> void:
	var ui_font := FontVariation.new()
	ui_font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	ui_font.variation_opentype = {"wght": 500.0}
	font = ui_font
	playlist = JSON.parse_string(FileAccess.get_file_as_string("res://playlist.json"))
	_select_chart(chart_index)
	music = AudioStreamPlayer.new()
	_load_selected_audio()
	music.volume_db = -4.0
	add_child(music)
	music.finished.connect(_finish)
	session.judged.connect(_on_judged)
	session.prompted.connect(_on_prompted)
	if config.load("user://settings.cfg") == OK:
		offset_ms = clampi(int(config.get_value("audio", "offset_ms", 0)), -250, 250)
		bindings.load_from(config)
	creator_panel = CreatorPanel.new()
	add_child(creator_panel)
	creator_panel.closed.connect(func():
		Input.emulate_mouse_from_touch = false
		mode = "menu"
		_refresh_playlist())
	creator_panel.bindings_requested.connect(func():
		Input.emulate_mouse_from_touch = false
		mode = "menu"
		_refresh_playlist()
		_open_bindings())
	creator_panel.try_project.connect(_try_custom_project)
	_refresh_playlist()
	queue_redraw()

func _refresh_playlist() -> void:
	var previous_id: String = playlist[song_index].id if not playlist.is_empty() else ""
	playlist = JSON.parse_string(FileAccess.get_file_as_string("res://playlist.json"))
	playlist.append_array(creator_panel.store.playlist_entries())
	song_index = maxi(0, playlist.find_custom(func(entry): return entry.id == previous_id))
	_select_chart(int(chart_choices.get(song_index, 0)))

func _open_settings() -> void:
	music.stop()
	Input.emulate_mouse_from_touch = true
	mode = "creator"
	creator_panel.open_settings()

func _try_custom_project(id: String) -> void:
	Input.emulate_mouse_from_touch = false
	mode = "menu"
	_refresh_playlist()
	var index := playlist.find_custom(func(entry): return entry.id == "custom_" + id)
	if index >= 0:
		_select_song(index)
		_request_start()

func _select_chart(index: int) -> void:
	var charts: Array = playlist[song_index]["charts"]
	chart_index = posmod(index, charts.size())
	chart_choices[song_index] = chart_index
	if charts[chart_index].has("project"):
		song = charts[chart_index].project.duplicate(true)
		song["note_count"] = song.notes.size()
		song["sections"] = []
	else:
		song = JSON.parse_string(FileAccess.get_file_as_string(charts[chart_index]["info"]))
	beat_seconds = 60.0 / float(song["bpm"])
	if is_instance_valid(music):
		_load_selected_audio()
	queue_redraw()

func _select_song(index: int) -> void:
	if mode != "menu":
		return
	if is_instance_valid(music):
		music.stop()
	song_index = posmod(index, playlist.size())
	session.reset([])
	song_time = 0.0
	feedback = ""
	feedback_left = 0.0
	sparks.clear()
	flashes = [0.0, 0.0]
	_select_chart(int(chart_choices.get(song_index, 0)))

func _load_selected_audio() -> void:
	music.stop()
	music.stream_paused = false
	music.stream = load(song["audio"]) if ResourceLoader.exists(song["audio"]) else null
	# 本地复制的 MP3 尚未生成 Godot 导入缓存时，直接读取原文件。
	if music.stream == null and FileAccess.file_exists(song["audio"]) and str(song["audio"]).get_extension().to_lower() == "mp3":
		var audio := AudioStreamMP3.new()
		audio.data = FileAccess.get_file_as_bytes(song["audio"])
		if audio.get_length() > 0.0:
			music.stream = audio
	if music.stream is AudioStreamMP3:
		music.stream.loop = false
	if music.stream == null and str(song["audio"]).get_extension().to_lower() == "ogg" and FileAccess.file_exists(song["audio"]):
		music.stream = AudioStreamOggVorbis.load_from_file(song["audio"])
	if music.stream is AudioStreamOggVorbis:
		music.stream.loop = false

func _difficulty_label() -> String:
	return str(playlist[song_index]["charts"][chart_index]["label"])

func _request_start() -> void:
	if mode not in ["menu", "result"] or music.stream == null:
		return
	music.stop()
	music.stream_paused = false
	session.reset([])
	song_time = 0.0
	sparks.clear()
	flashes = [0.0, 0.0]
	intro_left = INTRO_SECONDS
	health = MAX_HEALTH
	shown_health = MAX_HEALTH
	result_failed = false
	runner.reset()
	mode = "intro"
	queue_redraw()

func _advance_intro(delta: float) -> void:
	if mode != "intro":
		return
	intro_left = maxf(0, intro_left - delta)
	if intro_left <= 0:
		_start()

func _cancel_intro() -> void:
	intro_left = 0
	music.stop()
	mode = "menu"
	queue_redraw()

func _start() -> void:
	if music.stream == null:
		return
	runner.reset()
	health = MAX_HEALTH
	shown_health = MAX_HEALTH
	result_failed = false
	if song.has("notes"):
		session.reset(song.notes)
	else:
		var path: String = playlist[song_index]["charts"][chart_index]["chart"]
		session.reset(JSON.parse_string(FileAccess.get_file_as_string(path)))
	feedback = "READY"
	feedback_left = 1.0
	sparks.clear()
	flashes = [0.0, 0.0]
	song_time = -1.0
	latency = AudioServer.get_output_latency()
	mode = "play"
	music.stream_paused = false
	music.play()

func _clock() -> float:
	return music.get_playback_position() + AudioServer.get_time_since_last_mix() - latency

func _process(delta: float) -> void:
	visual_time += delta
	_advance_intro(delta)
	if frame_count == 0:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-song="):
				_select_song(arg.get_slice("=", 1).to_int())
	if frame_count == 0 and "--capture-game" in OS.get_cmdline_user_args():
		_start()
		music.seek(45.0)
		for note in notes:
			if float(note.get("end_time", note["time"])) < 45.0:
				note["done"] = true
	if frame_count == 0 and "--capture-keys" in OS.get_cmdline_user_args():
		_open_bindings()
	if frame_count == 0 and ("--capture-hold" in OS.get_cmdline_user_args() or "--capture-roll" in OS.get_cmdline_user_args()):
		_start()
		var target_kind := "hold" if "--capture-hold" in OS.get_cmdline_user_args() else "roll"
		for note in notes:
			if note.get("kind", "tap") != target_kind:
				continue
			if target_kind == "hold" and float(note["end_time"]) - float(note["time"]) < 1.2:
				continue
			var start := float(note["time"])
			for prior in notes:
				if float(prior["time"]) < start:
					prior["done"] = true
			session.press("qa", int(note["lane"]), start)
			if target_kind == "roll":
				session.release("qa", start + 0.01)
				session.press("qa", int(note["lane"]), start + 0.2)
				session.release("qa", start + 0.21)
			song_time = start + 0.22
			music.seek(song_time)
			break
	if mode == "play":
		song_time = maxf(song_time, _clock())
		var judged_time := song_time - offset_ms / 1000.0
		session.update(judged_time)
		if mode != "play":
			queue_redraw()
			frame_count += 1
			return
		shown_health = move_toward(shown_health, float(health), delta * 45)
		var sustained := ["", ""]
		for n in notes:
			if n["active"] and not n["done"] and n["kind"] in ["hold", "roll"]:
				sustained[int(n["lane"])] = n["kind"]
		runner.step(delta, sustained, [session.lane_held(0), session.lane_held(1)])
		feedback_left = maxf(0.0, feedback_left - delta)
		for i in range(2):
			flashes[i] = maxf(0.0, flashes[i] - delta * 4.0)
		for spark in sparks:
			spark["life"] -= delta
			spark["pos"] += spark["vel"] * delta
		sparks = sparks.filter(func(p): return p["life"] > 0.0)
	queue_redraw()
	frame_count += 1
	# Optional visual QA capture; never active in normal play.
	if frame_count == 15 and ("--capture" in OS.get_cmdline_user_args() or "--capture-game" in OS.get_cmdline_user_args() or "--capture-keys" in OS.get_cmdline_user_args() or "--capture-hold" in OS.get_cmdline_user_args() or "--capture-roll" in OS.get_cmdline_user_args()):
		await RenderingServer.frame_post_draw
		var capture_path := "res://preview-game.png" if "--capture-game" in OS.get_cmdline_user_args() else "res://preview.png"
		if "--capture-keys" in OS.get_cmdline_user_args():
			capture_path = "res://preview-keys.png"
		if "--capture-hold" in OS.get_cmdline_user_args():
			capture_path = "res://preview-hold.png"
		if "--capture-roll" in OS.get_cmdline_user_args():
			capture_path = "res://preview-roll.png"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-song="):
				capture_path = "res://preview-song-%d%s.png" % [song_index, "-game" if "--capture-game" in OS.get_cmdline_user_args() else ""]
		get_viewport().get_texture().get_image().save_png(capture_path)
		music.stop()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit()

func _finish() -> void:
	if mode != "play":
		return
	session.finish(float(song["duration"]))
	if mode == "play":
		song_time = float(song["duration"])
		music.stop()
		mode = "result"

func _fail() -> void:
	if mode != "play": return
	result_failed = true
	music.stop()
	session.suspend()
	mode = "result"
	queue_redraw()

func _pause() -> void:
	if mode == "intro":
		_cancel_intro()
	elif mode == "play":
		mode = "pause"
		music.stream_paused = true
		session.suspend()
	elif mode == "pause":
		music.stream_paused = false
		mode = "play"
		session.resume(_judgment_time())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode == "intro":
			_cancel_intro()
		elif mode == "play":
			_pause()
		elif mode == "bindings" and binding_lane >= 0:
			binding_lane = -1
			binding_slot = -1
			binding_message = "已取消改键，请重新选择按键框"
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "creator":
			creator_panel.go_back()
		elif mode == "bindings":
			_close_bindings()
		elif mode in ["intro", "play", "pause"]:
			_pause()
		else:
			get_tree().quit()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode == "creator" and is_instance_valid(creator_panel) and creator_panel.dirty:
			creator_panel._leave(func(): get_tree().quit())
		else:
			get_tree().quit()

func _input(event: InputEvent) -> void:
	if mode == "creator":
		return
	# Releases are handled in every mode so focus changes cannot leave a stuck hold.
	if event is InputEventKey and not event.pressed:
		session.release("key_%d" % event.keycode, _judgment_time())
		return
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		session.release("touch_%d" % event.index, _judgment_time())
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		session.release("mouse", _judgment_time())
		return
	if mode == "bindings" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if binding_lane >= 0:
				binding_lane = -1
				binding_slot = -1
				binding_message = "已取消，请选择要修改的按键"
			else:
				_close_bindings()
		elif binding_lane >= 0:
			if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
				binding_message = "请直接按单个按键，不使用组合键"
				return
			var error: String = bindings.assign(binding_lane, binding_slot, int(event.keycode))
			if error.is_empty():
				binding_lane = -1
				binding_slot = -1
				binding_message = "修改成功，已自动保存"
				_save_bindings()
			else:
				binding_message = error
		return
	if event is InputEventScreenTouch and event.pressed:
		_pointer_down(event.position, "touch_%d" % event.index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down(event.position, "mouse")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_pause()
		elif mode == "play":
			if not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
				var lane: int = bindings.lane_for(int(event.keycode))
				if lane >= 0:
					_press("key_%d" % event.keycode, lane)
		elif mode == "menu" and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_select_song(song_index + (-1 if event.keycode == KEY_LEFT else 1))
		elif event.keycode == KEY_ENTER:
			if mode == "pause":
				_pause()
			else:
				_request_start()

func _pointer_down(pos: Vector2, source: String) -> void:
	if mode == "play" and not ParkUI.PAUSE_RECT.has_point(pos):
		_press(source, 0 if pos.x < 640.0 else 1)
	else:
		_pointer(pos)

func _pointer(pos: Vector2) -> void:
	if mode == "intro":
		if Rect2(490, 630, 300, 55).has_point(pos):
			_cancel_intro()
		return
	if mode == "bindings":
		for lane in range(2):
			for slot in range(2):
				if _binding_rect(lane, slot).has_point(pos):
					binding_lane = lane
					binding_slot = slot
					binding_message = "请按新的按键；Esc 取消本次修改"
		if Rect2(310, 535, 280, 70).has_point(pos):
			bindings.reset()
			binding_lane = -1
			binding_slot = -1
			binding_message = "已恢复默认：地面 J，空中 F"
			_save_bindings()
		elif Rect2(690, 535, 280, 70).has_point(pos):
			_close_bindings()
		return
	if mode == "play":
		if ParkUI.PAUSE_RECT.has_point(pos):
			_pause()
		else:
			_press("mouse", 0 if pos.x < 640.0 else 1)
		return
	if mode == "menu":
		if Rect2(405, 105, 65, 50).has_point(pos):
			_select_song(song_index - 1)
		elif Rect2(810, 105, 65, 50).has_point(pos):
			_select_song(song_index + 1)
		elif Rect2(485, 380, 310, 76).has_point(pos):
			_request_start()
		elif Rect2(475, 498, 70, 56).has_point(pos):
			_set_offset(-10)
		elif Rect2(735, 498, 70, 56).has_point(pos):
			_set_offset(10)
		elif Rect2(1000, 42, 220, 54).has_point(pos):
			muted = not muted
			music.volume_db = -80.0 if muted else -4.0
		elif Rect2(52, 168, 180, 54).has_point(pos):
			_open_bindings()
		elif Rect2(52, 248, 220, 60).has_point(pos):
			_select_chart(chart_index + 1)
		elif Rect2(52, 370, 220, 60).has_point(pos):
			_open_settings()
		elif Rect2(52, 450, 220, 55).has_point(pos):
			get_tree().change_scene_to_file("res://character_lab.tscn")
	elif mode == "pause":
		if Rect2(485, 325, 310, 76).has_point(pos):
			_pause()
		elif Rect2(485, 425, 310, 65).has_point(pos):
			music.stop()
			mode = "menu"
		elif Rect2(485, 510, 310, 65).has_point(pos):
			_open_bindings()
	elif mode == "result":
		if Rect2(485, 510, 310, 76).has_point(pos):
			_request_start()
		elif Rect2(485, 600, 310, 55).has_point(pos):
			mode = "menu"

func _set_offset(step: int) -> void:
	offset_ms = clampi(offset_ms + step, -250, 250)
	config.set_value("audio", "offset_ms", offset_ms)
	config.save("user://settings.cfg")

func _open_bindings() -> void:
	binding_return_mode = mode
	mode = "bindings"
	binding_lane = -1
	binding_slot = -1
	binding_message = "点击按键框，然后按下新的按键"

func _close_bindings() -> void:
	binding_lane = -1
	binding_slot = -1
	mode = binding_return_mode

func _save_bindings() -> void:
	bindings.store_in(config)
	if config.save("user://settings.cfg") != OK:
		binding_message = "本次修改已生效，但保存失败，重启后将恢复"

func _binding_rect(lane: int, slot: int) -> Rect2:
	return Rect2(460 + slot * 250, 280 + lane * 110, 220, 76)

func _hit(lane: int) -> void:
	# Convenience tap for developer tools; real touch/key events use held sources.
	_press("manual", lane)
	session.release("manual", _judgment_time())

func _judgment_time() -> float:
	return maxf(song_time, _clock()) - offset_ms / 1000.0

func _press(source: String, lane: int) -> void:
	if session.sources.has(source):
		return
	var kind := "tap"
	for note in notes:
		if int(note["lane"]) == lane and note["active"] and not note["done"]:
			kind = note.get("kind", "tap")
			break
	if kind == "tap":
		var index: int = Judge.nearest(notes, lane, _judgment_time())
		if index >= 0:
			kind = notes[index].get("kind", "tap")
	runner.trigger(lane, kind)
	flashes[lane] = 1.0
	session.press(source, lane, _judgment_time())

func _on_prompted(_lane: int, message: String) -> void:
	feedback = message
	feedback_left = 0.5

func _on_judged(note: Dictionary, grade: String) -> void:
	feedback = grade
	feedback_left = 0.5
	if grade == "MISS":
		runner.miss()
		if mode == "play":
			health = maxi(0, health - MISS_DAMAGE)
			if health == 0:
				_fail()
		return
	var lane := int(note["lane"])
	runner.hit(lane)
	for i in range(10):
		var angle := float(i) * TAU / 10.0
		sparks.append({"pos": Vector2(HIT_X, LANES[lane]), "vel": Vector2(cos(angle), sin(angle)) * 180.0, "life": 0.35, "lane": lane})

func _text(value: String, pos: Vector2, size: int, color := WHITE) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(value: String, y: float, size: int, color := WHITE) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(value, Vector2((1280.0 - width) / 2.0, y), size, color)

func _fit_size(value: String, preferred: int, max_width: float) -> int:
	var size := preferred
	while size > 16 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size

func _button(rect: Rect2, label: String, accent := CYAN) -> void:
	draw_style_box(_style(INK.lightened(0.12), accent, 16), rect)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
	_text(label, Vector2(rect.get_center().x - width / 2.0, rect.get_center().y + 8), 23, accent)

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

func _draw() -> void:
	if mode in ["play", "pause"]:
		park_ui.background(self, visual_time)
		_draw_game()
		if mode == "pause":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.03, 0.08, 0.92))
			_center("已暂停", 250, 52)
			_button(Rect2(485, 325, 310, 76), "继续游戏")
			_button(Rect2(485, 425, 310, 65), "返回菜单", PINK)
			_button(Rect2(485, 510, 310, 65), "按键设置")
		return
	draw_rect(Rect2(0, 0, 1280, 720), Color("080f20"))
	for i in range(32):
		var x := fposmod(float(i * 163) - visual_time * 12.0, 1280.0)
		var y := float((i * 97) % 470 + 30)
		draw_circle(Vector2(x, y), 1.5, Color(0.4, 0.6, 0.8, 0.35))
	for i in range(18):
		var x := float(i * 90) - fposmod(visual_time * 28.0, 90.0)
		var h := float(45 + (i * 43) % 120)
		draw_rect(Rect2(x, 515.0 - h, 64, h), Color("101e37"))
	draw_line(Vector2(0, 515), Vector2(1280, 515), Color("293856"), 2)
	_text("NEON PAWS", Vector2(52, 72), 26, CYAN)
	if mode != "menu" and mode != "bindings":
		_text(song["title"], Vector2(290, 72), _fit_size(song["title"], 26, 540), CYAN)
	if mode == "menu" or mode == "creator":
		_draw_menu()
	elif mode == "bindings":
		_draw_bindings()
	elif mode == "result":
		_draw_result()
	elif mode == "intro":
		_draw_intro()

func _draw_intro() -> void:
	draw_rect(Rect2(0, 95, 1280, 625), Color(0.025, 0.045, 0.09, 0.90))
	_center(song["title"], 185, _fit_size(song["title"], 40, 1000), CYAN)
	_center("即将演奏 · " + _difficulty_label(), 231, 22, Color("9daec7"))
	var progress := 1.0 - intro_left / INTRO_SECONDS
	draw_circle(Vector2(640, 350), 85, Color(CYAN, 0.06))
	draw_arc(Vector2(640, 350), 85, -PI / 2, -PI / 2 + TAU * progress, 80, CYAN, 5, true)
	_center("开始" if intro_left < 0.25 else str(int(ceil(intro_left))), 385, 74, WHITE)
	_center("双手就位，倒计时结束后音乐开始", 475, 23, Color("9daec7"))
	_button(Rect2(100, 515, 500, 75), "地面 · " + bindings.lane_label(0), CYAN)
	_button(Rect2(680, 515, 500, 75), "空中 · " + bindings.lane_label(1), PINK)
	_button(Rect2(490, 630, 300, 55), "返回菜单 / Esc")

func _draw_menu() -> void:
	_button(Rect2(1000, 42, 220, 54), "声音：关" if muted else "声音：开")
	_button(Rect2(52, 168, 180, 54), "按键设置")
	_button(Rect2(52, 370, 220, 60), "设置 / 创作")
	_button(Rect2(52, 450, 220, 55), "角色动作测试")
	_button(Rect2(52, 248, 220, 60), "难度：" + _difficulty_label(), PINK if _difficulty_label() == "挑战" else CYAN)
	_text("点击切换难度" if playlist[song_index]["charts"].size() > 1 else "本曲一套谱面", Vector2(77, 335), 16, Color("9daec7"))
	_button(Rect2(405, 105, 65, 50), "‹")
	_button(Rect2(810, 105, 65, 50), "›")
	_center("曲目 %d / %d" % [song_index + 1, playlist.size()], 139, 23)
	_center(song["title"], 220, _fit_size(song["title"], 64, 720))
	_center(song["artist"], 270, _fit_size(song["artist"], 24, 680), Color("9daec7"))
	_center("%.0f BPM  /  %s  /  %d 音符  /  %s" % [song["bpm"], _difficulty_label(), song["note_count"], _time_label(float(song["duration"]))], 332, 20, CYAN)
	_center("菱形：点按   /   长条：按住   /   金色：反复击打", 365, 16, Color("9daec7"))
	_button(Rect2(485, 380, 310, 76), "开始演奏" if music.stream != null else "请先导入本曲音频")
	if music.stream == null:
		_center("缺少音频：" + str(song["audio"]).get_file(), 483, 17, PINK)
	_button(Rect2(475, 498, 70, 56), "-")
	_button(Rect2(735, 498, 70, 56), "+")
	_center("%+d ms" % offset_ms, 533, 24)
	_center("时差补偿：经常点晚则增加，点早则减少", 589, 18, Color("9daec7"))
	_center("左半屏：地面  /  右半屏：空中", 642, 20)
	_center("键盘：地面 %s   /   空中 %s" % [bindings.lane_label(0), bindings.lane_label(1)], 679, 17, Color("9daec7"))

func _draw_bindings() -> void:
	_center("自定义按键", 180, 46)
	_center("每条路线支持两个按键，可交替敲击", 225, 21, Color("9daec7"))
	_text("主按键", Vector2(530, 266), 18, Color("9daec7"))
	_text("备用按键", Vector2(770, 266), 18, Color("9daec7"))
	for lane in range(2):
		var accent: Color = CYAN if lane == 0 else PINK
		_text("地面攻击" if lane == 0 else "空中攻击", Vector2(275, 328 + lane * 110), 26, accent)
		for slot in range(2):
			var waiting := binding_lane == lane and binding_slot == slot
			_button(_binding_rect(lane, slot), "请按键…" if waiting else bindings.key_label(lane, slot), WHITE if waiting else accent)
	_center(binding_message, 500, 20, CYAN if binding_lane < 0 else PINK)
	_button(Rect2(310, 535, 280, 70), "恢复默认", PINK)
	_button(Rect2(690, 535, 280, 70), "完成 / 返回")
	_center("修改后自动保存；Esc 取消改键或返回", 653, 18, Color("9daec7"))
	_center("支持字母、数字、标点、空格与方向键；手机触控区域不变", 685, 16, Color("9daec7"))

func _time_label(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%d:%02d" % [total / 60, total % 60]

func _draw_game() -> void:
	var progress := park_ui.progress(song_time, float(song["duration"]))
	for lane in range(2):
		var col: Color = CYAN if lane == 0 else PINK
		var y: float = LANES[lane]
		if flashes[lane] > 0:
			draw_arc(Vector2(HIT_X, y), 44 + flashes[lane] * 8, 0, TAU, 48, Color(col, flashes[lane]), 4, true)
	for note in notes:
		_draw_note(note)
	for spark in sparks:
		draw_circle(spark["pos"], 4.0, Color(CYAN if spark["lane"] == 0 else PINK, spark["life"] / 0.35))
	runner.draw_on(self)
	park_ui.hud(self, font, health, MAX_HEALTH, shown_health, progress, combo, score, song["title"], _difficulty_label(), "%s / %s" % [_time_label(song_time), _time_label(float(song["duration"]))], bindings.lane_label(0), bindings.lane_label(1))
	if feedback_left > 0:
		var labels := {"PERFECT": "完美", "GOOD": "良好", "OK": "命中", "MISS": "漏击", "READY": "准备", "HOLD": "按住长条"}
		var label: String = labels.get(feedback, feedback)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var point := Vector2(640 - width / 2, 290)
		draw_string_outline(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 7, Color.WHITE)
		_text(label, point, 34, PINK if feedback == "MISS" else CYAN)
	if song_time < 1.5:
		_center("准备演奏", 230, 36, ParkUI.INK)

func _draw_note(note: Dictionary) -> void:
	if note["done"]:
		return
	var start := float(note["time"])
	var tail := float(note.get("end_time", start))
	if start - song_time > TRAVEL or tail - song_time < -0.5:
		return
	var lane := int(note["lane"])
	var y: float = LANES[lane]
	var col: Color = CYAN if lane == 0 else PINK
	var x := HIT_X + (start - song_time) / TRAVEL * (1280.0 - HIT_X)
	var tail_x := HIT_X + (tail - song_time) / TRAVEL * (1280.0 - HIT_X)
	var kind: String = note.get("kind", "tap")
	if kind == "tap":
		var points := PackedVector2Array([Vector2(x, y - 23), Vector2(x + 23, y), Vector2(x, y + 23), Vector2(x - 23, y)])
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 27), Vector2(x + 27, y), Vector2(x, y + 27), Vector2(x - 27, y)]), Color.WHITE)
		draw_colored_polygon(points, col)
		draw_circle(Vector2(x, y), 6, INK)
		return
	if note["active"]:
		x = HIT_X
	if kind == "hold":
		var end_x := maxf(x, minf(tail_x, 1310.0))
		draw_line(Vector2(x, y), Vector2(end_x, y), Color(col, 0.18), 30, true)
		draw_line(Vector2(x, y), Vector2(end_x, y), col, 9, true)
		draw_line(Vector2(end_x, y - 22), Vector2(end_x, y + 22), WHITE, 4, true)
		draw_circle(Vector2(x, y), 23, col)
		_text("按", Vector2(x - 11, y + 8), 22, INK)
		if note["active"]:
			var progress := clampf((song_time - start) / (tail - start), 0.0, 1.0)
			draw_arc(Vector2(x, y), 35, -PI / 2, -PI / 2 + TAU * progress, 48, WHITE, 4, true)
			_text("按住" if session.lane_held(lane) else "续按", Vector2(x - 24, y - 46), 18, col)
	else:
		col = Color("ffcc64")
		var end_x := maxf(x, minf(tail_x, 1310.0))
		draw_line(Vector2(x, y), Vector2(end_x, y), Color(col, 0.14), 34, true)
		for tick in range(int(note["required_hits"])):
			var tick_x := lerpf(x, end_x, float(tick + 1) / float(note["required_hits"]))
			draw_line(Vector2(tick_x, y - 11), Vector2(tick_x, y + 11), Color(col, 0.75), 3, true)
		draw_circle(Vector2(x, y), 30, col)
		_text("连", Vector2(x - 12, y + 9), 24, INK)
		_text("%d / %d" % [note["hits"], note["required_hits"]], Vector2(x - 25, y - 44), 20, col)

func _draw_result() -> void:
	_center(("演奏失败 · " if result_failed else "演奏完成 · ") + _difficulty_label(), 170, 48)
	_center("%07d" % score, 235, 52, CYAN)
	var earned: float = counts["PERFECT"] + counts["GOOD"] * 0.7 + counts["OK"] * 0.3
	var judged := int(counts["PERFECT"]) + int(counts["GOOD"]) + int(counts["OK"]) + int(counts["MISS"])
	var accuracy := 100.0 * earned / maxf(1.0, judged)
	_center("准确率 %.1f%%    /    最高连击 %d" % [accuracy, best_combo], 290, 24)
	_center("完美 %d     良好 %d     命中 %d" % [counts["PERFECT"], counts["GOOD"], counts["OK"]], 370, 23, CYAN)
	_center("漏击 %d" % counts["MISS"], 418, 23, PINK)
	if result_failed:
		_center("血量耗尽 · 已判定 %d / %d 个音符" % [judged, notes.size()], 465, 20, PINK)
	_button(Rect2(485, 510, 310, 76), "再来一次")
	_button(Rect2(485, 600, 310, 55), "返回菜单", PINK)
