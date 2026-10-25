extends Control

signal edited(message: String)
signal seek_requested(time: float)
signal selection_changed
var project: Dictionary = {}
var view_start := 0.0
var subdivision := 4
var tool := "tap"
var length_beats := 1.0
var roll_hits := 8
var erase := false
var cursor := 0.0
var history: Array = []
var future: Array = []
var waveform := PackedFloat32Array()
var waveform_stream: AudioStream
var waveform_enabled := true
var selected: Array[int] = []
var clipboard: Array = []
var drag_origin := Vector2.ZERO
var drag_before: Array = []
var drag_preview: Array = []
var dragging := false
var resizing := false
var drag_moved := false
var wave_decoder: AudioStreamPlayback
var wave_key := ""
var wave_bin := 0

func bar_start(time: float) -> float:
	var offset := float(project.get("grid_offset_seconds", 0.0))
	return maxf(0.0, offset + floor((time - offset + 0.000001) / window_seconds()) * window_seconds())

func bar_end(time: float) -> float:
	var offset := float(project.get("grid_offset_seconds", 0.0))
	return minf(float(project.get("duration", 0)), offset + (floor((time - offset + 0.000001) / window_seconds()) + 1) * window_seconds())

func lane_y(lane: int) -> float:
	return size.y * (0.79 if lane == 0 else 0.47)

func _process(_delta: float) -> void:
	if not waveform_enabled or waveform_stream == null or not is_visible_in_tree():
		return
	var key := "%s/%.6f/%.6f" % [waveform_stream.get_instance_id(), view_start, window_seconds()]
	if key != wave_key:
		wave_key = key
		wave_decoder = waveform_stream.instantiate_playback()
		wave_decoder.start(view_start)
		waveform.resize(256)
		waveform.fill(0)
		wave_bin = 0
	var frames := maxi(1, int(ceil(window_seconds() * AudioServer.get_mix_rate() / 256.0)))
	for i in range(16):
		if wave_bin >= 256:
			break
		var samples := wave_decoder.mix_audio(1.0, frames)
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		waveform[wave_bin] = minf(peak, 1.0)
		wave_bin += 1
	queue_redraw()

func beat() -> float:
	return 60.0 / float(project.get("bpm", 120.0))

func window_seconds() -> float:
	return beat() * 8.0

func snap(time: float) -> float:
	var offset := float(project.get("grid_offset_seconds", 0.0))
	return maxf(0.0, snappedf(time - offset, beat() / subdivision) + offset)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			begin_pointer(event.position, event.button_index == MOUSE_BUTTON_RIGHT, event.ctrl_pressed)
		elif dragging:
			end_drag()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		update_drag(event.position)
		accept_event()

func hit_note(pos: Vector2) -> int:
	for i in range(project.notes.size() - 1, -1, -1):
		var n: Dictionary = project.notes[i]
		var x := (float(n.time) - view_start) / window_seconds() * size.x
		var tail := (float(n.get("end_time", n.time)) - view_start) / window_seconds() * size.x
		if absf(pos.y - lane_y(int(n.lane))) < 22 and pos.x >= x - 17 and pos.x <= tail + 17:
			return i
	return -1

func begin_pointer(pos: Vector2, remove: bool = false, multiple: bool = false) -> void:
	if pos.y < 26:
		seek_requested.emit(clampf(view_start + pos.x / size.x * window_seconds(), 0, maxf(0, float(project.duration) - 0.001)))
		return
	var index := hit_note(pos)
	if remove or erase:
		if index >= 0:
			selected.assign([index])
			delete_selected()
		return
	if index < 0:
		selected.clear()
		selection_changed.emit()
		place(pos)
		return
	if multiple:
		if index in selected:
			selected.erase(index)
		else:
			selected.append(index)
		queue_redraw()
		selection_changed.emit()
		return
	if index not in selected:
		selected.assign([index])
	drag_origin = pos
	drag_before = project.notes.duplicate(true)
	drag_preview = []
	dragging = true
	drag_moved = false
	var note: Dictionary = project.notes[index]
	var tail := (float(note.get("end_time", note.time)) - view_start) / window_seconds() * size.x
	resizing = selected.size() == 1 and note.kind != "tap" and absf(pos.x - tail) < 16
	selection_changed.emit()
	queue_redraw()

func update_drag(pos: Vector2) -> void:
	if not dragging or pos.distance_to(drag_origin) < 4:
		return
	drag_moved = true
	drag_preview = drag_before.duplicate(true)
	var delta_time := (pos.x - drag_origin.x) / size.x * window_seconds()
	var delta_lane := (0 if pos.y >= size.y * 0.62 else 1) - (0 if drag_origin.y >= size.y * 0.62 else 1)
	var anchor: float = drag_before[selected[0]].time
	delta_time = snap(anchor + delta_time) - anchor
	for index in selected:
		var n: Dictionary = drag_preview[index]
		if resizing:
			n.end_time = snap(float(n.end_time) + delta_time)
		else:
			n.time = float(n.time) + delta_time
			n.lane = clampi(int(n.lane) + delta_lane, 0, 1)
			if n.has("end_time"):
				n.end_time = float(n.end_time) + delta_time
	queue_redraw()

