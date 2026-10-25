extends Control

const Store = preload("res://creator_store.gd")
const Timeline = preload("res://creator_timeline.gd")
signal closed
signal try_project(id: String)
signal bindings_requested
var store = Store.new()
var content: Control
var message: Label
var project: Dictionary = {}
var timeline: Control
var player: AudioStreamPlayer
var seek: HSlider
var transport: Button
var dirty := false
var preview_end := -1.0
var page := "settings"
var loop_enabled := false
var loop_start := 0.0
var loop_end := 0.0
var metronome_enabled := false
var count_in_enabled := false
var recording := false
var countdown := -1.0
var last_beat := -999999
var click_player: AudioStreamPlayer
var normal_click: AudioStreamWAV
var accent_click: AudioStreamWAV
var position_box: SpinBox
var bar_label: Label
var loop_button: Button
var edit_tools: OptionButton
var edit_length: SpinBox
var edit_hits: SpinBox

func _ready() -> void:
	size = Vector2(1280, 720)
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {"wght": 500.0}
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 21
	for item in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("243750") if item != "hover" else Color("355170")
		style.border_color = Color("5de7ee")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		theme.set_stylebox(item, "Button", style)
	self.theme = theme
	player = AudioStreamPlayer.new()
	player.volume_db = -5
	add_child(player)
	player.finished.connect(func():
		if page == "editor" and is_instance_valid(timeline):
			if loop_enabled and loop_end > loop_start:
				_start_at(loop_start)
			else:
				timeline.cursor = maxf(0, float(project.duration) - 0.001)
				timeline.queue_redraw()
		_update_transport())
	click_player = AudioStreamPlayer.new()
	click_player.volume_db = -12
	add_child(click_player)
	normal_click = _make_click(1200)
	accent_click = _make_click(1800)
	hide()

func _make_click(frequency: float) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(1324)
	for i in range(662):
		var value := int(sin(TAU * frequency * i / 22050.0) * exp(-float(i) / 110.0) * 18000)
		bytes.encode_s16(i * 2, value)
	audio.data = bytes
	return audio

func _tick(accent: bool = false) -> void:
	click_player.stream = accent_click if accent else normal_click
	click_player.play()

func _clock() -> float:
	if player.stream_paused or not player.playing:
		return timeline.cursor
	return clampf(player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency(), 0, maxf(0, float(project.duration) - 0.001))

func _process(delta: float) -> void:
	if page == "editor" and visible and is_instance_valid(timeline):
		if countdown >= 0:
			countdown -= delta
			if countdown < 0:
				_start_at(timeline.cursor)
		if player.playing and not player.stream_paused:
			advance_playhead(maxf(timeline.cursor, _clock()))
			var index := int(floor((timeline.cursor - float(project.grid_offset_seconds)) / timeline.beat()))
			if metronome_enabled and index != last_beat:
				_tick(posmod(index, 8) == 0)
			last_beat = index
			timeline.queue_redraw()
		if is_instance_valid(bar_label):
			bar_label.text = "第 %d 个八拍段  ·  %.2f–%.2fs  ·  光标 %.3fs  |  空格 播放/暂停 · R 段首%s" % [int(floor((timeline.cursor - float(project.grid_offset_seconds)) / timeline.window_seconds())) + 1, timeline.bar_start(timeline.cursor), timeline.bar_end(timeline.cursor), timeline.cursor, " · 正在录谱 J/F" if recording else ""]
		_update_transport()

func advance_playhead(time: float) -> void:
	if loop_enabled and loop_end > loop_start and time >= loop_end:
		_start_at(loop_start + fposmod(time - loop_end, loop_end - loop_start))
	else:
		timeline.cursor = time
	if preview_end >= 0 and timeline.cursor >= preview_end and not loop_enabled:
		_pause_audio()
		preview_end = -1
	if timeline.cursor < timeline.view_start or timeline.cursor >= timeline.view_start + timeline.window_seconds():
		timeline.view_start = timeline.bar_start(timeline.cursor)
	seek.set_value_no_signal(timeline.cursor)
	position_box.set_value_no_signal(timeline.cursor)

func _update_transport() -> void:
	if is_instance_valid(transport):
		transport.text = "预备中 · 空格取消" if countdown >= 0 else ("暂停 · 空格" if player.playing and not player.stream_paused else "播放 · 空格")

func _pause_audio() -> void:
	if countdown >= 0:
		countdown = -1
	if player.playing and not player.stream_paused:
		timeline.cursor = maxf(timeline.cursor, _clock())
		player.stream_paused = true
	click_player.stop()
	_update_transport()

