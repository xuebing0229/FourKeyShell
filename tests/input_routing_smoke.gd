extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _fail(message: String) -> void:
	push_error("Input routing failed: " + message)
	quit(1)

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.playing = true
	scene.paused = false
	scene.key_codes[0] = KEY_LEFT
	scene.key_labels[0] = "Left"
	scene.song_clock_ms = 1000.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "pending"}]

	# Arrow keys must reach the gameplay judge even when the skin has focused UI.
	var press := InputEventKey.new()
	press.keycode = KEY_LEFT
	press.pressed = true
	scene._input(press)
	if not scene.lane_down[0] or scene.notes[0].state != "holding":
		_fail("arrow-key press did not start the hold")
		return

	# A held lane must keep the body active through the tail and complete there.
	scene.song_clock_ms = 1500.0
	scene._update_note_states()
	if scene.notes[0].state != "holding":
		_fail("hold disappeared while the lane remained down")
		return

	# A real key-up must reach the hold judge and break the body. The previous
	# version accidentally nested this branch under the key-down branch.
	var release := InputEventKey.new()
	release.keycode = KEY_LEFT
	release.pressed = false
	scene._input(release)
	if scene.lane_down[0] or scene.notes[0].state != "broken":
		_fail("arrow-key release did not break the active hold")
		return

	# Re-pressing during the body restores the visual hold, while retaining the
	# earlier break result, matching the supported osu!mania interaction.
	scene.song_clock_ms = 1600.0
	scene._input(press)
	if not scene.lane_down[0] or scene.notes[0].state != "holding":
		_fail("hold did not restore after a mid-body re-press")
		return
	scene.song_clock_ms = 2000.0
	scene._input(release)
	if scene.notes[0].state != "completed":
		_fail("hold did not complete at its tail")
		return

	print("INPUT ROUTING OK: arrow key reaches gameplay and held note survives to tail")
	quit(0)
