extends RefCounted

static func play(scene: Node, keyboard := false) -> void:
	var events: Array = []
	for note in scene.notes:
		var lane := int(note["lane"])
		var start := float(note["time"])
		var kind: String = note.get("kind", "tap")
		if kind == "roll":
			for i in range(int(note["required_hits"])):
				var t := start + (float(note["end_time"]) - start) * i / float(note["required_hits"])
				events.append({"time": t, "lane": lane, "down": true})
				events.append({"time": t + 0.015, "lane": lane, "down": false})
		else:
			events.append({"time": start, "lane": lane, "down": true})
			events.append({"time": float(note["end_time"]) + 0.010 if kind == "hold" else start + 0.015, "lane": lane, "down": false})
	events.sort_custom(func(a, b): return a["time"] < b["time"])
	for event in events:
		scene.song_time = float(event["time"])
		scene.session.update(scene.song_time)
		if keyboard:
			var key := InputEventKey.new()
			key.keycode = int(scene.bindings.keys[int(event["lane"])][0]) as Key
			key.pressed = event["down"]
			scene._input(key)
		else:
			var touch := InputEventScreenTouch.new()
			touch.index = int(event["lane"])
			touch.position = Vector2(200 if touch.index == 0 else 900, 620)
			touch.pressed = event["down"]
			scene._input(touch)
	scene.song_time = float(scene.song["duration"]) - 0.1
	scene.session.update(scene.song_time)
