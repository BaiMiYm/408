extends RefCounted

# 动画只负责表现，不推进音频时钟、不限制判定或下一次输入。
const ROOT := "res://assets/characters/whitecat/"
const SHEETS := {
	"run": preload("res://assets/characters/whitecat/atlases/run.png"),
	"ground_attack": preload("res://assets/characters/whitecat/atlases/ground_attack.png"),
	"air_attack": preload("res://assets/characters/whitecat/atlases/air_attack.png"),
	"hold": preload("res://assets/characters/whitecat/atlases/hold.png"),
	"barrage": preload("res://assets/characters/whitecat/atlases/barrage.png")
}
const FOOT := Vector2(224, 514)
const LANE_GAP := 144.0
const DRAW_SCALE := 0.38
var metadata: Dictionary
var actions := ["run", "run"]
var elapsed := [0.0, 0.0]
var release_time := [-1.0, -1.0]
var impact := [0.0, 0.0]
var strikes := [0, 0]
var primary_lane := 0
var height := 0.0
var air_left := 0.0
var echo_lane := 0
var echo_left := 0.0
var land_left := 0.0
var miss_left := 0.0
var clock := 0.0
var sustaining := [false, false]

func _init() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "animation.json"))

func reset() -> void:
	actions = ["run", "run"]
	elapsed = [0.0, 0.0]
	release_time = [-1.0, -1.0]
	impact = [0.0, 0.0]
	strikes = [0, 0]
	primary_lane = 0
	height = 0
	air_left = 0
	echo_left = 0
	land_left = 0
	miss_left = 0
	clock = 0
	sustaining = [false, false]

func trigger(lane: int, kind: String = "tap") -> void:
	if primary_lane != lane and (actions[primary_lane] != "run" or height > 0.05):
		echo_lane = primary_lane
		echo_left = 0.18
	primary_lane = lane
	strikes[lane] += 1
	actions[lane] = "hold" if kind == "hold" else ("barrage" if kind == "roll" else ("air_attack" if lane == 1 else "ground_attack"))
	elapsed[lane] = 0
	release_time[lane] = -1
	air_left = 0.43 if lane == 1 else 0.0

func hit(lane: int) -> void:
	impact[lane] = 0.13

func miss() -> void:
	miss_left = 0.16

func step(delta: float, sustain_kinds: Array = ["", ""], held: Array = [false, false]) -> void:
	clock += delta
	echo_left = maxf(0, echo_left - delta)
	land_left = maxf(0, land_left - delta)
	miss_left = maxf(0, miss_left - delta)
	air_left = maxf(0, air_left - delta)
	for lane in range(2):
		impact[lane] = maxf(0, impact[lane] - delta)
		sustaining[lane] = sustain_kinds[lane] != "" and held[lane]
		# 短暂定格仅停角色关键姿态，歌曲和计分始终保持原速。
		if impact[lane] < 0.10:
			elapsed[lane] += delta
		if sustaining[lane]:
			var next := "hold" if sustain_kinds[lane] == "hold" else "barrage"
			if actions[lane] != next:
				actions[lane] = next
				elapsed[lane] = 0
			release_time[lane] = -1
		elif actions[lane] == "hold":
			if release_time[lane] < 0:
				release_time[lane] = 0
			else:
				release_time[lane] += delta
			if release_time[lane] >= 0.12:
				actions[lane] = "run"
				elapsed[lane] = 0
		elif actions[lane] != "run" and elapsed[lane] >= float(metadata.actions[actions[lane]].duration_ms) / 1000:
			actions[lane] = "run"
			elapsed[lane] = 0
	var target := 1.0 if primary_lane == 1 and (air_left > 0 or sustaining[1] or actions[1] == "air_attack") else 0.0
	var previous := height
	height = lerpf(height, target, 1.0 - exp(-delta * (34.0 if target > height else 20.0)))
	if previous >= 0.08 and height < 0.08 and target == 0:
		land_left = 0.14
	if height < 0.002:
		height = 0

