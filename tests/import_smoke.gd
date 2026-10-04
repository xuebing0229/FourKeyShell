extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	var examples := {
		"res://Songs/River-AI/Yiruma & Skullee - River Flows In You - MuG 1.4 test (MuG Diffusion v1.0.0) [AI v1].osu": 421,
		"res://Songs/River-Human/Yiruma & Skullee - river Flows In You (shnevnev) [Hard].osu": 594,
	}
	for chart_path in examples:
		scene.playing = false
		scene.notes.clear()
		scene._load_chart(ProjectSettings.globalize_path(chart_path))
		if not scene.playing or scene.notes.size() != examples[chart_path]:
			push_error("Import failed: " + chart_path + " — " + scene.status_label.text)
			quit(1)
		if not scene.notes[0].has("sample_set") or not scene.notes[0].has("sample_filename"):
			push_error("Import failed: hit sample metadata was not parsed")
			quit(1)
			return
		scene.audio_player.stop()
		print("IMPORT OK: ", chart_path.get_file(), " / ", scene.notes.size(), " notes / ", scene.audio_player.stream.get_length(), " sec")
	quit(0)
