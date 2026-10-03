extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func _click_at(scene: Node, position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = position
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	scene.get_viewport().push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = position
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	scene.get_viewport().push_input(up)
	await process_frame

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var skin = scene.skin_root
	if skin == null or skin.current_page != skin.Page.HOME:
		push_error("skin did not start on home page")
		quit(1)
		return
	# Sidebar navigation must be clickable.
	await _click_at(scene, Vector2(100, 218))
	if skin.current_page != skin.Page.LIBRARY:
		push_error("library navigation click failed")
		quit(1)
		return
	await _click_at(scene, Vector2(100, 322))
	if skin.current_page != skin.Page.SETTINGS:
		push_error("settings navigation click failed")
		quit(1)
		return
	# Return home, then click a page-content button outside the rail.
	await _click_at(scene, Vector2(100, 166))
	await _click_at(scene, Vector2(500, 370))
	if skin.current_page != skin.Page.LIBRARY:
		push_error("content button click was swallowed by the navigation container")
		quit(1)
		return
	print("UI CLICK OK: sidebar and page-content buttons receive mouse input")
	quit(0)