func frame_index(lane: int) -> int:
	var action: String = actions[lane]
	var spec: Dictionary = metadata.actions[action]
	if action == "hold":
		if release_time[lane] >= 0:
			return 6 if release_time[lane] < 0.06 else 7
		if elapsed[lane] < 0.12:
			return 0 if elapsed[lane] < 0.06 else 1
		return 2 + int(fposmod(elapsed[lane] - 0.12, 0.44) / 0.11)
	var t: float = elapsed[lane]
	if action == "run" or action == "barrage":
		t = fposmod(t + (0.16 if action == "barrage" and strikes[lane] % 2 == 0 else 0.0), float(spec.duration_ms) / 1000)
	for i in spec.ms.size():
		t -= float(spec.ms[i]) / 1000
		if t < 0:
			return i
	return 7

func _body(canvas: CanvasItem, lane: int, foot: Vector2, alpha: float = 1.0) -> void:
	var index := frame_index(lane)
	var frame_rect := Rect2(Vector2((index % 4) * 448, (index >> 2) * 544), Vector2(448, 544))
	var squash := sin(land_left / 0.14 * PI) * 0.10 if foot.y > FOOT.y - 20 else 0.0
	var scale := Vector2(DRAW_SCALE * (1 + squash), DRAW_SCALE * (1 - squash))
	var target := Rect2(foot - Vector2(224, 496) * scale, Vector2(448, 544) * scale)
	var tint := Color(1, 1, 1, alpha * (0.55 if miss_left > 0 and int(miss_left * 60) % 2 == 0 else 1.0))
	if actions[lane] != "run" and elapsed[lane] < 0.18:
		canvas.draw_texture_rect_region(SHEETS[actions[lane]], Rect2(target.position + Vector2(-13, 4), target.size), frame_rect, Color(0.4, 0.9, 1, alpha * 0.13))
	canvas.draw_texture_rect_region(SHEETS[actions[lane]], target, frame_rect, tint)

func draw_on(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(Vector2(FOOT.x, FOOT.y), 0, Vector2(1.5, 0.18))
	canvas.draw_circle(Vector2.ZERO, 34 - height * 9, Color(0.01, 0.02, 0.04, 0.45 - height * 0.15))
	canvas.draw_set_transform(Vector2.ZERO)
	var dual: bool = sustaining[0] and sustaining[1]
	if dual:
		_body(canvas, 1 - primary_lane, FOOT - Vector2(0, LANE_GAP * (1 - primary_lane)), 0.70)
	elif echo_left > 0:
		_body(canvas, echo_lane, FOOT - Vector2(0, LANE_GAP * echo_lane), 0.38 * echo_left / 0.18)
	_body(canvas, primary_lane, FOOT - Vector2(0, LANE_GAP * height))
	if land_left > 0:
		var progress := 1 - land_left / 0.14
		for side in [-1, 1]:
			canvas.draw_line(Vector2(FOOT.x + side * (22 + progress * 42), FOOT.y - 3), Vector2(FOOT.x + side * (40 + progress * 44), FOOT.y - 6), Color(0.7, 0.9, 1, (1 - progress) * 0.7), 3, true)
	for lane in range(2):
		var center := Vector2(310, 444 - LANE_GAP * lane)
		var color := Color("5de7ee") if lane == 0 else Color("ff71ad")
		if actions[lane] != "run" and elapsed[lane] < 0.20:
			var p: float = elapsed[lane] / 0.20
			canvas.draw_arc(center - Vector2(26, 0), 37 + p * 10, -1.35 + p * 0.4, 1.1 + p * 0.4, 24, Color(color, 0.75 * (1 - p)), 5, true)
		if impact[lane] > 0:
			var p: float = 1 - impact[lane] / 0.13
			for i in range(8):
				var direction := Vector2.from_angle(i * TAU / 8)
				canvas.draw_line(center + direction * (10 + p * 12), center + direction * (24 + p * 20), Color(color, 1 - p), 3, true)
