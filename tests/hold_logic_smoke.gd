extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _fail(message: String) -> void:
	push_error("Hold logic failed: " + message)
	quit(1)

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.playing = true
	scene.paused = false

	# Head press must turn a hold into an active hold.
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "pending"}]
	scene.lane_down = [true, false, false, false]
	scene._judge_lane_down(0)
	if scene.notes[0].state != "holding":
		_fail("head press did not enter holding")
		return

	# Missing a hold head must record one Miss but keep a grey body/tail alive
	# until the tail window expires, instead of making the whole note vanish.
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "pending"}]
	scene.lane_down = [false, false, false, false]
	var miss_count_before := int(scene.judgement_counts["Miss"])
	scene.song_clock_ms = 1000.0 + scene.miss_window_ms + 1.0
	scene._update_note_states()
	if scene.notes[0].state != "hold_missed" or int(scene.judgement_counts["Miss"]) != miss_count_before + 1:
		_fail("missed hold head did not remain visible as hold_missed")
		return
	scene.song_clock_ms = 1500.0
	scene._update_note_states()
	if scene.notes[0].state != "hold_missed":
		_fail("missed hold disappeared before its tail")
		return
	scene.song_clock_ms = 2000.0 + scene.hold_release_window_ms + 1.0
	scene._update_note_states()
	if scene.notes[0].state != "missed" or int(scene.judgement_counts["Miss"]) != miss_count_before + 1:
		_fail("missed hold did not retire after its tail window")
		return

	# A late re-press may hold the remaining body, but never changes the Miss
	# into a successful head or awards an unbroken-tail bonus.
	scene.song_clock_ms = 1000.0 + scene.miss_window_ms + 1.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "pending"}]
	scene._update_note_states()
	var score_before := int(scene.score)
	var accuracy_total_before := float(scene.accuracy_total)
	scene.song_clock_ms = 1500.0
	scene.lane_down[0] = true
	scene._judge_lane_down(0)
	if scene.notes[0].state != "holding" or not scene.notes[0].hold_broken or int(scene.score) != score_before:
		_fail("late re-press did not preserve the missed-head result")
		return
	scene.song_clock_ms = 2000.0
	scene._update_note_states()
	if scene.notes[0].state != "completed" or int(scene.score) != score_before or float(scene.accuracy_total) != accuracy_total_before:
		_fail("re-pressed missed head was incorrectly awarded an unbroken tail")
		return

	# Reset the lane before checking early-release behaviour.
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "pending"}]
	scene.lane_down = [true, false, false, false]
	scene._judge_lane_down(0)

	# Releasing well before the tail must break the hold.
	scene.song_clock_ms = 1500.0
	scene.lane_down[0] = false
	scene._judge_lane_up(0)
	if scene.notes[0].state != "broken" or int(scene.judgement_counts["Hold Break"]) != 1:
		_fail("early release was not recorded as Hold Break")
		return

	# A broken hold remains in the lane and can be re-pressed before its tail.
	scene.song_clock_ms = 1750.0
	scene.lane_down[0] = true
	scene._judge_lane_down(0)
	if scene.notes[0].state != "holding":
		_fail("broken hold did not restore when re-pressed mid-body")
		return
	scene.song_clock_ms = 2000.0
	scene._update_note_states()
	if scene.notes[0].state != "completed" or int(scene.judgement_counts["Hold Break"]) != 1 or int(scene.judgement_counts["Hold OK"]) != 0:
		_fail("restored hold changed its original break result")
		return

	# A second hold kept through its tail must complete automatically.
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 1, "time": 1000, "end": 2000, "state": "pending"}]
	scene.lane_down = [false, true, false, false]
	scene._judge_lane_down(1)
	scene.song_clock_ms = 2000.0
	scene._update_note_states()
	if scene.notes[0].state != "completed" or int(scene.judgement_counts["Hold OK"]) != 1:
		_fail("held note did not complete at its tail")
		return

	# Pausing must freeze hold judgement; releasing during the pause is not a break.
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 2, "time": 1000, "end": 2000, "state": "pending"}]
	scene.lane_down = [false, false, true, false]
	scene._judge_lane_down(2)
	scene.paused = true
	scene.lane_down[2] = false
	scene._judge_lane_up(2)
	if scene.notes[0].state != "holding":
		_fail("releasing during pause incorrectly broke hold")
		return

	print("HOLD LOGIC OK: missed-head lifetime/re-press, head, break/re-press, tail completion, pause-safe release")
	quit(0)
