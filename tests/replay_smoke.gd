extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	var chart_path := ProjectSettings.globalize_path("res://Songs/River-AI/Yiruma & Skullee - River Flows In You - MuG 1.4 test (MuG Diffusion v1.0.0) [AI v1].osu")
	scene.load_chart_file(chart_path)
	scene.last_replay_path = scene.chart_source_path
	scene.last_replay_offset_ms = scene.global_offset_ms
	scene.last_replay_events.clear()
	scene.last_replay_events.append({"time_ms": 0.0, "lane": 0, "down": true})
	scene.last_replay_events.append({"time_ms": 50.0, "lane": 0, "down": false})
	scene.replay_complete_available = true
	if not scene.start_replay() or not scene.replay_playing:
		push_error("replay start API failed")
		quit(1)
		return
	scene.stop_replay()
	if scene.replay_playing or bool(scene.get_replay_info().get("playing", false)):
		push_error("replay stop API failed")
		quit(1)
		return
	print("REPLAY OK: available -> start -> stop")
	quit(0)