func _start_at(time: float) -> void:
	player.stream_paused = false
	player.play(time)
	timeline.cursor = time
	timeline.view_start = timeline.bar_start(time)
	last_beat = -999999

func locate(time: float) -> void:
	time = clampf(time, 0, maxf(0, float(project.duration) - 0.001))
	var running := player.playing and not player.stream_paused
	if player.playing:
		player.seek(time)
	timeline.cursor = time
	timeline.view_start = timeline.bar_start(time)
	seek.set_value_no_signal(time)
	position_box.set_value_no_signal(time)
	if loop_enabled:
		loop_start = timeline.bar_start(time)
		loop_end = timeline.bar_end(time)
	if running:
		last_beat = -999999
	timeline.queue_redraw()

func return_to_bar() -> void:
	locate(timeline.bar_start(timeline.cursor))

func set_loop(value: bool) -> void:
	loop_enabled = value
	if value:
		loop_start = timeline.bar_start(timeline.cursor)
		loop_end = timeline.bar_end(timeline.cursor)
	if is_instance_valid(loop_button):
		loop_button.text = "循环：开" if value else "循环：关"

func _input(event: InputEvent) -> void:
	if not visible or page != "editor" or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.alt_pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	for node in get_children():
		if node is Window and node.visible:
			return
	if event.ctrl_pressed or event.meta_pressed:
		match event.keycode:
			KEY_Z:
				if event.shift_pressed: timeline.redo()
				else: timeline.undo()
			KEY_Y: timeline.redo()
			KEY_C: timeline.copy_notes()
			KEY_V: timeline.paste_notes()
			KEY_S: _save()
			_: return
	else:
		match event.keycode:
			KEY_SPACE: _play(false)
			KEY_R: return_to_bar()
			KEY_DELETE, KEY_BACKSPACE: timeline.delete_selected()
			KEY_J, KEY_F:
				if recording and player.playing and not player.stream_paused:
					timeline.record_tap(_clock(), 0 if event.keycode == KEY_J else 1)
				else: return
			_: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(player):
		if page == "editor" and is_instance_valid(timeline):
			_pause_audio()

func open_settings() -> void:
	show()
	settings_page()

func go_back() -> void:
	if page == "editor":
		_leave(library_page)
	elif page == "library":
		settings_page()
	else:
		hide()
		closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		go_back()
		get_viewport().set_input_as_handled()

func _clear(title: String, next_page: String) -> void:
	_stop_audio()
	page = next_page
	if is_instance_valid(content):
		content.hide()
		content.queue_free()
	content = Control.new()
	content.size = size
	add_child(content)
	var bg := ColorRect.new()
	bg.color = Color("0c1423")
	bg.size = size
	content.add_child(bg)
	_label(title, Rect2(60, 30, 1000, 55), 34)
	message = _label("", Rect2(65, 664, 1150, 44), 18)
	message.add_theme_color_override("font_color", Color("5de7ee"))

func _label(text: String, rect: Rect2, font_size: int = 21) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	content.add_child(node)
	return node

func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(func():
		get_viewport().gui_release_focus()
		action.call())
	content.add_child(node)
	return node

func _field(text: String, rect: Rect2, placeholder: String = "") -> LineEdit:
	var node := LineEdit.new()
	node.text = text
	node.placeholder_text = placeholder
	node.position = rect.position
	node.size = rect.size
	content.add_child(node)
	return node

func _spin(value: float, minimum: float, maximum: float, step: float, rect: Rect2) -> SpinBox:
	var node := SpinBox.new()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = value
	node.position = rect.position
	node.size = rect.size
	content.add_child(node)
	return node

func _say(text: String) -> void:
	message.text = text

