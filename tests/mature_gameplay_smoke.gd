extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _fail(message: String) -> void:
	push_error("Mature gameplay failed: " + message)
	quit(1)

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.playing = true
	scene.paused = false
	scene.no_fail_mode = true
	scene.notes = [
		{"lane": 0, "time": 1000, "end": 1000, "state": "pending"},
		{"lane": 1, "time": 1100, "end": 1300, "state": "pending"},
	]
	scene.song_clock_ms = 1000.0
	scene.set_autoplay_mode(true)
	scene._process_autoplay(1000.0)
	if scene.notes[0].state != "completed":
		_fail("autoplay did not judge a regular note")
		return
	scene._process_autoplay(1100.0)
	if scene.notes[1].state != "holding":
		_fail("autoplay did not start a hold head")
		return
	scene._process_autoplay(1300.0)
	if scene.notes[1].state != "completed" or int(scene.judgement_counts["Perfect"]) < 3:
		_fail("autoplay did not release and judge a hold tail")
		return
	if not scene.get_gameplay_snapshot().get("practice", false):
		_fail("autoplay run was not marked as non-recorded practice")
		return
	if int(scene.score) != 1000000 or str(scene.get_gameplay_snapshot().get("grade", "")) != "SS":
		_fail("a full autoplay run did not produce a normalized 1,000,000 / SS result")
		return
	if scene.get_timing_error_history().size() != 3:
		_fail("timing error history did not retain head and tail judgements")
		return
	var quality: Dictionary = scene._inspect_chart_quality([
		{"lane": 0, "time": 1000, "end": 1400},
		{"lane": 0, "time": 1200, "end": 1200},
	])
	if bool(quality.get("ok", true)) or quality.get("issues", []).is_empty():
		_fail("chart quality inspection did not report an overlapping lane")
		return
	if scene._grade_for_accuracy(99.0) != "S" or scene._grade_for_accuracy(95.0) != "A" or scene._grade_for_accuracy(100.0) != "SS":
		_fail("mania grade boundaries are not strict")
		return

	print("MATURE GAMEPLAY OK: autoplay uses normal head/tail paths, normalized score and error history")
	quit(0)
