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

	print("HEALTH OK: NoFail preserves run, enabled fail mode ends at zero")
	quit(0)
