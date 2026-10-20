extends SceneTree

const Session = preload("res://rhythm_session.gd")

func _initialize() -> void:
	var s = Session.new()
	var prompts: Array = []
	s.prompted.connect(func(_lane, message): prompts.append(message))
	s.reset([{"time": 1.0, "lane": 0, "kind": "tap"}, {"time": 2.0, "lane": 0, "kind": "tap"}])
	s.press("early", 0, 0.2)
	s.release("early", 0.21)
	assert(s.score == 0 and s.combo == 0 and prompts.is_empty())
	s.press("hit", 0, 1.0)
	s.release("hit", 1.01)
	for i in range(20):
		var time := 1.2 + i * 0.025
		s.press("extra", i % 2, time)
		s.release("extra", time + 0.01)
	assert(s.score == 1000 and s.combo == 1 and s.best_combo == 1)
	assert(s.counts["PERFECT"] == 1 and s.counts["MISS"] == 0)
	assert(prompts.is_empty())
	s.update(2.3)
	assert(s.counts["MISS"] == 1 and s.combo == 0)
	print("PASS: empty presses do not score, penalize, break combo or emit prompts; real misses still count")
	quit()
