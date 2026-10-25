extends Node2D

const Runner = preload("res://whitecat_runner.gd")
const CYAN := Color("5de7ee")
const PINK := Color("ff71ad")
var runner = Runner.new()
var font: Font
var paused := false
var sources: Dictionary = {}
var time := 0.0

func _ready() -> void:
	var variation := FontVariation.new()
	variation.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
	variation.variation_opentype = {"wght": 500.0}
	font = variation

func _process(delta: float) -> void:
	if not paused:
		time += delta
		var held := [false, false]
		for entry in sources.values():
			if entry.kind == "hold": held[int(entry.lane)] = true
		runner.step(delta, ["hold" if held[0] else "", "hold" if held[1] else ""], held)
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		sources.clear()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://main.tscn")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _press(source: String, lane: int, kind: String) -> void:
	if paused or sources.has(source): return
	sources[source] = {"lane": lane, "kind": kind}
	runner.trigger(lane, kind)
	runner.hit(lane)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_source := "key_%d" % event.keycode
		if not event.pressed:
			sources.erase(key_source)
		elif not event.echo:
			match event.keycode:
				KEY_ESCAPE: get_tree().change_scene_to_file("res://main.tscn")
				KEY_SPACE:
					paused = not paused
					sources.clear()
				KEY_R:
					runner.reset()
					sources.clear()
				KEY_J: _press(key_source, 0, "tap")
				KEY_F: _press(key_source, 1, "tap")
				KEY_Q: _press(key_source, 0, "hold")
				KEY_E: _press(key_source, 1, "hold")
				KEY_A: _press(key_source, 0, "roll")
				KEY_S: _press(key_source, 1, "roll")
	elif event is InputEventScreenTouch:
		var source := "touch_%d" % event.index
		if event.pressed and not event.canceled: _pointer(event.position, source)
		else: sources.erase(source)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _pointer(event.position, "mouse")
		else: sources.erase("mouse")

func _button_rect(lane: int, action: int) -> Rect2:
	return Rect2(40 + lane * 620 + action * 185, 560, 170, 65)

func _pointer(pos: Vector2, source: String) -> void:
	if Rect2(1050, 30, 180, 55).has_point(pos):
		get_tree().change_scene_to_file("res://main.tscn")
		return
	if Rect2(845, 30, 180, 55).has_point(pos):
		paused = not paused
		sources.clear()
		return
	for lane in range(2):
		for action in range(3):
			if _button_rect(lane, action).has_point(pos):
				_press(source, lane, ["tap", "hold", "roll"][action])
				return
	_press(source, 0 if pos.x < 640 else 1, "tap")

func _text(text: String, pos: Vector2, size: int = 21, color := Color.WHITE) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _button(rect: Rect2, text: String, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2b41")
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	_text(text, Vector2(rect.get_center().x - width / 2, rect.get_center().y + 8), 21, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("080f20"))
	_text("白发兽耳角色 · 动作测试", Vector2(40, 64), 30, CYAN)
	_button(Rect2(845, 30, 180, 55), "继续 / 空格" if paused else "暂停 / 空格", CYAN)
	_button(Rect2(1050, 30, 180, 55), "返回菜单 / Esc", PINK)
	_text("不用选歌，直接测试动作；音乐判定不在此场景运行", Vector2(40, 115), 20, Color("9daec7"))
	for i in range(18):
		var x := fposmod(i * 90 - time * 160, 1350) - 70
		draw_rect(Rect2(x, 515 - 50 - (i * 37) % 110, 60, 50 + (i * 37) % 110), Color("101e37"))
	draw_line(Vector2(0, 515), Vector2(1280, 515), Color("293856"), 3)
	for lane in range(2):
		var y := 444.0 - lane * 144
		var color: Color = CYAN if lane == 0 else PINK
		draw_line(Vector2(300, y), Vector2(1200, y), Color(color, 0.25), 2)
		draw_arc(Vector2(310, y), 28, 0, TAU, 48, color, 3, true)
		_text("地面" if lane == 0 else "空中", Vector2(1140, y - 18), 21, color)
	runner.draw_on(self)
	for lane in range(2):
		var keys: Array = ["J", "Q", "A"] if lane == 0 else ["F", "E", "S"]
		for action in range(3):
			_button(_button_rect(lane, action), ["点按 ", "长按 ", "连打 "][action] + keys[action], CYAN if lane == 0 else PINK)
	_text("J / F 地面与空中攻击   ·   按住 Q / E 长按   ·   连按 A / S 连打", Vector2(80, 666), 23)
	_text("R 重置角色   ·   地空交替可打断收招   ·   Q + E 同按可查看双轨持续分身", Vector2(80, 702), 19, Color("9daec7"))
