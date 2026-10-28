extends "res://whitecat_runner.gd"

# PSD只有一张人物姿态；保留原像素，用整体变换表现动作，不冒充新序列帧。
const PORTRAIT = preload("res://assets/park_ui/character.png")
const PARK_FOOT := Vector2(185, 580)
const PARK_GAP := 122.0

func _park_body(canvas: CanvasItem, lane: int, foot: Vector2, alpha: float = 1.0) -> void:
	var action: String = actions[lane]
	var phase := clampf(elapsed[lane] / (0.52 if lane == 1 else 0.33), 0, 1)
	var swing := sin(phase * PI) if action != "run" else 0.0
	if action == "barrage": swing = sin(elapsed[lane] * TAU / 0.16) * 0.5 + 0.5
	var squash := sin(land_left / 0.14 * PI) * 0.09 if foot.y > PARK_FOOT.y - 20 else 0.0
	var scale := Vector2(0.40 * (1 + squash), 0.40 * (1 - squash))
	var bob := sin(clock * TAU / 0.67) * 2.0 if action == "run" else 0.0
	var rotation := 0.055 * swing if lane == 0 else -0.10 * swing
	var position := foot + Vector2(22 * swing, bob)
	canvas.draw_set_transform(position, rotation, scale)
	var rect := Rect2(Vector2(-215, -572), Vector2(430, 572))
	if action != "run":
		canvas.draw_texture_rect(PORTRAIT, Rect2(rect.position - Vector2(18, 0), rect.size), false, Color(0.2, 0.7, 1, alpha * 0.12))
	canvas.draw_texture_rect(PORTRAIT, rect, false, Color(1, 0.6 if miss_left > 0 else 1.0, 0.6 if miss_left > 0 else 1.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_on(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(PARK_FOOT + Vector2(0, -3), 0, Vector2(1.7, 0.18))
	canvas.draw_circle(Vector2.ZERO, 34 - height * 10, Color(0.2, 0.25, 0.2, 0.20))
	canvas.draw_set_transform(Vector2.ZERO)
	if sustaining[0] and sustaining[1]:
		_park_body(canvas, 1 - primary_lane, PARK_FOOT - Vector2(0, PARK_GAP * (1 - primary_lane)), 0.60)
	elif echo_left > 0:
		_park_body(canvas, echo_lane, PARK_FOOT - Vector2(0, PARK_GAP * echo_lane), 0.30 * echo_left / 0.18)
	_park_body(canvas, primary_lane, PARK_FOOT - Vector2(0, PARK_GAP * height))
	if land_left > 0:
		var p := 1 - land_left / 0.14
		for direction in [-1, 1]:
			canvas.draw_line(PARK_FOOT + Vector2(direction * (24 + p * 35), 0), PARK_FOOT + Vector2(direction * (40 + p * 45), -5), Color(1, 1, 1, 1 - p), 4, true)
	for lane in range(2):
		var center := Vector2(310, 456 - PARK_GAP * lane)
		var color := Color("168bbd") if lane == 0 else Color("d45391")
		if actions[lane] != "run" and elapsed[lane] < 0.20:
			var p: float = elapsed[lane] / 0.20
			canvas.draw_arc(center - Vector2(22, 0), 39, -1.2 + p, 1.2 + p, 24, Color(1, 1, 1, 1 - p), 9, true)
			canvas.draw_arc(center - Vector2(22, 0), 39, -1.2 + p, 1.2 + p, 24, Color(color, 1 - p), 4, true)
		if impact[lane] > 0:
			var p: float = 1 - impact[lane] / 0.13
			for i in range(8):
				var direction := Vector2.from_angle(i * TAU / 8)
				canvas.draw_line(center + direction * 12, center + direction * (26 + p * 18), Color(color, 1 - p), 4, true)
