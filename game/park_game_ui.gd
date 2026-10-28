extends RefCounted

const BACKGROUND = preload("res://assets/park_ui/background.png")
const AVATAR = preload("res://assets/park_ui/avatar.png")
const HEALTH = preload("res://assets/park_ui/health_fill.png")
const SMALL_PROGRESS = preload("res://assets/park_ui/progress_fill.png")
const STRIPES = preload("res://assets/park_ui/progress_stripes.png")
const POINTER = preload("res://assets/park_ui/progress_pointer.png")
const PAUSE = preload("res://assets/park_ui/pause_button.png")
const COMBO = preload("res://assets/park_ui/combo_label.png")
const RING = preload("res://assets/park_ui/hit_ring.png")
const PAUSE_RECT := Rect2(1160, 12, 90, 80)
const INK := Color("334753")
const GOLD := Color("d5a445")
const BLUE := Color("00a7ed")

func progress(time: float, duration: float) -> float:
	return clampf(time / duration, 0, 1) if duration > 0 else 0.0

func _fill(canvas: CanvasItem, texture: Texture2D, rect: Rect2, value: float, tint := Color.WHITE) -> void:
	value = clampf(value, 0, 1)
	if value <= 0: return
	canvas.draw_texture_rect_region(texture, Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)), Rect2(Vector2.ZERO, Vector2(texture.get_width() * value, texture.get_height())), tint)

func background(canvas: CanvasItem, time: float) -> void:
	canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, 1280, 720), false)
	for lane in range(2):
		var y := 456.0 - lane * 122
		canvas.draw_line(Vector2(310, y), Vector2(1280, y), Color(1, 1, 1, 0.22), 2)
		canvas.draw_texture_rect(RING, Rect2(272, y - 38, 76, 76), false)

func hud(canvas: CanvasItem, font: Font, hp: int, max_hp: int, shown_hp: float, ratio: float, combo: int, score: int, title: String, difficulty: String, time_label: String, ground_keys: String, air_keys: String) -> void:
	var track := Rect2(0, 35, 1145, 18)
	canvas.draw_texture_rect(STRIPES, track, false, Color(1, 1, 1, 0.40))
	_fill(canvas, STRIPES, track, ratio)
	canvas.draw_texture_rect(POINTER, Rect2(clampf(ratio * 1145 - 22, 0, 1105), 14, 42, 60), false)
	canvas.draw_texture_rect(AVATAR, Rect2(20, 18, 110, 110), false)
	var health_rect := Rect2(142, 72, 355, 38)
	var base := StyleBoxFlat.new()
	base.bg_color = Color("b1dace")
	base.set_corner_radius_all(8)
	canvas.draw_style_box(base, health_rect)
	base.bg_color = Color("e9c56b")
	canvas.draw_style_box(base, Rect2(health_rect.position, Vector2(health_rect.size.x * clampf(shown_hp / maxf(1, max_hp), 0, 1), health_rect.size.y)))
	_fill(canvas, HEALTH, health_rect, float(hp) / maxf(1, max_hp))
	if hp <= max_hp * 0.3:
		canvas.draw_rect(health_rect.grow(2), Color("e55e52"), false, 3)
	_text(canvas, font, "HP  %d / %d" % [hp, max_hp], Vector2(160, 99), 22, Color.WHITE, true)
	canvas.draw_rect(Rect2(142, 120, 250, 6), Color("b1dace"))
	_fill(canvas, SMALL_PROGRESS, Rect2(142, 120, 250, 6), ratio)
	_text(canvas, font, time_label, Vector2(142, 151), 17, INK)
	var title_size := 23
	while title_size > 16 and font.get_string_size(title.left(30), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 495:
		title_size -= 1
	_text(canvas, font, title.left(30), Vector2(545, 96), title_size, INK)
	_text(canvas, font, "%s  ·  %07d" % [difficulty, score], Vector2(545, 125), 18, INK)
	canvas.draw_texture_rect(PAUSE, PAUSE_RECT, false)
	var number := str(combo)
	var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 45).x
	_text(canvas, font, number, Vector2(1146 - width / 2, 161), 45, Color.WHITE, true)
	canvas.draw_texture_rect(COMBO, Rect2(1045, 176, 202, 48), false)
	_text(canvas, font, "地面  " + ground_keys, Vector2(28, 701), 17, INK, true)
	_text(canvas, font, "空中  " + air_keys, Vector2(1060, 701), 17, INK, true)

func _text(canvas: CanvasItem, font: Font, text: String, point: Vector2, size: int, color: Color, outline := false) -> void:
	if outline:
		canvas.draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, GOLD if size == 45 else Color(1, 1, 1, 0.75))
	canvas.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