func settings_page() -> void:
	_clear("设置 · 本机账号", "settings")
	_label("当前账号：" + store.nickname(), Rect2(70, 115, 1000, 45), 28)
	_label("本机身份用于区分作品；无需密码，不联网、不跨设备同步。", Rect2(70, 165, 1100, 40), 20)
	var choices := OptionButton.new()
	choices.position = Vector2(70, 230)
	choices.size = Vector2(450, 54)
	for profile in store.profiles:
		choices.add_item(profile.name)
		if profile.id == store.active_id:
			choices.select(choices.item_count - 1)
	content.add_child(choices)
	var login_button := _button("登录所选账号", Rect2(545, 230, 240, 54), func():
		if choices.selected >= 0 and store.login(store.profiles[choices.selected].id):
			settings_page()
		else:
			_say("登录失败"))
	login_button.disabled = store.profiles.is_empty()
	_button("退出账号", Rect2(810, 230, 230, 54), func():
		if store.login(""):
			project = {}
			settings_page()
		else:
			_say("退出保存失败"))
	var name_field := _field("", Rect2(70, 315, 450, 54), "新账号昵称（1–20 字）")
	name_field.max_length = 20
	_button("创建并登录", Rect2(545, 315, 240, 54), func():
		var error: String = store.create_profile(name_field.text)
		if error.is_empty():
			settings_page()
		else:
			_say(error))
	_button("谱面创作 / 我的作品", Rect2(70, 425, 460, 80), func():
		if store.active_id.is_empty():
			_say("先创建或登录一个本机账号，再进入谱面创作")
		else:
			library_page())
	_button("按键设置", Rect2(565, 425, 300, 80), func():
		hide()
		bindings_requested.emit())
	_button("返回游戏", Rect2(70, 565, 300, 64), func():
		hide()
		closed.emit())

func library_page() -> void:
	_clear("谱面创作 · " + store.nickname(), "library")
	_button("新建谱面", Rect2(70, 105, 280, 58), func():
		project = store.new_project()
		dirty = false
		editor_page())
	_button("返回设置", Rect2(940, 105, 270, 58), settings_page)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(70, 195)
	scroll.size = Vector2(1140, 430)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var projects: Array = store.projects()
	if projects.is_empty():
		_say("还没有作品。点击新建，导入音乐后在双轨时间轴上写谱。")
	for p in projects:
		var button := Button.new()
		button.text = "%s    ·    %.1f BPM    ·    %d 音符    → 编辑" % [p.title, p.bpm, p.notes.size()]
		button.custom_minimum_size = Vector2(1060, 70)
		button.pressed.connect(func():
			project = p.duplicate(true)
			dirty = false
			editor_page())
		list.add_child(button)

func _stop_audio() -> void:
	if page == "editor" and is_instance_valid(timeline) and is_instance_valid(player) and player.playing and not player.stream_paused:
		timeline.cursor = maxf(timeline.cursor, _clock())
	if is_instance_valid(player):
		player.stop()
		player.stream_paused = false
	countdown = -1
	if is_instance_valid(click_player):
		click_player.stop()
	preview_end = -1.0
	if is_instance_valid(transport):
		transport.text = "播放 / 暂停"

func _choose(kind: String) -> void:
	_stop_audio()
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "选择主音乐" if kind == "audio" else "选择谱面封面"
	dialog.filters = PackedStringArray(["*.mp3,*.ogg ; MP3 / OGG 音乐"]) if kind == "audio" else PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片"])
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var error: String = store.import_asset(project, path, kind)
		if error.is_empty():
			if kind == "audio" and project.title == "未命名曲目":
				project.title = path.get_file().get_basename()
			dirty = true
			editor_page()
			_say("已导入" + ("主音乐" if kind == "audio" else "封面"))
		else:
			_say(error)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.85)

func _leave(action: Callable) -> void:
	if not dirty:
		action.call()
		return
	if page == "editor":
		_pause_audio()
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "当前修改尚未保存。放弃修改并返回？"
	dialog.ok_button_text = "放弃修改"
	dialog.cancel_button_text = "继续编辑"
	add_child(dialog)
	dialog.confirmed.connect(func():
		dirty = false
		action.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 180))

func _save() -> bool:
	var error: String = store.save_project(project)
	if not error.is_empty():
		_say(error)
		return false
	dirty = false
	_say("已保存到当前账号；返回游戏后也可在歌单中选择")
	return true

