extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _fail(message: String) -> void:
	push_error("Health logic failed: " + message)
	quit(1)

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.playing = true
	scene.paused = false
	scene.no_fail_mode = true
	scene.health = 50.0
	scene.song_clock_ms = 1500.0
	scene.notes = [{"lane": 0, "time": 1000, "end": 2000, "state": "holding"}]
	scene._update_hold_health(1.0)
	if scene.health <= 50.0:
		_fail("held body did not regenerate health")
		return
	scene.notes[0].state = "broken"
	var health_after_break: float = scene.health
	scene._update_hold_health(1.0)
	if scene.health != health_after_break:
		_fail("broken hold incorrectly regenerated health")
		return
	scene.health = 10.0
	scene._record_judgement("Miss", 0, 0.0)
	if scene.health >= 10.0 or not scene.playing:
		_fail("NoFail did not preserve the run while draining health")
		return

	scene.no_fail_mode = false
	scene.health = 5.0
	scene._record_judgement("Miss", 0, 0.0)
	await process_frame
	if scene.health != 0.0 or scene.playing:
		_fail("enabled fail mode did not end at zero health")
		return

	print("HEALTH OK: held body regenerates, broken body stops regen, NoFail preserves run, fail mode ends at zero")
	quit(0)
