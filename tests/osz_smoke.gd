extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene._load_path(ProjectSettings.globalize_path("res://Songs/River-AI-SR1.4.osz"))
	if not scene.playing or scene.notes.size() != 421 or scene.audio_player.stream == null:
		push_error("OSZ import failed: " + scene.status_label.text)
		quit(1)
		return
	print("OSZ IMPORT OK: ", scene.song_title, " / ", scene.notes.size(), " notes")
	quit(0)
