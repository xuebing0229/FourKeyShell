extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _fail(message: String) -> void:
	push_error("Gameplay regression failed: " + message)
	quit(1)

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)

	# Health failure must finish the run and stop the music immediately.
	scene.no_fail_mode = false
	scene.playing = true
	scene.audio_player.stream = scene._make_calibration_track()
	scene.audio_player.play()
	scene.audio_started = true
	scene._change_health(-200.0)
	await process_frame
	if scene.playing or scene.audio_player.playing:
		_fail("health failure left gameplay audio running")
		return

	# A press outside the positive Meh window must wait for the normal miss,
	# rather than being awarded a late Meh.
	scene.playing = true
	scene.paused = false
	scene.song_clock_ms = 1138.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 1000, "state": "pending", "hold_broken": false, "head_error_ms": 0.0, "tail_error_ms": 0.0}]
	scene._judge_lane_down(0)
	if scene.notes[0].state != "pending":
		_fail("late press outside Meh window was judged")
		return
	scene.song_clock_ms = 1174.0
	scene._update_note_states()
	if scene.notes[0].state != "missed":
		_fail("late note did not become a miss at the miss window")
		return

	scene.global_offset_ms = 23.0
	if absf(float(scene.get_timing_calibration_state().get("offset_ms", 0.0)) - 23.0) > 0.1:
		_fail("timing calibration state did not expose the saved offset")
		return

	# Losing focus must not leave a phantom held lane when Windows drops key-up.
	scene.playing = true
	scene.paused = false
	scene.lane_down = [true, false, false, false]
	scene._notification(Window.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if scene.lane_down[0] or not scene.paused:
		_fail("focus loss left a lane held or failed to pause")
		return

	print("GAMEPLAY REGRESSION OK: failure stops audio, late window, offset state, focus-safe input")
	quit(0)
