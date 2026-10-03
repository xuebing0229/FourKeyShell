extends SceneTree

var loaded_metadata: Dictionary = {}
var started_metadata: Dictionary = {}
var started_count := 0

func _initialize() -> void:
	call_deferred("run_test")

func _on_chart_loaded(metadata: Dictionary) -> void:
	loaded_metadata = metadata

func _on_gameplay_started(metadata: Dictionary) -> void:
	started_metadata = metadata
	started_count += 1

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.chart_loaded.connect(_on_chart_loaded)
	scene.gameplay_started.connect(_on_gameplay_started)
	scene.load_chart_file(ProjectSettings.globalize_path("res://Songs/River-AI/Yiruma & Skullee - River Flows In You - MuG 1.4 test (MuG Diffusion v1.0.0) [AI v1].osu"))
	if loaded_metadata.get("note_count", 0) != 421 or started_metadata.get("version", "") != "AI v1":
		push_error("Chart API metadata signal failed")
		quit(1)
		return
	if scene.get_chart_metadata().get("hold_count", 0) <= 0:
		push_error("Chart API metadata missing hold count")
		quit(1)
		return
	scene.pause_game()
	if not scene.paused:
		push_error("pause_game API failed")
		quit(1)
		return
	scene.resume_game()
	if scene.paused:
		push_error("resume_game API failed")
		quit(1)
		return
	scene.retry_run()
	if started_count != 2 or not scene.get_gameplay_snapshot().playing:
		push_error("retry_run did not restart gameplay")
		quit(1)
		return
	if not scene.set_lane_keycode(0, scene.key_codes[0]):
		push_error("set_lane_keycode API rejected existing binding")
		quit(1)
		return
	scene.set_volume_percent(65.0)
	if absf(scene.get_volume_percent() - 65.0) > 0.1:
		push_error("volume API failed")
		quit(1)
		return
	scene.set_scroll_speed_percent(140.0)
	if absf(scene.get_scroll_speed_percent() - 140.0) > 0.1:
		push_error("scroll speed API failed")
		quit(1)
		return
	scene.seek_practice_ms(10000.0)
	if scene.get_gameplay_snapshot().song_time_ms < 7000.0:
		push_error("practice seek API failed")
		quit(1)
		return
	scene.set_practice_loop_start()
	scene.seek_practice_ms(5000.0)
	scene.set_practice_loop_end()
	var loop_state: Dictionary = scene.get_practice_loop()
	if float(loop_state.get("end_ms", -1.0)) <= float(loop_state.get("start_ms", -1.0)):
		push_error("practice loop API failed")
		quit(1)
		return
	scene.clear_practice_loop()
	if float(scene.get_practice_loop().get("start_ms", 0.0)) >= 0.0:
		push_error("practice loop clear API failed")
		quit(1)
		return
	if not scene.get_hit_sounds_enabled():
		push_error("hit sounds should default to enabled")
		quit(1)
		return
	scene.set_hit_sounds_enabled(false)
	if scene.get_hit_sounds_enabled():
		push_error("hit sound toggle API failed")
		quit(1)
		return
	scene.set_hit_sounds_enabled(true)
	scene.start_timing_calibration()
	if not bool(scene.get_timing_calibration_state().get("active", false)):
		push_error("timing calibration start API failed")
		quit(1)
		return
	scene.cancel_timing_calibration()
	if bool(scene.get_timing_calibration_state().get("active", false)):
		push_error("timing calibration cancel API failed")
		quit(1)
		return
	if scene.get_recent_charts().is_empty():
		push_error("recent charts API failed")
		quit(1)
		return
	var import_source := ProjectSettings.globalize_path("res://Songs/River-AI/Yiruma & Skullee - River Flows In You - MuG 1.4 test (MuG Diffusion v1.0.0) [AI v1].osu")
	if not scene.import_chart_to_library(import_source) or scene.get_library_entries().is_empty():
		push_error("library import API failed")
		quit(1)
		return
	if not scene.preview_library_entry(0) or not bool(scene.get_preview_state().get("active", false)):
		push_error("library preview API failed")
		quit(1)
		return
	scene.stop_preview()
	if bool(scene.get_preview_state().get("active", false)):
		push_error("library preview stop API failed")
		quit(1)
		return
	print("SHELL API OK: metadata, load, pause/resume, retry, key binding, volume, scroll speed, practice seek/loop, hit sounds, timing calibration, library search/preview interfaces")
	quit(0)
