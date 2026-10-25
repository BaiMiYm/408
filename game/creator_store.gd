extends RefCounted

# 本机身份只用于区分作品归属，不是联网认证或文件加密。
var base := "user://creator"
var profiles: Array = []
var active_id := ""

func _init(directory: String = "user://creator") -> void:
	base = directory
	DirAccess.make_dir_recursive_absolute(base)
	var data = read_json(base.path_join("profiles.json"))
	profiles = data.get("profiles", [])
	active_id = data.get("active_id", "")
	if not profiles.any(func(p): return p.id == active_id):
		active_id = ""

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func write_json(path: String, value: Variant) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(temp, path) == OK

func _save_profiles() -> bool:
	return write_json(base.path_join("profiles.json"), {"profiles": profiles, "active_id": active_id})

func create_profile(nickname: String) -> String:
	nickname = nickname.strip_edges()
	if nickname.is_empty() or nickname.length() > 20:
		return "昵称请输入 1–20 个字符"
	if profiles.any(func(p): return p.name == nickname):
		return "昵称已存在，请选择该账号登录"
	var id := Crypto.new().generate_random_bytes(12).hex_encode()
	profiles.append({"id": id, "name": nickname})
	var previous := active_id
	active_id = id
	if not _save_profiles():
		profiles.pop_back()
		active_id = previous
		return "账号保存失败"
	return ""

func login(id: String) -> bool:
	if not id.is_empty() and not profiles.any(func(p): return p.id == id):
		return false
	var previous := active_id
	active_id = id
	if not _save_profiles():
		active_id = previous
		return false
	return true

func nickname() -> String:
	for p in profiles:
		if p.id == active_id:
			return p.name
	return "未登录"

func new_project() -> Dictionary:
	return {"id": Crypto.new().generate_random_bytes(12).hex_encode(), "title": "未命名曲目", "artist": "", "bpm": 120.0, "grid_offset_seconds": 0.0, "duration": 0.0, "audio": "", "cover": "", "notes": []}

func project_dir(id: String) -> String:
	if active_id.is_empty() or id.length() != 24 or not id.is_valid_hex_number(false):
		return ""
	return base.path_join(active_id).path_join(id)

func load_audio(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	if path.get_extension().to_lower() == "mp3":
		var audio := AudioStreamMP3.new()
		audio.data = FileAccess.get_file_as_bytes(path)
		return audio if audio.get_length() > 0 else null
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	return null

func import_asset(project: Dictionary, source: String, kind: String) -> String:
	var folder := project_dir(project.id)
	if folder.is_empty():
		return "请先登录本机账号"
	if kind == "audio":
		var stream := load_audio(source)
		if stream == null:
			return "无法读取音乐，请选择有效的 MP3 / OGG"
		if not project.notes.is_empty() and absf(float(project.duration) - stream.get_length()) > 0.1:
			return "已有音符时不替换不同长度的录音，请新建作品"
		DirAccess.make_dir_recursive_absolute(folder)
		var target := folder.path_join("music-" + Crypto.new().generate_random_bytes(6).hex_encode() + "." + source.get_extension().to_lower())
		if source != target and DirAccess.copy_absolute(source, target) != OK:
			return "音乐复制失败"
		project.audio = target
		project.audio_name = source.get_file()
		project.duration = stream.get_length()
	else:
		if Image.load_from_file(source) == null:
			return "无法读取封面"
		DirAccess.make_dir_recursive_absolute(folder)
		var target := folder.path_join("cover-" + Crypto.new().generate_random_bytes(6).hex_encode() + "." + source.get_extension().to_lower())
		if source != target and DirAccess.copy_absolute(source, target) != OK:
			return "封面复制失败"
		project.cover = target
	return ""

func validate(project: Dictionary) -> String:
	if project.title.strip_edges().is_empty():
		return "请填写曲名"
	if float(project.bpm) < 20 or float(project.bpm) > 400:
		return "BPM 应在 20–400 之间"
	if load_audio(project.audio) == null:
		return "请先导入主音乐"
	var previous := [-1.0, -1.0]
	for n in project.notes:
		var lane := int(n.get("lane", -1))
		var time := float(n.get("time", -1))
		var end := float(n.get("end_time", time))
		if lane not in [0, 1] or n.get("kind", "") not in ["tap", "hold", "roll"]:
			return "音符类型或轨道无效"
		if time < 0 or end >= float(project.duration) or end < time or time < previous[lane] + 0.04:
			return "同轨音符重叠、间距小于 40ms 或超出音乐范围"
		if n.kind != "tap" and end <= time:
			return "长按或连打需要结束时间"
		if n.kind == "roll" and int(n.get("required_hits", 0)) < 2:
			return "连打至少需要两次击打"
		previous[lane] = end
	return ""

func save_project(project: Dictionary) -> String:
	var folder := project_dir(project.id)
	if folder.is_empty():
		return "请先登录本机账号"
	project.notes.sort_custom(func(a, b): return a.time < b.time or (a.time == b.time and a.lane < b.lane))
	var error := validate(project)
	if not error.is_empty():
		return error
	DirAccess.make_dir_recursive_absolute(folder)
	if not write_json(folder.path_join("project.json"), project):
		return "作品保存失败"
	return ""

func projects() -> Array:
	var result: Array = []
	if active_id.is_empty():
		return result
	var folder := base.path_join(active_id)
	if not DirAccess.dir_exists_absolute(folder):
		return result
	for id in DirAccess.get_directories_at(folder):
		var data := read_json(folder.path_join(id).path_join("project.json"))
		if not data.is_empty() and data.get("id", "") == id:
			result.append(data)
	result.sort_custom(func(a,b): return a.title < b.title)
	return result

func playlist_entries() -> Array:
	var entries: Array = []
	for p in projects():
		entries.append({"id": "custom_" + p.id, "title": p.title, "artist": p.artist, "charts": [{"label": "自制", "project": p}]})
	return entries