func editor_page() -> void:
	_clear("谱面工坊", "editor")
	_button("前 8 拍", Rect2(400, 30, 135, 50), func(): seek.value = maxf(0, seek.value - timeline.window_seconds()))
	_button("后 8 拍", Rect2(550, 30, 135, 50), func(): seek.value = minf(seek.max_value, seek.value + timeline.window_seconds()))
	_label("定位秒", Rect2(705, 35, 85, 40), 18)
	position_box = _spin(0, 0, maxf(0, float(project.duration) - 0.01), 0.01, Rect2(790, 30, 190, 50))
	position_box.value_changed.connect(func(value): seek.value = value)
	_button("返回作品", Rect2(1010, 30, 200, 50), func(): _leave(library_page))
	_button("导入主音乐", Rect2(65, 105, 200, 58), func(): _choose("audio"))
	var audio_name := _label(str(project.get("audio_name", project.audio.get_file())) if not project.audio.is_empty() else "MP3 / OGG · 使用完整音轨", Rect2(285, 107, 650, 54), 19)
	audio_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	audio_name.tooltip_text = audio_name.text
	_button("导入封面", Rect2(965, 105, 245, 58), func(): _choose("cover"))
	var title_field := _field(project.title, Rect2(65, 185, 440, 50), "曲名")
	title_field.max_length = 80
	title_field.text_changed.connect(func(value): project.title = value; dirty = true)
	var artist_field := _field(project.artist, Rect2(525, 185, 390, 50), "作者 / 艺术家")
	artist_field.max_length = 80
	artist_field.text_changed.connect(func(value): project.artist = value; dirty = true)
	if not project.cover.is_empty():
		var image := Image.load_from_file(project.cover)
		if image != null:
			var cover := TextureRect.new()
			cover.position = Vector2(1010, 178)
			cover.size = Vector2(160, 120)
			cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cover.texture = ImageTexture.create_from_image(image)
			content.add_child(cover)
	_label("BPM", Rect2(65, 251, 80, 40), 18)
	var bpm := _spin(project.bpm, 20, 400, 0.1, Rect2(145, 247, 150, 48))
	bpm.value_changed.connect(func(value): project.bpm = value; dirty = true; locate(timeline.cursor))
	_label("起拍偏移(秒)", Rect2(320, 251, 150, 40), 18)
	var offset := _spin(project.grid_offset_seconds, -10, 60, 0.001, Rect2(470, 247, 160, 48))
	offset.value_changed.connect(func(value): project.grid_offset_seconds = value; dirty = true; locate(timeline.cursor))
	_label("吸附", Rect2(655, 251, 65, 40), 18)
	var snap_box := OptionButton.new()
	snap_box.position = Vector2(720, 247)
	snap_box.size = Vector2(190, 48)
	for text in ["1 拍", "1/2 拍", "1/4 拍", "1/8 拍"]:
		snap_box.add_item(text)
	snap_box.select(2)
	snap_box.item_selected.connect(func(index): timeline.subdivision = [1,2,4,8][index]; timeline.queue_redraw())
	content.add_child(snap_box)
	timeline = Timeline.new()
	timeline.position = Vector2(65, 325)
	timeline.size = Vector2(1145, 195)
	timeline.clip_contents = true
	timeline.project = project
	timeline.focus_mode = Control.FOCUS_CLICK
	timeline.waveform_stream = store.load_audio(project.audio)
	timeline.edited.connect(func(text): dirty = true; _say(text))
	timeline.seek_requested.connect(locate)
	content.add_child(timeline)
	bar_label = _label("空格播放/暂停 · R 回八拍段首 · 点击标尺定位 · Ctrl 点选多个音符", Rect2(65, 298, 1145, 27), 16)
	seek = HSlider.new()
	seek.position = Vector2(65, 528)
	seek.size = Vector2(1145, 30)
	seek.min_value = 0
	seek.max_value = maxf(0.0, float(project.duration) - 0.01)
	seek.step = 0.01
	seek.value_changed.connect(func(value):
		locate(value))
	content.add_child(seek)
	var tools := OptionButton.new()
	edit_tools = tools
	tools.position = Vector2(65, 572)
	tools.size = Vector2(150, 50)
	for text in ["点按", "长按", "连打", "删除"]:
		tools.add_item(text)
	tools.item_selected.connect(func(index):
		timeline.erase = index == 3
		timeline.tool = ["tap", "hold", "roll", "tap"][index])
	content.add_child(tools)
	_label("持续(拍)", Rect2(230, 578, 96, 40), 17)
	var length := _spin(1, 0.125, 32, 0.125, Rect2(330, 572, 120, 50))
	edit_length = length
	length.value_changed.connect(func(value): timeline.length_beats = value)
	_label("连打数", Rect2(465, 578, 80, 40), 17)
	var hits := _spin(8, 2, 128, 1, Rect2(545, 572, 110, 50))
	edit_hits = hits
	hits.value_changed.connect(func(value): timeline.roll_hits = int(value))
	_button("撤销", Rect2(675, 572, 80, 50), func(): timeline.undo())
	_button("重做", Rect2(765, 572, 80, 50), func(): timeline.redo())
	_button("应用", Rect2(855, 572, 100, 50), func():
		if timeline.erase:
			timeline.delete_selected()
		else:
			timeline.apply_selected(timeline.tool, length.value, int(hits.value)))
	_button("保存", Rect2(965, 572, 110, 50), _save)
	_button("试玩", Rect2(1085, 572, 125, 50), func():
		if project.notes.is_empty():
			_say("先在时间轴上添加音符")
		elif _save():
			_stop_audio()
			hide()
			try_project.emit(project.id))
	transport = _button("播放 / 暂停", Rect2(65, 73, 0, 0), func(): _play(false))
	transport.position = Vector2(65, 625)
	transport.size = Vector2(180, 38)
	_button("试听 20 秒", Rect2(260, 625, 160, 38), func(): _play(true))
	_button("段首 R", Rect2(435, 625, 130, 38), return_to_bar)
	loop_button = _button("循环：关", Rect2(580, 625, 120, 38), func(): set_loop(not loop_enabled))
	_button("更多工具", Rect2(715, 625, 120, 38), _more_tools)
	_button("复制", Rect2(850, 625, 100, 38), func(): timeline.copy_notes()).tooltip_text = "Ctrl+C：复制选中音符；无选中时复制当前八拍段"
	_button("粘贴", Rect2(965, 625, 100, 38), func(): timeline.paste_notes()).tooltip_text = "Ctrl+V：粘贴到播放线位置"
	_button("复制段", Rect2(1080, 625, 130, 38), func(): timeline.duplicate_bar()).tooltip_text = "复制当前八拍段到下一段"
	timeline.selection_changed.connect(func():
		if timeline.selected.is_empty(): return
		var n: Dictionary = project.notes[timeline.selected[0]]
		tools.select(["tap", "hold", "roll"].find(n.kind))
		timeline.tool = n.kind
		timeline.erase = false
		length.set_value_no_signal((float(n.get("end_time", float(n.time) + timeline.beat())) - float(n.time)) / timeline.beat())
		hits.set_value_no_signal(int(n.get("required_hits", 8)))
		timeline.length_beats = length.value
		timeline.roll_hits = int(hits.value))
	set_loop(loop_enabled)
	_say("点击音符选中；拖动换轨/移动，拖尾改长度；选类型和参数后点应用。Ctrl+Z/Y 撤销/重做。")

