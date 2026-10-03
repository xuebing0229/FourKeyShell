# 定制 UI 皮肤模板

Four Key Shell 默认查找 `res://skins/active_skin.tscn`。也可以在 `project.godot` 中设置：

```ini
[four_key_shell]
skin_scene="res://skins/my_skin.tscn"
```

皮肤场景的根节点使用 `Control`。加载后，壳子会调用根节点的可选方法：

```gdscript
func attach_shell(shell: Control) -> void:
	_shell = shell
	shell.chart_loaded.connect(_on_chart_loaded)
	shell.judgement_made.connect(_on_judgement_made)
	shell.progress_changed.connect(_on_progress_changed)
	shell.gameplay_finished.connect(_on_finished)

func _on_play_pressed() -> void:
	_shell.open_file_dialog()
```

常用接口：

- `load_path(path)`、`open_file_dialog()`
- `pause_game()`、`resume_game()`、`retry_run()`
- `get_chart_metadata()`、`get_gameplay_snapshot()`
- `get_lane_bindings()`、`set_lane_keycode(lane, keycode)`
- `set_default_playfield_visible(false)`：让皮肤完全接管轨道和音符绘制

这样换标题、配色、按钮、结算页或整套布局时，只替换皮肤场景和资源，不改谱面解析、音频、判定、长键和结算逻辑。