func end_drag() -> void:
	if dragging and drag_moved:
		if valid_notes(drag_preview):
			var chosen: Array = []
			for i in selected:
				chosen.append(drag_preview[i])
			remember()
			project.notes = drag_preview
			_sort_and_select(chosen)
			edited.emit("已调整音符，可撤销")
		else:
			edited.emit("移动未生效：同轨重叠、持续长度或音乐边界无效")
	dragging = false
	drag_preview = []
	queue_redraw()

func valid_notes(notes: Array) -> bool:
	var ordered := notes.duplicate(true)
	ordered.sort_custom(func(a,b): return a.time < b.time)
	var previous := [-1.0, -1.0]
	for n in ordered:
		var lane := int(n.lane)
		var end := float(n.get("end_time", n.time))
		if float(n.time) < 0 or end >= float(project.duration) or float(n.time) < previous[lane] + 0.04:
			return false
		if n.kind != "tap" and end <= float(n.time):
			return false
		previous[lane] = end
	return true

func _sort_and_select(chosen: Array) -> void:
	project.notes.sort_custom(func(a,b): return a.time < b.time)
	selected.clear()
	for n in chosen:
		var index: int = project.notes.find(n)
		if index >= 0:
			selected.append(index)
	selection_changed.emit()

func delete_selected() -> void:
	if selected.is_empty():
		return
	remember()
	selected.sort()
	for i in range(selected.size() - 1, -1, -1):
		project.notes.remove_at(selected[i])
	selected.clear()
	selection_changed.emit()
	edited.emit("已删除选中音符")
	queue_redraw()

func apply_selected(kind: String, beats: float, hits: int) -> void:
	if selected.is_empty():
		return
	var candidate: Array = project.notes.duplicate(true)
	var chosen: Array = []
	for i in selected:
		var n: Dictionary = candidate[i]
		n.kind = kind
		n.erase("end_time")
		n.erase("required_hits")
		if kind != "tap":
			n.end_time = float(n.time) + beats * beat()
		if kind == "roll":
			n.required_hits = hits
		chosen.append(n)
	if not valid_notes(candidate):
		edited.emit("修改未生效：音符重叠或超出音乐范围")
		return
	remember()
	project.notes = candidate
	_sort_and_select(chosen)
	edited.emit("已修改选中音符")
	queue_redraw()

func copy_notes(whole_bar: bool = false) -> void:
	clipboard.clear()
	var anchor := bar_start(cursor)
	if not whole_bar and not selected.is_empty():
		anchor = INF
		for i in selected:
			anchor = minf(anchor, float(project.notes[i].time))
	for i in project.notes.size():
		var n: Dictionary = project.notes[i]
		if (not whole_bar and not selected.is_empty() and i in selected) or ((whole_bar or selected.is_empty()) and float(n.time) >= anchor and float(n.time) < bar_end(cursor)):
			var copy := n.duplicate(true)
			copy.time = float(copy.time) - anchor
			if copy.has("end_time"):
				copy.end_time = float(copy.end_time) - anchor
			clipboard.append(copy)
	edited.emit("已复制 %d 个音符" % clipboard.size())

func paste_notes(at: float = -1.0) -> void:
	if clipboard.is_empty():
		return
	var target := snap(cursor) if at < 0 else at
	var candidate: Array = project.notes.duplicate(true)
	var chosen: Array = []
	for n in clipboard:
		var copy: Dictionary = n.duplicate(true)
		copy.time = float(copy.time) + target
		if copy.has("end_time"):
			copy.end_time = float(copy.end_time) + target
		candidate.append(copy)
		chosen.append(copy)
	if not valid_notes(candidate):
		edited.emit("粘贴未生效：目标位置有重叠或超出音乐范围")
		return
	remember()
	project.notes = candidate
	_sort_and_select(chosen)
	edited.emit("已粘贴 %d 个音符，可撤销" % chosen.size())
	queue_redraw()

func duplicate_bar() -> void:
	copy_notes(true)
	paste_notes(bar_end(cursor))

func record_tap(time: float, lane: int) -> void:
	var note := {"time": snap(time), "lane": lane, "kind": "tap", "section": "录谱"}
	var candidate: Array = project.notes.duplicate(true)
	candidate.append(note)
	if valid_notes(candidate):
		remember()
		project.notes = candidate
		_sort_and_select([note])
		edited.emit("已录制%s点按" % ("地面" if lane == 0 else "空中"))
		queue_redraw()

