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

	print("MATURE GAMEPLAY OK: autoplay uses normal head/tail paths")
	quit(0)
