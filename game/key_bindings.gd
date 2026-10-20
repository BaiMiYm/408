extends RefCounted

const DEFAULT_KEYS := [[KEY_J, KEY_LEFT], [KEY_F, KEY_RIGHT]]
var keys: Array = DEFAULT_KEYS.duplicate(true)

func reset() -> void:
	keys = DEFAULT_KEYS.duplicate(true)

func is_allowed(code: int) -> bool:
	# Keep navigation and system modifier keys available outside gameplay.
	return (code >= KEY_SPACE and code <= 126) or code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

func lane_for(code: int) -> int:
	for lane in range(2):
		if code in keys[lane]:
			return lane
	return -1

func assign(lane: int, slot: int, code: int) -> String:
	if lane < 0 or lane > 1 or slot < 0 or slot > 1:
		return "无效的按键位置"
	if not is_allowed(code):
		return "请使用字母、数字、标点、空格或方向键"
	for other_lane in range(2):
		for other_slot in range(2):
			if other_lane == lane and other_slot == slot:
				continue
			if keys[other_lane][other_slot] == code:
				return "该按键已被使用，请选择其他按键"
	keys[lane][slot] = code
	return ""

func load_from(config: ConfigFile) -> void:
	var saved: Variant = config.get_value("input", "keys", null)
	if not saved is Array or saved.size() != 2:
		return
	var seen: Array = []
	for row in saved:
		if not row is Array or row.size() != 2:
			return
		for code in row:
			if not code is int or not is_allowed(code) or code in seen:
				return
			seen.append(code)
	keys = saved.duplicate(true)

func store_in(config: ConfigFile) -> void:
	config.set_value("input", "keys", keys.duplicate(true))

func key_label(lane: int, slot: int) -> String:
	var code: int = keys[lane][slot]
	var labels := {KEY_SPACE: "空格", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓"}
	return labels.get(code, OS.get_keycode_string(code))

func lane_label(lane: int) -> String:
	return "%s / %s" % [key_label(lane, 0), key_label(lane, 1)]