func place(pos: Vector2, remove: bool = false) -> void:
	if project.is_empty() or float(project.get("duration", 0)) <= 0:
		edited.emit("请先导入主音乐")
		return
	var time := snap(view_start + clampf(pos.x / size.x, 0, 1) * window_seconds())
	var lane := 1 if pos.y < size.y * 0.62 else 0
	if remove:
		var found := -1
		var distance := window_seconds() * 24.0 / size.x
		for i in project.notes.size():
			var note: Dictionary = project.notes[i]
			if int(note.lane) == lane and absf(float(note.time) - time) <= distance:
				found = i
				break
		if found >= 0:
			remember()
			project.notes.remove_at(found)
			edited.emit("已删除音符，可撤销")
		queue_redraw()
		return
	var note := {"time": time, "lane": lane, "kind": tool, "section": "自制"}
	var end := time
	if tool != "tap":
		end += length_beats * beat()
		note.end_time = end
		if tool == "roll":
			note.required_hits = roll_hits
	if end >= float(project.duration):
		edited.emit("音符不能超过音乐结尾")
		return
	for other in project.notes:
		if int(other.lane) == lane and time <= float(other.get("end_time", other.time)) + 0.04 and end >= float(other.time) - 0.04:
			edited.emit("同轨音符重叠，请删除旧音符或更换位置")
			return
	remember()
	project.notes.append(note)
	project.notes.sort_custom(func(a,b): return a.time < b.time)
	selected.clear()
	edited.emit("已添加%s · %.3fs" % [{"tap":"点按", "hold":"长按", "roll":"连打"}[tool], time])
	queue_redraw()

func remember() -> void:
	history.append(project.notes.duplicate(true))
	if history.size() > 100:
		history.pop_front()
	future.clear()

func undo() -> void:
	if history.is_empty():
		return
	future.append(project.notes.duplicate(true))
	project.notes = history.pop_back()
	selected.clear()
	selection_changed.emit()
	queue_redraw()
	edited.emit("已撤销")

func redo() -> void:
	if future.is_empty():
		return
	history.append(project.notes.duplicate(true))
	project.notes = future.pop_back()
	selected.clear()
	selection_changed.emit()
	queue_redraw()
	edited.emit("已重做")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d32"))
	if project.is_empty():
		return
	var font := get_theme_default_font()
	var colors := [Color("5de7ee"), Color("ff71ad")]
	if waveform_enabled and not waveform.is_empty():
		for i in waveform.size():
			var x := float(i) / waveform.size() * size.x
			var h := waveform[i] * 15.0
			draw_line(Vector2(x, 43 - h), Vector2(x, 43 + h), Color("58738d"), maxf(1, size.x / 256.0))
	var start_tick := int(floor((view_start - float(project.grid_offset_seconds)) / (beat() / subdivision)))
	for i in range(start_tick, start_tick + 8 * subdivision + 3):
		var time := float(project.grid_offset_seconds) + i * beat() / subdivision
		var x := (time - view_start) / window_seconds() * size.x
		if x < 0 or x > size.x:
			continue
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("49627c") if i % subdivision == 0 else Color("25364e"), 1)
		if i % subdivision == 0:
			draw_string(font, Vector2(x + 4, 19), "%.2f" % time, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9daec7"))
		if i % (8 * subdivision) == 0:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color("5de7ee"), 3)
			draw_string(font, Vector2(x + 3, size.y - 5), "第 %d 段" % (int(i / (8 * subdivision)) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5de7ee"))
	for lane in [0, 1]:
		var y := lane_y(lane)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(colors[lane], 0.4), 2)
		draw_string(font, Vector2(8, y - 16), "地面" if lane == 0 else "空中", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, colors[lane])
	var drawn: Array = drag_preview if dragging and drag_moved else project.notes
	for index in drawn.size():
		var n: Dictionary = drawn[index]
		var x := (float(n.time) - view_start) / window_seconds() * size.x
		var tail := (float(n.get("end_time", n.time)) - view_start) / window_seconds() * size.x
		if tail < 0 or x > size.x:
			continue
		var y := lane_y(int(n.lane))
		var color: Color = Color("ffcc64") if n.kind == "roll" else colors[int(n.lane)]
		if n.kind != "tap":
			draw_line(Vector2(maxf(x, 0), y), Vector2(minf(tail, size.x), y), color, 10)
			draw_line(Vector2(minf(tail, size.x), y - 18), Vector2(minf(tail, size.x), y + 18), color, 3)
		if x >= 0:
			draw_circle(Vector2(x, y), 13, color)
			if index in selected:
				draw_arc(Vector2(x,y), 19, 0, TAU, 32, Color.WHITE, 2)
			if n.kind == "roll":
				draw_string(font, Vector2(x - 8, y + 5), str(n.required_hits), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("101d32"))
	var play_x := (cursor - view_start) / window_seconds() * size.x
	if play_x >= 0 and play_x <= size.x:
		draw_line(Vector2(play_x, 0), Vector2(play_x, size.y), Color.WHITE, 2)