func _more_tools() -> void:
	var popup := AcceptDialog.new()
	popup.title = "创作工具"
	popup.ok_button_text = "完成"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(550, 290)
	box.add_theme_constant_override("separation", 12)
	popup.add_child(box)
	for entry in [["节拍器", metronome_enabled], ["开始播放前预备一拍", count_in_enabled], ["显示音乐波形", timeline.waveform_enabled], ["实时录谱（播放时 J 地面 / F 空中，记录点按）", recording]]:
		var check := CheckButton.new()
		check.text = entry[0]
		check.button_pressed = entry[1]
		check.custom_minimum_size.y = 48
		check.toggled.connect(func(value):
			match entry[0]:
				"节拍器":
					metronome_enabled = value
					last_beat = -999999
				"开始播放前预备一拍":
					count_in_enabled = value
				"显示音乐波形":
					timeline.waveform_enabled = value
					timeline.queue_redraw()
				_:
					recording = value
		)
		box.add_child(check)
	var delete := Button.new()
	delete.text = "删除选中音符（Delete）"
	delete.custom_minimum_size.y = 48
	delete.pressed.connect(func(): timeline.delete_selected(); popup.hide(); popup.queue_free())
	box.add_child(delete)
	add_child(popup)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	popup.popup_centered(Vector2i(650, 390))

func _play(demo: bool) -> void:
	if countdown >= 0 or (player.playing and not player.stream_paused):
		_pause_audio()
		return
	if player.playing and player.stream_paused:
		player.stream_paused = false
		last_beat = -999999
		_update_transport()
		return
	if player.stream == null or player.get_meta("audio_path", "") != project.audio:
		player.stream = store.load_audio(project.audio)
		player.set_meta("audio_path", project.audio)
	if player.stream == null:
		_say("请先导入主音乐")
		return
	if timeline.cursor >= float(project.duration) - 0.02:
		locate(loop_start if loop_enabled else 0)
	preview_end = minf(float(project.duration), timeline.cursor + 20.0) if demo else -1.0
	if count_in_enabled:
		countdown = timeline.beat()
		_tick(true)
	else:
		_start_at(timeline.cursor)
	_update_transport()
