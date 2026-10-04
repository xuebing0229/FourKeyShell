# Four Key Shell 接口

`Main.tscn` 的根节点仍然是当前的游戏壳子。后续替换 UI 时，只需要保留这个节点或连接到它的接口，不需要重写谱面判定。

## 公开方法

- `load_path(path)`：根据扩展名加载 `.osu` 或 `.osz`。
- `load_chart_file(path)`：加载单个 4K `.osu`。
- `load_chart_package(path)`：加载 `.osz`，自动筛选 4K 谱面。
- `pause_game()` / `resume_game()`：暂停或继续当前演奏。
- `retry_run()`：重置当前演奏。
- `get_chart_metadata()`：返回标题、作者、OverallDifficulty、判定窗口、TimingPoints/BPM、音符数、长键数和时长。
- `get_gameplay_snapshot()`：返回当前分数、连击、准确率、血量、失败状态、时间和音符状态。
- `get_personal_best()`：返回当前谱面的本地最佳成绩；没有记录时返回空字典。
- `get_personal_bests()`：返回所有谱面的本地最佳成绩，供成就/成绩页面展示。
- `get_lane_bindings()`：返回四条轨道的键位名称。
- `set_lane_keycode(lane, keycode)`：修改一条轨道的键位；重复键会返回 `false`。
- `begin_key_rebind(lane)`：进入指定轨道的按键捕获状态，用户按下新键后自动保存。
- `cancel_key_rebind()`：取消当前按键捕获。
- `reset_lane_bindings()`：恢复默认 `D F J K` 并保存。
- `get_volume_percent()` / `set_volume_percent(value)`：读取或设置 0–100 的音量，并保存到用户配置。
- `get_hit_sounds_enabled()` / `set_hit_sounds_enabled(enabled)`：读取或切换内置判定音效，并保存到用户配置。
- `get_health()`：读取当前血量。
- `get_no_fail_mode()` / `set_no_fail_mode(enabled)`：读取或切换练习模式；练习模式不会因血量归零结束。
- `get_autoplay_mode()` / `set_autoplay_mode(enabled)`：开启或关闭自动演示；自动演示复用正常头尾判定、血量和事件，但本局标记为练习，不写入本地最佳成绩。
- `toggle_fullscreen()`：切换全屏并返回切换后的状态。
- `get_scroll_speed_percent()` / `set_scroll_speed_percent(value)`：读取或设置 50–200% 下落速度，并保存到用户配置。
- `get_recent_charts()` / `clear_recent_charts()`：读取或清空最近打开的谱面路径。
- `get_library_entries()` / `scan_library()`：读取或刷新内置曲库和用户曲库。
- `open_import_dialog()` / `import_chart_to_library(path)`：把 `.osu` 或 `.osz` 复制进用户曲库并载入。
- `load_library_entry(index)`：载入曲库中的条目。
- `seek_practice_ms(delta_ms)`：练习跳转；前进/后退时重置本局统计，跳过的音符不计 Miss。
- `get_practice_loop()` / `set_practice_loop_start()` / `set_practice_loop_end()` / `clear_practice_loop()`：读取或设置练习循环区间；循环播放时会自动回到起点并重置本段统计。
- `reset_timing_offset()`：将全局时序偏移恢复为 0 ms。
- `get_timing_calibration_state()` / `start_timing_calibration()` / `cancel_timing_calibration()`：运行或取消本地自动延迟校准；完成后自动保存全局偏移。
- `preview_library_entry(index)` / `stop_preview()` / `toggle_preview_pause()` / `seek_preview_seconds(position_sec)`：控制曲库完整试听；不会开始游戏。
- `cycle_preview_mode()` / `get_preview_mode()`：在播放一首、单曲循环、列表播放、列表循环之间切换。
- `get_replay_info()` / `start_replay()` / `stop_replay()`：读取并播放当前谱面最近一局的本地回放；回放不刷新最佳成绩。

## 事件信号

- `chart_loaded(metadata)`：谱面载入完成。
- `chart_load_failed(message)`：谱面载入失败。
- `gameplay_started(metadata)`：开始一局。
- `gameplay_paused(is_paused)`：暂停状态变化。
- `judgement_made(judgement)`：Perfect/Great/Good/OK/Meh/Miss/Hold Break 结果，同时包含 `timing_error_ms`、`timing_text` 和 `health`；长键尾部使用普通 Perfect/Great/Good/OK/Meh/Miss 判定，身体断连只作为不计准确率的 Hold Break 事件。
- `note_state_changed(note_index, note)`：单个音符变为 holding、completed、missed、hold_missed 或 broken。`hold_missed` 表示头部已漏按但本体/尾部尚未结束，仍需显示；`broken` 表示已按中的长键提前松开。两者都可以重新按住剩余部分，但 `hold_broken` 会保留，尾部最高只能为 Meh。
- `progress_changed(progress, song_time_ms, duration_ms)`：播放进度变化。
- `gameplay_finished(result)`：结算完成。
- `personal_best_changed(best)`：当前谱面刷新本地最佳成绩。
- `bindings_changed(bindings)`：键位变化。
- `timing_offset_changed(offset_ms)`：播放器延迟设置变化。
- `volume_changed(volume_percent)`：音量变化。
- `hit_sounds_changed(enabled)`：判定音效开关变化。
- `fullscreen_changed(is_fullscreen)`：全屏状态变化。
- `scroll_speed_changed(speed_percent)`：下落速度变化。
- `recent_charts_changed(charts)`：最近谱面列表变化。
- `library_changed(entries)`：曲库扫描或导入完成。
- `practice_seeked(song_time_ms)`：练习跳转完成。
- `practice_loop_changed(start_ms, end_ms)`：练习循环区间变化；关闭时两个值均为负数。
- `timing_calibration_changed(state)`：自动校准进度或完成状态变化。
- `preview_changed(active, label)`：曲库试听开始或停止。
- `preview_progress_changed(position_sec, duration_sec)`：试听进度更新。
- `preview_mode_changed(mode, label)`：试听播放模式更新。
- `replay_state_changed(available, playing)`：最近回放可用性或播放状态变化。
- `health_changed(health, no_fail, failed)`：血量、练习模式或失败状态变化；按住未断连的长键身体时会缓慢恢复血量。
- `autoplay_changed(enabled)`：自动演示状态变化。

UI 可以只订阅这些信号，再把数据显示到自己的场景中。

## 换皮肤

壳子会查找 `res://skins/active_skin.tscn`；也可以通过 `project.godot` 的
`four_key_shell/skin_scene` 指定其他 `Control` 场景。皮肤根节点如果提供
`attach_shell(shell)`，启动时会收到壳子实例。需要完全接管游戏区域时，调用
`set_default_playfield_visible(false)` 即可。

默认快捷键：`Esc` 暂停/继续，`R` 重开当前谱面，`P` 回放上一局，`F11` 切换全屏。结算结果提供简单评价（SS/S/A/B/C/D/F）、早击/晚击统计和本地最佳成绩。
