extends Control

signal chart_loaded(metadata: Dictionary)
signal chart_load_failed(message: String)
signal gameplay_started(metadata: Dictionary)
signal gameplay_paused(is_paused: bool)
signal judgement_made(judgement: Dictionary)
signal note_state_changed(note_index: int, note: Dictionary)
signal progress_changed(progress: float, song_time_ms: float, duration_ms: float)
signal gameplay_finished(result: Dictionary)
signal bindings_changed(bindings: Array)
signal timing_offset_changed(offset_ms: float)
signal volume_changed(volume_percent: float)
signal fullscreen_changed(is_fullscreen: bool)
signal scroll_speed_changed(speed_percent: float)
signal recent_charts_changed(charts: Array)
signal practice_seeked(song_time_ms: float)
signal practice_loop_changed(start_ms: float, end_ms: float)
signal library_changed(entries: Array)
signal skin_loaded(path: String)
signal personal_best_changed(best: Dictionary)
signal hit_sounds_changed(enabled: bool)
signal timing_calibration_changed(state: Dictionary)
signal replay_state_changed(available: bool, playing: bool)
signal preview_changed(active: bool, label: String)
signal preview_progress_changed(position_sec: float, duration_sec: float)
signal preview_mode_changed(mode: int, label: String)
signal health_changed(health: float, no_fail: bool, failed: bool)

const LANE_COUNT := 4
const HIT_LINE_Y := 585.0
const SPAWN_Y := 205.0
const DEFAULT_OVERALL_DIFFICULTY := 5.0
const MAX_HEALTH := 100.0
const PERFECT_WINDOW_MS := 16.0
const GREAT_WINDOW_MS := 49.0
const GOOD_WINDOW_MS := 82.0
const OK_WINDOW_MS := 112.0
const MEH_WINDOW_MS := 136.0
const HOLD_RELEASE_WINDOW_MS := 120.0
const LANE_WIDTH := 150.0
const DEFAULT_APPROACH_MS := 1800.0
const CONFIG_PATH := "user://four_key_shell.cfg"
const REPLAY_PATH := "user://last_replay.cfg"
const CALIBRATION_BEAT_MS := 500.0
const CALIBRATION_TAPS_REQUIRED := 8
const PREVIEW_MODE_SINGLE := 0
const PREVIEW_MODE_SINGLE_LOOP := 1
const PREVIEW_MODE_PLAYLIST := 2
const PREVIEW_MODE_PLAYLIST_LOOP := 3

var notes: Array = []
var audio_player: AudioStreamPlayer
var hit_sound_player: AudioStreamPlayer
var hit_sound_players: Array[AudioStreamPlayer] = []
var hit_sound_cursor := 0
var hit_sound_streams: Dictionary = {}
var calibration_player: AudioStreamPlayer
var preview_player: AudioStreamPlayer
var preview_active := false
var preview_paused := false
var preview_entry_index := -1
var preview_mode := PREVIEW_MODE_SINGLE
var song_title := "未载入谱面"
var song_artist := ""
var song_version := ""
var chart_source_path := ""
var playing := false
var paused := false
var audio_started := false
var audio_finished := false
var approach_ms := DEFAULT_APPROACH_MS
var scroll_speed_percent := 100.0
var overall_difficulty := DEFAULT_OVERALL_DIFFICULTY
var timing_points: Array[Dictionary] = []
var perfect_window_ms := PERFECT_WINDOW_MS
var great_window_ms := GREAT_WINDOW_MS
var good_window_ms := GOOD_WINDOW_MS
var ok_window_ms := OK_WINDOW_MS
var meh_window_ms := MEH_WINDOW_MS
var miss_window_ms := MEH_WINDOW_MS
var hold_release_window_ms := HOLD_RELEASE_WINDOW_MS
var song_clock_ms := -DEFAULT_APPROACH_MS
var chart_end_ms := 0.0
var score := 0
var combo := 0
var best_combo := 0
var accuracy_points := 0.0
var accuracy_total := 0.0
var judgement_counts := {"Perfect": 0, "Great": 0, "Good": 0, "OK": 0, "Meh": 0, "Miss": 0, "Hold OK": 0, "Hold Break": 0}
var last_judgement := ""
var last_timing_error_ms := 0.0
var early_hit_count := 0
var late_hit_count := 0
var practice_loop_start_ms := -1.0
var practice_loop_end_ms := -1.0
var key_labels := ["D", "F", "J", "K"]
var key_codes := [KEY_D, KEY_F, KEY_J, KEY_K]
var lane_down := [false, false, false, false]
var capture_lane := -1
var global_offset_ms := 0.0
var volume_percent := 100.0
var hit_sounds_enabled := true
var calibration_active := false
var calibration_was_playing := false
var calibration_was_paused := false
var calibration_last_beat := -1
var calibration_tap_errors: Array[float] = []
var replay_events: Array[Dictionary] = []
var last_replay_events: Array[Dictionary] = []
var last_replay_path := ""
var replay_playing := false
var replay_cursor := 0
var last_replay_offset_ms := 0.0
var practice_run := false
var replay_complete_available := false
var run_offset_ms := 0.0
var health := MAX_HEALTH
var no_fail_mode := true
var failed := false
var finish_queued := false
var recent_charts: Array[String] = []
var recent_path_override := ""
var library_entries: Array[Dictionary] = []
var personal_best_entries: Array[Dictionary] = []
var import_dialog_mode := false

var title_label: Label
var help_label: Label
var status_label: Label
var score_label: Label
var judgement_label: Label
var pause_label: Label
var result_label: Label
var timing_label: Label
var chart_selector: OptionButton
var progress_bar: ProgressBar
var default_ui_root: Control
var skin_root: Control
var default_playfield_visible := true
var file_dialog: FileDialog
var file_dialog_dir := ""
var key_buttons: Array[Button] = []
var chart_candidates: Array[Dictionary] = []

func _ready() -> void:
	_ensure_window_geometry()
	_load_settings()
	_recalculate_timing_windows()
	load_replay(REPLAY_PATH)
	_build_ui()
	audio_player = AudioStreamPlayer.new()
	audio_player.finished.connect(_on_audio_finished)
	add_child(audio_player)
	audio_player.volume_db = linear_to_db(maxf(volume_percent / 100.0, 0.0001))
	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.volume_db = linear_to_db(maxf(volume_percent / 100.0, 0.0001)) - 10.0
	add_child(hit_sound_player)
	# A single player cuts off the previous judgement sound when a chord is
	# judged in the same frame. Keep a small pool so simultaneous lanes remain
	# audible without changing the public shell API.
	hit_sound_players = [hit_sound_player]
	for _i in 7:
		var extra_hit_sound := AudioStreamPlayer.new()
		extra_hit_sound.volume_db = hit_sound_player.volume_db
		add_child(extra_hit_sound)
		hit_sound_players.append(extra_hit_sound)
	hit_sound_streams = {
		"Perfect": _make_hit_sound(1050.0),
		"Great": _make_hit_sound(850.0),
		"Good": _make_hit_sound(650.0),
		"OK": _make_hit_sound(480.0),
		"Meh": _make_hit_sound(340.0),
		"Hold OK": _make_hit_sound(760.0),
		"Hold Break": _make_hit_sound(240.0),
	}
	calibration_player = AudioStreamPlayer.new()
	calibration_player.stream = _make_calibration_track()
	calibration_player.finished.connect(cancel_timing_calibration)
	add_child(calibration_player)
	preview_player = AudioStreamPlayer.new()
	preview_player.finished.connect(_on_preview_finished)
	add_child(preview_player)
	set_audio_levels()
	get_window().files_dropped.connect(_on_files_dropped)
	scan_library()
	_load_skin()
	if "--demo-chart" in OS.get_cmdline_args() or "--demo-chart" in OS.get_cmdline_user_args():
		call_deferred("_load_path", ProjectSettings.globalize_path("res://Songs/River-AI-SR1.4.osz"))
	call_deferred("_ensure_window_geometry")
	queue_redraw()

func _ensure_window_geometry() -> void:
	var app_window := get_window()
	if app_window.size.x < 600 or app_window.size.y < 400:
		app_window.size = Vector2i(1100, 700)
	var usable := DisplayServer.screen_get_usable_rect()
	var max_position := usable.end - app_window.size
	if app_window.position.x < usable.position.x or app_window.position.y < usable.position.y or app_window.position.x > max_position.x or app_window.position.y > max_position.y:
		app_window.position = usable.position + Vector2i(30, 30)

# Public shell API: a replacement UI can call these without touching gameplay code.
func load_chart_file(path: String) -> void:
	_load_chart(path)

func load_chart_package(path: String) -> void:
	_load_osz(path)

func load_path(path: String) -> void:
	_load_path(path)

func open_file_dialog() -> void:
	import_dialog_mode = false
	_open_dialog()

func open_import_dialog() -> void:
	import_dialog_mode = true
	_open_dialog()

func get_chart_candidates() -> Array:
	return chart_candidates.duplicate(true)

func select_chart(index: int) -> void:
	_on_chart_selected(index)

func set_default_playfield_visible(visible: bool) -> void:
	default_playfield_visible = visible
	queue_redraw()

func pause_game() -> void:
	if playing and not paused:
		_toggle_pause()

func resume_game() -> void:
	if playing and paused:
		_toggle_pause()

func retry_run() -> void:
	_retry()

func get_chart_metadata() -> Dictionary:
	var hold_count := 0
	for note in notes:
		if int(note.end) > int(note.time):
			hold_count += 1
	return {
		"title": song_title,
		"artist": song_artist,
		"version": song_version,
		"overall_difficulty": overall_difficulty,
		"timing_windows_ms": {
			"Perfect": perfect_window_ms,
			"Great": great_window_ms,
			"Good": good_window_ms,
			"OK": ok_window_ms,
			"Meh": meh_window_ms,
			"Miss": miss_window_ms,
		},
		"source_path": chart_source_path,
		"note_count": notes.size(),
		"hold_count": hold_count,
		"duration_ms": chart_end_ms,
		"timing_points": timing_points.duplicate(true),
		"bpm": _initial_bpm(),
	}

func _initial_bpm() -> float:
	for point in timing_points:
		var beat_length := float(point.get("beat_length", 0.0))
		if beat_length > 0.0:
			return 60000.0 / beat_length
	return 0.0

func get_gameplay_snapshot() -> Dictionary:
	var public_notes: Array = []
	for note in notes:
		public_notes.append(note.duplicate())
	return {
		"playing": playing,
		"paused": paused,
		"score": score,
		"combo": combo,
		"best_combo": best_combo,
		"accuracy": _accuracy_percent(),
		"grade": _grade_for_accuracy(_accuracy_percent()),
		"health": health,
		"no_fail": no_fail_mode,
		"failed": failed,
		"last_timing_error_ms": last_timing_error_ms,
		"early_hits": early_hit_count,
		"late_hits": late_hit_count,
		"song_time_ms": _song_time_ms(),
		"notes": public_notes,
		"replay_playing": replay_playing,
		"practice": practice_run,
	}

func get_personal_best() -> Dictionary:
	for entry in personal_best_entries:
		if str(entry.get("path", "")) == chart_source_path:
			return entry.duplicate(true)
	return {}

func get_personal_bests() -> Array:
	return personal_best_entries.duplicate(true)

func get_lane_bindings() -> Array:
	return key_labels.duplicate()

func set_lane_keycode(lane: int, keycode: int) -> bool:
	var duplicate_lane := key_codes.find(keycode)
	if lane < 0 or lane >= LANE_COUNT or (duplicate_lane >= 0 and duplicate_lane != lane):
		return false
	key_codes[lane] = keycode
	key_labels[lane] = OS.get_keycode_string(keycode)
	if key_buttons.size() == LANE_COUNT:
		key_buttons[lane].text = "轨道 %d：%s" % [lane + 1, key_labels[lane]]
	_save_settings()
	bindings_changed.emit(get_lane_bindings())
	queue_redraw()
	return true

func begin_key_rebind(lane: int) -> bool:
	if lane < 0 or lane >= LANE_COUNT:
		return false
	capture_lane = lane
	if key_buttons.size() == LANE_COUNT:
		key_buttons[lane].text = "轨道 %d：请按键…" % (lane + 1)
	_set_status("正在修改轨道 %d 的键位，按下任意键确认，Esc 取消" % (lane + 1))
	return true

func cancel_key_rebind() -> void:
	_cancel_rebind()

func reset_lane_bindings() -> void:
	key_codes = [KEY_D, KEY_F, KEY_J, KEY_K]
	key_labels = ["D", "F", "J", "K"]
	_save_settings()
	bindings_changed.emit(get_lane_bindings())
	queue_redraw()

func get_volume_percent() -> float:
	return volume_percent

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	if audio_player != null:
		audio_player.volume_db = linear_to_db(maxf(volume_percent / 100.0, 0.0001))
	var hit_level := linear_to_db(maxf(volume_percent / 100.0, 0.0001)) - 10.0
	for player in hit_sound_players:
		if player != null:
			player.volume_db = hit_level
	set_audio_levels()
	_save_settings()
	volume_changed.emit(volume_percent)

func set_audio_levels() -> void:
	var level := linear_to_db(maxf(volume_percent / 100.0, 0.0001))
	if calibration_player != null:
		calibration_player.volume_db = level - 6.0
	if preview_player != null:
		preview_player.volume_db = level

func get_hit_sounds_enabled() -> bool:
	return hit_sounds_enabled

func set_hit_sounds_enabled(enabled: bool) -> void:
	hit_sounds_enabled = enabled
	_save_settings()
	hit_sounds_changed.emit(hit_sounds_enabled)

func get_no_fail_mode() -> bool:
	return no_fail_mode

func set_no_fail_mode(enabled: bool) -> void:
	no_fail_mode = enabled
	_save_settings()
	health_changed.emit(health, no_fail_mode, failed)

func get_health() -> float:
	return health

func get_timing_calibration_state() -> Dictionary:
	return {
		"active": calibration_active,
		"tap_count": calibration_tap_errors.size(),
		"required_taps": CALIBRATION_TAPS_REQUIRED,
		"last_average_error_ms": _calibration_average_error(),
		"offset_ms": global_offset_ms,
	}

func start_timing_calibration() -> bool:
	if calibration_active:
		return false
	if volume_percent <= 0.0:
		_set_status("请先提高音量，再进行校准", true)
		return false
	stop_preview()
	cancel_key_rebind()
	calibration_was_playing = playing
	calibration_was_paused = paused
	if playing and not paused:
		pause_game()
	calibration_active = true
	calibration_last_beat = -1
	calibration_tap_errors.clear()
	calibration_player.play()
	_set_status("跟拍校准：先听两拍，再跟着节拍按键 %d 次（Esc 取消）" % CALIBRATION_TAPS_REQUIRED)
	timing_calibration_changed.emit(get_timing_calibration_state())
	return true

func cancel_timing_calibration() -> void:
	if not calibration_active:
		return
	_finish_timing_calibration(false)

func get_replay_info() -> Dictionary:
	return {
		"available": replay_complete_available and last_replay_path == chart_source_path,
		"event_count": last_replay_events.size(),
		"path": last_replay_path,
		"playing": replay_playing,
	}

func save_replay(path := REPLAY_PATH) -> bool:
	if not replay_complete_available:
		return false
	var config := ConfigFile.new()
	config.set_value("replay", "chart_path", last_replay_path)
	config.set_value("replay", "offset_ms", last_replay_offset_ms)
	config.set_value("replay", "events", last_replay_events)
	return config.save(path) == OK

func load_replay(path := REPLAY_PATH) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	last_replay_path = str(config.get_value("replay", "chart_path", ""))
	last_replay_offset_ms = float(config.get_value("replay", "offset_ms", 0.0))
	last_replay_events.clear()
	for event in config.get_value("replay", "events", []):
		last_replay_events.append(event)
	replay_complete_available = last_replay_path != ""
	replay_state_changed.emit(replay_complete_available and last_replay_path == chart_source_path, replay_playing)
	return replay_complete_available

func start_replay() -> bool:
	if not replay_complete_available or last_replay_path != chart_source_path or notes.is_empty() or calibration_active:
		return false
	stop_preview()
	clear_practice_loop()
	practice_run = false
	replay_playing = true
	replay_cursor = 0
	replay_events.clear()
	run_offset_ms = global_offset_ms - last_replay_offset_ms
	_reset_run_state()
	replay_state_changed.emit(true, true)
	return true

func stop_replay() -> void:
	if not replay_playing:
		return
	replay_playing = false
	replay_cursor = 0
	playing = false
	paused = false
	audio_player.stop()
	lane_down = [false, false, false, false]
	gameplay_paused.emit(false)
	replay_state_changed.emit(replay_complete_available and last_replay_path == chart_source_path, false)

func toggle_fullscreen() -> bool:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	fullscreen_changed.emit(window.mode == Window.MODE_FULLSCREEN)
	return window.mode == Window.MODE_FULLSCREEN

func get_scroll_speed_percent() -> float:
	return scroll_speed_percent

func set_scroll_speed_percent(value: float) -> void:
	scroll_speed_percent = clampf(value, 50.0, 200.0)
	approach_ms = DEFAULT_APPROACH_MS * 100.0 / scroll_speed_percent
	_save_settings()
	scroll_speed_changed.emit(scroll_speed_percent)
	queue_redraw()

func get_recent_charts() -> Array:
	return recent_charts.duplicate()

func clear_recent_charts() -> void:
	recent_charts.clear()
	_save_settings()
	recent_charts_changed.emit(get_recent_charts())

func get_library_entries() -> Array:
	return library_entries.duplicate(true)

func scan_library() -> void:
	library_entries.clear()
	for root in _library_roots():
		_collect_library_files(root, library_entries)
	library_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("label", "")).naturalnocasecmp_to(str(b.get("label", ""))) < 0)
	library_changed.emit(get_library_entries())

func import_chart_to_library(path: String) -> bool:
	var lower := path.to_lower()
	if not lower.ends_with(".osu") and not lower.ends_with(".osz"):
		_set_status("曲库只接受 .osu 或 .osz", true)
		return false
	var root := _writable_library_root()
	if root == "":
		_set_status("无法创建用户曲库目录", true)
		return false
	var folder := root.path_join(path.get_file().get_basename().validate_filename())
	DirAccess.make_dir_recursive_absolute(folder)
	var target := folder.path_join(path.get_file().get_file())
	if lower.ends_with(".osz"):
		if not _copy_file(path, target):
			_set_status("无法复制谱面包到曲库", true)
			return false
	else:
		var source_file := FileAccess.open(path, FileAccess.READ)
		if source_file == null:
			_set_status("无法读取谱面文件", true)
			return false
		var chart_text := source_file.get_as_text()
		source_file.close()
		var parsed := _parse_osu(chart_text)
		if parsed.mode != 3 or parsed.keys != 4:
			_set_status("只支持 osu!mania 4K 谱面", true)
			return false
		var source_audio := path.get_base_dir().path_join(str(parsed.audio_filename).replace("\\", "/"))
		if not FileAccess.file_exists(source_audio):
			_set_status("谱面引用的音频不存在：" + str(parsed.audio_filename), true)
			return false
		var target_audio := folder.path_join(str(parsed.audio_filename).replace("\\", "/"))
		DirAccess.make_dir_recursive_absolute(target_audio.get_base_dir())
		if not _copy_file(source_audio, target_audio) or not _copy_file(path, target):
			_set_status("无法复制谱面或音频到曲库", true)
			return false
	scan_library()
	_set_status("已加入曲库：" + path.get_file())
	_load_path(target)
	return true

func load_library_entry(index: int) -> void:
	if index >= 0 and index < library_entries.size():
		_load_path(str(library_entries[index].get("path", "")))

func preview_library_entry(index: int) -> bool:
	if index < 0 or index >= library_entries.size() or calibration_active:
		return false
	return _start_preview_entry(index)

func stop_preview() -> void:
	if preview_player == null or not preview_active:
		return
	preview_player.stop()
	preview_active = false
	preview_paused = false
	preview_entry_index = -1
	preview_player.stream = null
	preview_changed.emit(false, "")
	preview_progress_changed.emit(0.0, 0.0)

func get_preview_state() -> Dictionary:
	var duration := preview_player.stream.get_length() if preview_player != null and preview_player.stream != null else 0.0
	var position := preview_player.get_playback_position() if preview_active else 0.0
	return {
		"active": preview_active,
		"paused": preview_paused,
		"position_sec": position,
		"duration_sec": duration,
		"entry_index": preview_entry_index,
		"mode": preview_mode,
		"mode_label": _preview_mode_label(),
	}

func toggle_preview_pause() -> bool:
	if not preview_active or preview_player == null:
		return false
	preview_paused = not preview_paused
	preview_player.stream_paused = preview_paused
	return true

func seek_preview_seconds(position_sec: float) -> void:
	if not preview_active or preview_player == null or preview_player.stream == null:
		return
	preview_player.seek(clampf(position_sec, 0.0, preview_player.stream.get_length()))
	preview_progress_changed.emit(preview_player.get_playback_position(), preview_player.stream.get_length())

func cycle_preview_mode() -> int:
	preview_mode = (preview_mode + 1) % 4
	preview_mode_changed.emit(preview_mode, _preview_mode_label())
	return preview_mode

func get_preview_mode() -> Dictionary:
	return {"mode": preview_mode, "label": _preview_mode_label()}

func _start_preview_entry(index: int) -> bool:
	if index < 0 or index >= library_entries.size():
		return false
	var entry := library_entries[index]
	var stream := _preview_stream_for_entry(entry)
	if stream == null:
		_set_status("无法试听：音频不存在或格式不支持", true)
		return false
	pause_game()
	preview_player.stop()
	preview_player.stream = stream
	preview_player.stream_paused = false
	var start_sec := clampf(float(entry.get("preview_ms", 0.0)) / 1000.0, 0.0, maxf(0.0, stream.get_length() - 0.05))
	preview_player.play(start_sec)
	preview_active = true
	preview_paused = false
	preview_entry_index = index
	preview_changed.emit(true, str(entry.get("label", "")))
	preview_mode_changed.emit(preview_mode, _preview_mode_label())
	preview_progress_changed.emit(start_sec, stream.get_length())
	return true

func _preview_stream_for_entry(entry: Dictionary) -> AudioStream:
	var stream: AudioStream
	if str(entry.get("package_path", "")) != "":
		var reader := ZIPReader.new()
		if reader.open(str(entry.package_path)) != OK:
			return null
		var audio_name := str(entry.audio_path)
		if reader.get_files().has(audio_name):
			stream = _load_audio_buffer(audio_name, reader.read_file(audio_name))
		reader.close()
	else:
		stream = _load_audio(str(entry.get("audio_path", "")))
	return stream

func _on_preview_finished() -> void:
	if not preview_active:
		return
	if preview_mode == PREVIEW_MODE_SINGLE_LOOP:
		_start_preview_entry(preview_entry_index)
		return
	if preview_mode == PREVIEW_MODE_PLAYLIST or preview_mode == PREVIEW_MODE_PLAYLIST_LOOP:
		var next_index := preview_entry_index + 1
		if next_index >= library_entries.size():
			if preview_mode == PREVIEW_MODE_PLAYLIST_LOOP:
				next_index = 0
			else:
				stop_preview()
				return
		if _start_preview_entry(next_index):
			return
	stop_preview()

func _preview_mode_label() -> String:
	match preview_mode:
		PREVIEW_MODE_SINGLE_LOOP:
			return "单曲循环"
		PREVIEW_MODE_PLAYLIST:
			return "列表播放"
		PREVIEW_MODE_PLAYLIST_LOOP:
			return "列表循环"
		_:
			return "播放一首"

func seek_practice_ms(delta_ms: float) -> void:
	if not playing or notes.is_empty() or audio_player == null or audio_player.stream == null:
		return
	var target := clampf(_song_time_ms() + delta_ms, 0.0, chart_end_ms)
	_seek_practice_absolute(target)

func get_practice_loop() -> Dictionary:
	return {"start_ms": practice_loop_start_ms, "end_ms": practice_loop_end_ms}

func set_practice_loop_start() -> void:
	if chart_end_ms <= 0.0:
		return
	practice_loop_start_ms = clampf(_song_time_ms(), 0.0, chart_end_ms)
	if practice_loop_end_ms >= 0.0 and practice_loop_end_ms <= practice_loop_start_ms:
		practice_loop_end_ms = -1.0
	practice_loop_changed.emit(practice_loop_start_ms, practice_loop_end_ms)

func set_practice_loop_end() -> void:
	if chart_end_ms <= 0.0:
		return
	practice_loop_end_ms = clampf(_song_time_ms(), 0.0, chart_end_ms)
	if practice_loop_start_ms < 0.0 or practice_loop_start_ms >= practice_loop_end_ms:
		practice_loop_start_ms = maxf(0.0, practice_loop_end_ms - 10000.0)
	practice_loop_changed.emit(practice_loop_start_ms, practice_loop_end_ms)

func clear_practice_loop() -> void:
	practice_loop_start_ms = -1.0
	practice_loop_end_ms = -1.0
	practice_loop_changed.emit(practice_loop_start_ms, practice_loop_end_ms)

func _seek_practice_absolute(target: float) -> void:
	if replay_playing:
		return
	practice_run = true
	run_offset_ms = 0.0
	replay_events.clear()
	for i in notes.size():
		var note: Dictionary = notes[i]
		note.state = "skipped" if float(note.time) < target else "pending"
		note.hold_broken = false
		note.head_error_ms = 0.0
		note.tail_error_ms = 0.0
		notes[i] = note
	score = 0
	combo = 0
	best_combo = 0
	accuracy_points = 0.0
	accuracy_total = 0.0
	judgement_counts = {"Perfect": 0, "Great": 0, "Good": 0, "OK": 0, "Meh": 0, "Miss": 0, "Hold OK": 0, "Hold Break": 0}
	last_judgement = ""
	last_timing_error_ms = 0.0
	early_hit_count = 0
	late_hit_count = 0
	health = MAX_HEALTH
	failed = false
	finish_queued = false
	lane_down = [false, false, false, false]
	playing = true
	paused = false
	audio_started = true
	audio_finished = false
	song_clock_ms = target - global_offset_ms
	pause_label.visible = false
	result_label.visible = false
	audio_player.stream_paused = false
	# `target` is the actual position in the chart.  Do not feed the
	# user-facing timing offset back into the audio seek position.
	audio_player.play(maxf(target / 1000.0, 0.0))
	gameplay_started.emit(get_chart_metadata())
	_update_progress()
	practice_seeked.emit(target)
	queue_redraw()

func reset_timing_offset() -> void:
	global_offset_ms = 0.0
	_save_settings()
	_update_timing_label()
	_set_status("全局延迟已归零")
	timing_offset_changed.emit(global_offset_ms)

func _build_ui() -> void:
	default_ui_root = Control.new()
	default_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(default_ui_root)

	var background := ColorRect.new()
	background.color = Color("101522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	default_ui_root.add_child(background)

	title_label = Label.new()
	title_label.position = Vector2(30, 20)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.text = "Four Key Shell — " + song_title
	default_ui_root.add_child(title_label)

	help_label = Label.new()
	help_label.position = Vector2(30, 60)
	help_label.text = "拖入完整 4K .osu/.osz 或点击“打开谱面”。默认键位：D F J K"
	help_label.add_theme_color_override("font_color", Color("aab6cc"))
	default_ui_root.add_child(help_label)

	var open_button := Button.new()
	open_button.text = "打开谱面"
	open_button.position = Vector2(30, 95)
	open_button.size = Vector2(130, 38)
	open_button.pressed.connect(_open_dialog)
	default_ui_root.add_child(open_button)

	var pause_button := Button.new()
	pause_button.text = "暂停 / 继续"
	pause_button.position = Vector2(170, 95)
	pause_button.size = Vector2(130, 38)
	pause_button.pressed.connect(_toggle_pause)
	default_ui_root.add_child(pause_button)

	var retry_button := Button.new()
	retry_button.text = "重试"
	retry_button.position = Vector2(310, 95)
	retry_button.size = Vector2(90, 38)
	retry_button.pressed.connect(_retry)
	default_ui_root.add_child(retry_button)

	for lane in LANE_COUNT:
		var key_button := Button.new()
		key_button.text = "轨道 %d：%s" % [lane + 1, key_labels[lane]]
		key_button.position = Vector2(30 + lane * 105, 145)
		key_button.size = Vector2(95, 30)
		key_button.pressed.connect(_begin_rebind.bind(lane, key_button))
		key_buttons.append(key_button)
		default_ui_root.add_child(key_button)

	status_label = Label.new()
	status_label.position = Vector2(430, 103)
	status_label.text = "请导入一个 4K .osu 谱面"
	status_label.add_theme_color_override("font_color", Color("8ee6b2"))
	default_ui_root.add_child(status_label)

	var offset_minus_button := Button.new()
	offset_minus_button.text = "−5 ms"
	offset_minus_button.position = Vector2(430, 145)
	offset_minus_button.size = Vector2(75, 30)
	offset_minus_button.pressed.connect(_adjust_offset.bind(-5.0))
	default_ui_root.add_child(offset_minus_button)

	var offset_plus_button := Button.new()
	offset_plus_button.text = "+5 ms"
	offset_plus_button.position = Vector2(510, 145)
	offset_plus_button.size = Vector2(75, 30)
	offset_plus_button.pressed.connect(_adjust_offset.bind(5.0))
	default_ui_root.add_child(offset_plus_button)

	timing_label = Label.new()
	timing_label.position = Vector2(595, 149)
	timing_label.size = Vector2(160, 24)
	timing_label.add_theme_color_override("font_color", Color("aab6cc"))
	default_ui_root.add_child(timing_label)

	chart_selector = OptionButton.new()
	chart_selector.position = Vector2(770, 145)
	chart_selector.size = Vector2(190, 30)
	chart_selector.visible = false
	chart_selector.item_selected.connect(_on_chart_selected)
	default_ui_root.add_child(chart_selector)

	var speed_label := Label.new()
	speed_label.position = Vector2(595, 177)
	speed_label.text = "速度"
	speed_label.add_theme_color_override("font_color", Color("aab6cc"))
	default_ui_root.add_child(speed_label)
	var speed_slider := HSlider.new()
	speed_slider.position = Vector2(635, 175)
	speed_slider.size = Vector2(125, 24)
	speed_slider.min_value = 50.0
	speed_slider.max_value = 200.0
	speed_slider.step = 5.0
	speed_slider.value = scroll_speed_percent
	speed_slider.tooltip_text = "下落速度百分比"
	speed_slider.value_changed.connect(set_scroll_speed_percent)
	default_ui_root.add_child(speed_slider)

	judgement_label = Label.new()
	judgement_label.position = Vector2(720, 103)
	judgement_label.add_theme_font_size_override("font_size", 18)
	judgement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgement_label.size = Vector2(180, 36)
	default_ui_root.add_child(judgement_label)

	score_label = Label.new()
	score_label.position = Vector2(900, 20)
	score_label.add_theme_font_size_override("font_size", 16)
	default_ui_root.add_child(score_label)

	pause_label = Label.new()
	pause_label.position = Vector2(420, 320)
	pause_label.size = Vector2(260, 100)
	pause_label.add_theme_font_size_override("font_size", 28)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.text = "已暂停\n按 Esc 继续"
	pause_label.visible = false
	default_ui_root.add_child(pause_label)

	result_label = Label.new()
	result_label.position = Vector2(360, 275)
	result_label.size = Vector2(380, 180)
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.visible = false
	default_ui_root.add_child(result_label)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.osu,*.osz ; osu!mania chart or package"])
	file_dialog.current_dir = _get_file_dialog_dir()
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(30, 665)
	progress_bar.size = Vector2(1040, 18)
	progress_bar.show_percentage = false
	progress_bar.value = 0.0
	default_ui_root.add_child(progress_bar)

	var volume_label := Label.new()
	volume_label.position = Vector2(790, 149)
	volume_label.text = "音量"
	volume_label.add_theme_color_override("font_color", Color("aab6cc"))
	default_ui_root.add_child(volume_label)
	var volume_slider := HSlider.new()
	volume_slider.position = Vector2(830, 147)
	volume_slider.size = Vector2(125, 24)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = volume_percent
	volume_slider.tooltip_text = "音量"
	volume_slider.value_changed.connect(set_volume_percent)
	default_ui_root.add_child(volume_slider)
	_update_score_text()
	_update_timing_label()

func _load_skin() -> void:
	var configured_path := str(ProjectSettings.get_setting("four_key_shell/skin_scene", "res://skins/active_skin.tscn"))
	if not ResourceLoader.exists(configured_path):
		return
	var packed_skin := load(configured_path) as PackedScene
	if packed_skin == null:
		return
	var instance := packed_skin.instantiate()
	if not instance is Control:
		instance.queue_free()
		return
	skin_root = instance as Control
	skin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(skin_root)
	default_ui_root.visible = false
	if skin_root.has_method("attach_shell"):
		skin_root.call("attach_shell", self)
	skin_loaded.emit(configured_path)

func _process(delta: float) -> void:
	if preview_active and preview_player != null and preview_player.stream != null:
		preview_progress_changed.emit(preview_player.get_playback_position(), preview_player.stream.get_length())
	if not playing or paused:
		return
	if audio_started and not audio_finished:
		_sync_song_clock()
	else:
		song_clock_ms += delta * 1000.0
	if not audio_started and song_clock_ms >= 0.0:
		audio_player.play()
		audio_started = true
		audio_finished = false
	if replay_playing:
		_process_replay_events(_song_time_ms())
	_update_note_states()
	if practice_loop_start_ms >= 0.0 and practice_loop_end_ms > practice_loop_start_ms and _song_time_ms() >= practice_loop_end_ms:
		_seek_practice_absolute(practice_loop_start_ms)
		return
	if audio_finished and _song_time_ms() >= chart_end_ms + hold_release_window_ms:
		_finish_play()
		return
	_update_score_text()
	_update_progress()
	queue_redraw()

func _sync_song_clock() -> void:
	if audio_started and not audio_finished and audio_player.playing and not paused:
		# Playback position is measured before the output device latency. Follow
		# the time heard by the player so timing stays consistent across devices.
		var playback_ms := (audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) * 1000.0
		song_clock_ms = maxf(song_clock_ms, playback_ms)

func _process_replay_events(now_ms: float) -> void:
	while replay_cursor < last_replay_events.size():
		var event: Dictionary = last_replay_events[replay_cursor]
		if float(event.get("time_ms", 0.0)) + run_offset_ms > now_ms:
			break
		var lane := int(event.get("lane", -1))
		if lane >= 0 and lane < LANE_COUNT:
			var event_time := float(event.get("time_ms", 0.0)) + run_offset_ms
			if bool(event.get("down", false)):
				lane_down[lane] = true
				_judge_lane_down(lane, event_time)
			else:
				lane_down[lane] = false
				_judge_lane_up(lane, event_time)
		replay_cursor += 1

func _record_calibration_tap(elapsed := -1.0) -> void:
	if elapsed < 0.0:
		elapsed = (calibration_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) * 1000.0
	var beat_index := int(round(elapsed / CALIBRATION_BEAT_MS))
	# The first two clicks are a count-in. One keypress is accepted per beat.
	if beat_index < 3 or beat_index <= calibration_last_beat:
		return
	calibration_last_beat = beat_index
	var target := beat_index * CALIBRATION_BEAT_MS
	calibration_tap_errors.append(elapsed - target)
	timing_calibration_changed.emit(get_timing_calibration_state())
	if calibration_tap_errors.size() >= CALIBRATION_TAPS_REQUIRED:
		_finish_timing_calibration(true)

func _calibration_average_error() -> float:
	if calibration_tap_errors.is_empty():
		return 0.0
	var total := 0.0
	for error_ms in calibration_tap_errors:
		total += error_ms
	return total / calibration_tap_errors.size()

func _finish_timing_calibration(apply_offset: bool) -> void:
	var requested_apply := apply_offset
	var average := _calibration_average_error()
	calibration_active = false
	calibration_player.stop()
	var spread := 0.0
	for error_ms in calibration_tap_errors:
		spread += pow(error_ms - average, 2.0)
	if not calibration_tap_errors.is_empty():
		spread = sqrt(spread / calibration_tap_errors.size())
	apply_offset = apply_offset and spread <= 60.0
	if apply_offset:
		global_offset_ms = clampf(-average, -250.0, 250.0)
		if playing:
			practice_run = true
		_save_settings()
		_update_timing_label()
		timing_offset_changed.emit(global_offset_ms)
		_set_status("跟拍校准完成：偏移 %+.1f ms（包含跟拍误差，可手动微调）" % global_offset_ms)
	else:
		if requested_apply and spread > 60.0:
			_set_status("跟拍不稳定（标准差 %.1f ms），未修改偏移；请重新校准" % spread, true)
		else:
			_set_status("已取消自动校准")
	timing_calibration_changed.emit({
		"active": false,
		"tap_count": calibration_tap_errors.size(),
		"required_taps": CALIBRATION_TAPS_REQUIRED,
		"last_average_error_ms": average,
		"applied": apply_offset,
		"offset_ms": global_offset_ms,
		"unstable": spread > 60.0,
	})
	if calibration_was_playing and not calibration_was_paused:
		resume_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_timing_calibration()
		stop_preview()
		if playing and not paused:
			_toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if calibration_active:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				cancel_timing_calibration()
			else:
				_record_calibration_tap()
		get_viewport().set_input_as_handled()
		return
	if capture_lane >= 0:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_cancel_rebind()
				return
			if event.keycode == KEY_F11:
				_set_status("Esc 和 F11 是系统快捷键，不能绑定到轨道", true)
				return
			var duplicate_lane := key_codes.find(event.keycode)
			if duplicate_lane >= 0 and duplicate_lane != capture_lane:
				_set_status("这个键已经绑定到轨道 %d" % (duplicate_lane + 1), true)
				return
			key_codes[capture_lane] = event.keycode
			key_labels[capture_lane] = OS.get_keycode_string(event.keycode)
			key_buttons[capture_lane].text = "轨道 %d：%s" % [capture_lane + 1, key_labels[capture_lane]]
			capture_lane = -1
			_save_settings()
			_set_status("键位已保存：" + str(key_labels))
			queue_redraw()
		return
	if event.keycode == KEY_F11 and event.pressed and not event.echo:
		toggle_fullscreen()
		return
	if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_toggle_pause()
		return
	if event.keycode == KEY_R and key_codes.find(KEY_R) < 0 and event.pressed and not event.echo and not notes.is_empty():
		_retry()
		return
	if event.keycode == KEY_P and key_codes.find(KEY_P) < 0 and event.pressed and not event.echo and not playing:
		start_replay()
		return
	var lane := key_codes.find(event.keycode)
	if lane < 0:
		return
	if event.echo:
		return
	if playing and not paused and audio_started:
		_sync_song_clock()
	if event.pressed:
		if not replay_playing and playing and not paused:
			replay_events.append({"time_ms": _song_time_ms(), "lane": lane, "down": true})
		lane_down[lane] = true
		if not paused:
			_judge_lane_down(lane)
	else:
		if not replay_playing and playing and not paused:
			replay_events.append({"time_ms": _song_time_ms(), "lane": lane, "down": false})
		lane_down[lane] = false
		if not paused:
			_judge_lane_up(lane)

func _input(event: InputEvent) -> void:
	# Gameplay keys must be captured before Controls get a chance to use them
	# for focus navigation. This matters especially for the supported arrow-key
	# bindings: a focused Button can otherwise consume Left/Up/Right/Down and a
	# hold note will miss its head even while the player is holding the key.
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	var should_capture := calibration_active or capture_lane >= 0
	if playing and key_codes.find(key_event.keycode) >= 0:
		should_capture = true
	if not should_capture:
		return
	_unhandled_key_input(key_event)
	get_viewport().set_input_as_handled()

func _open_dialog() -> void:
	file_dialog.current_dir = _get_file_dialog_dir()
	file_dialog.popup_centered_ratio(0.8)

func _on_file_selected(path: String) -> void:
	var selected_dir := path.get_base_dir()
	if selected_dir != "" and DirAccess.dir_exists_absolute(selected_dir):
		file_dialog_dir = selected_dir
		_save_settings()
	if import_dialog_mode:
		import_dialog_mode = false
		import_chart_to_library(path)
	else:
		_load_path(path)

func _get_file_dialog_dir() -> String:
	if file_dialog_dir != "" and DirAccess.dir_exists_absolute(file_dialog_dir):
		return file_dialog_dir
	var library_dir := ProjectSettings.globalize_path("user://songs")
	if DirAccess.dir_exists_absolute(library_dir):
		return library_dir
	var documents_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_dir != "" and DirAccess.dir_exists_absolute(documents_dir):
		return documents_dir
	return ProjectSettings.globalize_path("res://")

func _on_files_dropped(paths: PackedStringArray) -> void:
	if not paths.is_empty():
		_load_path(paths[0])

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("files") and data.files.size() > 0 and (str(data.files[0]).to_lower().ends_with(".osu") or str(data.files[0]).to_lower().ends_with(".osz"))

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		_load_path(str(data.files[0]))

func _load_path(path: String) -> void:
	recent_path_override = path
	chart_candidates.clear()
	chart_selector.clear()
	chart_selector.visible = false
	if path.to_lower().ends_with(".osz"):
		_load_osz(path)
	else:
		_load_chart(path)

func _load_osz(path: String) -> void:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		_set_status("无法打开 .osz 压缩包", true)
		chart_load_failed.emit("无法打开 .osz 压缩包")
		return
	# Keep extracted packages in the app's writable user data directory. System Temp
	# can be restricted by Windows policy, while user:// is guaranteed for the app.
	var import_root := ProjectSettings.globalize_path("user://imports")
	var import_error := DirAccess.make_dir_recursive_absolute(import_root)
	if import_error != OK:
		# Development sandboxes can deny the profile directory. Keep a local fallback
		# so the same build remains testable when the project folder is writable.
		import_root = ProjectSettings.globalize_path("res://.imports")
		import_error = DirAccess.make_dir_recursive_absolute(import_root)
	if import_error != OK:
		_set_status("无法创建谱面解包目录", true)
		chart_load_failed.emit("无法创建谱面解包目录")
		return
	var base := import_root.path_join(path.get_file().get_basename().validate_filename())
	DirAccess.make_dir_recursive_absolute(base)
	var osu_candidates: Array[Dictionary] = []
	for name in reader.get_files():
		if name.ends_with("/"):
			continue
		var target := base.path_join(name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var output := FileAccess.open(target, FileAccess.WRITE)
		if output == null and not import_root.ends_with(".imports"):
			# Some restricted test hosts expose user:// for reads but reject writes.
			# Retry the same package in the project-local writable directory.
			import_root = ProjectSettings.globalize_path("res://.imports")
			DirAccess.make_dir_recursive_absolute(import_root)
			base = import_root.path_join(path.get_file().get_basename().validate_filename())
			target = base.path_join(name)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			output = FileAccess.open(target, FileAccess.WRITE)
		if output == null:
			continue
		output.store_buffer(reader.read_file(name))
		output.close()
		if name.to_lower().ends_with(".osu"):
			var chart_file := FileAccess.open(target, FileAccess.READ)
			if chart_file != null:
				var chart_info := _parse_osu(chart_file.get_as_text())
				chart_file.close()
				if chart_info.mode == 3 and chart_info.keys == 4:
					osu_candidates.append({
						"path": target,
						"title": chart_info.title,
						"artist": chart_info.artist,
						"version": chart_info.version,
						"note_count": chart_info.notes.size(),
					})
	reader.close()
	if osu_candidates.is_empty():
		_set_status(".osz 中没有找到 osu!mania 4K 谱面", true)
		chart_load_failed.emit(".osz 中没有找到 osu!mania 4K 谱面")
		return
	chart_candidates = osu_candidates
	chart_selector.clear()
	for candidate in chart_candidates:
		var version_text: String = str(candidate.version)
		chart_selector.add_item(version_text if version_text != "" else "4K 谱面")
	chart_selector.select(0)
	chart_selector.visible = chart_candidates.size() > 1
	_load_chart(str(chart_candidates[0].path))

func _on_chart_selected(index: int) -> void:
	if index < 0 or index >= chart_candidates.size():
		return
	_load_chart(str(chart_candidates[index].path))

func _load_chart(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("无法读取谱面文件", true)
		chart_load_failed.emit("无法读取谱面文件")
		return
	var text := file.get_as_text()
	file.close()
	var parsed := _parse_osu(text)
	if parsed.mode != 3 or parsed.keys != 4:
		_set_status("只支持 osu!mania 4K（Mode=3，CircleSize=4）", true)
		chart_load_failed.emit("只支持 osu!mania 4K（Mode=3，CircleSize=4）")
		return
	var candidate_audio := path.get_base_dir().path_join(str(parsed.audio_filename).replace("\\", "/"))
	if not FileAccess.file_exists(candidate_audio):
		_set_status("谱面读取成功，但找不到音频：" + parsed.audio_filename, true)
		chart_load_failed.emit("找不到音频：" + parsed.audio_filename)
		return
	var stream := _load_audio(candidate_audio)
	if stream == null:
		_set_status("找到了音频，但当前格式无法播放", true)
		chart_load_failed.emit("找到了音频，但当前格式无法播放")
		return

	stop_preview()
	audio_player.stop()
	replay_playing = false
	replay_cursor = 0
	replay_events.clear()
	run_offset_ms = 0.0
	practice_run = false
	overall_difficulty = clampf(float(parsed.overall_difficulty), 0.0, 10.0)
	_recalculate_timing_windows()
	timing_points.clear()
	for point in parsed.timing_points:
		if point is Dictionary:
			timing_points.append(point)
	notes = parsed.notes
	chart_source_path = path
	replay_state_changed.emit(replay_complete_available and last_replay_path == chart_source_path, false)
	song_title = parsed.title if parsed.title != "" else path.get_file().get_basename()
	song_artist = parsed.artist
	song_version = parsed.version
	title_label.text = "Four Key Shell — " + song_title + (" [" + song_version + "]" if song_version != "" else "")
	audio_player.stream = stream
	playing = true
	paused = false
	audio_started = false
	audio_finished = false
	song_clock_ms = -approach_ms
	chart_end_ms = 0.0
	for note in notes:
		chart_end_ms = maxf(chart_end_ms, float(note.end))
	practice_loop_start_ms = -1.0
	practice_loop_end_ms = -1.0
	practice_loop_changed.emit(practice_loop_start_ms, practice_loop_end_ms)
	score = 0
	combo = 0
	best_combo = 0
	accuracy_points = 0.0
	accuracy_total = 0.0
	judgement_counts = {"Perfect": 0, "Great": 0, "Good": 0, "OK": 0, "Meh": 0, "Miss": 0, "Hold OK": 0, "Hold Break": 0}
	last_judgement = ""
	last_timing_error_ms = 0.0
	early_hit_count = 0
	late_hit_count = 0
	health = MAX_HEALTH
	failed = false
	finish_queued = false
	lane_down = [false, false, false, false]
	pause_label.visible = false
	result_label.visible = false
	_set_status("已载入：" + song_title + "  |  " + song_artist)
	_update_progress()
	_remember_chart(recent_path_override if recent_path_override != "" else path)
	recent_path_override = ""
	chart_loaded.emit(get_chart_metadata())
	gameplay_started.emit(get_chart_metadata())
	queue_redraw()

func _parse_osu(text: String) -> Dictionary:
	var section := ""
	var result := {"mode": -1, "keys": 0, "audio_filename": "", "preview_time": 0, "title": "", "artist": "", "version": "", "overall_difficulty": DEFAULT_OVERALL_DIFFICULTY, "timing_points": [], "notes": []}
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		# osu! beatmaps exported by some editors include a UTF-8 BOM on the first line.
		if line.begins_with("\uFEFF"):
			line = line.trim_prefix("\uFEFF")
		if line.begins_with("[") and line.ends_with("]"):
			section = line
			continue
		if line == "" or line.begins_with("//"):
			continue
		if section == "[General]":
			var general := line.split(":", false, 1)
			if general.size() == 2 and general[0].strip_edges() == "Mode":
				result.mode = int(general[1].strip_edges())
			if general.size() == 2 and general[0].strip_edges() == "AudioFilename":
				result.audio_filename = general[1].strip_edges()
			if general.size() == 2 and general[0].strip_edges() == "PreviewTime":
				result.preview_time = int(general[1].strip_edges())
		elif section == "[Metadata]":
			var meta := line.split(":", false, 1)
			if meta.size() == 2 and meta[0].strip_edges() == "Title":
				result.title = meta[1].strip_edges()
			if meta.size() == 2 and meta[0].strip_edges() == "Artist":
				result.artist = meta[1].strip_edges()
			if meta.size() == 2 and meta[0].strip_edges() == "Version":
				result.version = meta[1].strip_edges()
		elif section == "[Difficulty]":
			var diff := line.split(":", false, 1)
			if diff.size() == 2 and diff[0].strip_edges() == "CircleSize":
				result.keys = int(float(diff[1].strip_edges()))
			if diff.size() == 2 and diff[0].strip_edges() == "OverallDifficulty":
				result.overall_difficulty = float(diff[1].strip_edges())
		elif section == "[TimingPoints]" and line.contains(","):
			var timing := line.split(",")
			if timing.size() >= 2:
				var beat_length := float(timing[1])
				result.timing_points.append({
					"offset_ms": float(timing[0]),
					"beat_length": beat_length,
					"meter": int(timing[2]) if timing.size() > 2 else 4,
					"uninherited": int(timing[6]) if timing.size() > 6 else 1,
				})
		elif section == "[HitObjects]" and line.contains(","):
			var fields := line.split(",")
			if fields.size() < 4:
				continue
			var x := int(fields[0])
			var time := int(fields[2])
			var kind := int(fields[3])
			var end_time := time
			if kind & 128 and fields.size() >= 6:
				end_time = int(fields[5].split(":")[0])
			result.notes.append({
				"lane": clampi(int(float(x) / 512.0 * 4.0), 0, 3),
				"time": time,
				"end": maxi(end_time, time),
				"state": "pending",
				"hold_broken": false,
				"head_error_ms": 0.0,
				"tail_error_ms": 0.0,
				"hit_sound": kind >> 2 & 7,
			})
	result.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return result

func _load_audio(path: String) -> AudioStream:
	var lower := path.to_lower()
	if lower.ends_with(".mp3"):
		return AudioStreamMP3.load_from_file(path)
	if lower.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if lower.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	return null

func _song_time_ms() -> float:
	return song_clock_ms + global_offset_ms

func _recalculate_timing_windows() -> void:
	# Use the current osu!mania/Lazer timing ranges. The Perfect range is also
	# OD-dependent; keeping it fixed at 16 ms made OD 0 and OD 10 identical.
	var od := clampf(overall_difficulty, 0.0, 10.0)
	perfect_window_ms = lerpf(22.4, 13.9, od / 10.0)
	great_window_ms = maxf(16.0, 64.0 - 3.0 * od)
	good_window_ms = maxf(great_window_ms, 97.0 - 3.0 * od)
	ok_window_ms = maxf(good_window_ms, 127.0 - 3.0 * od)
	meh_window_ms = maxf(ok_window_ms, 151.0 - 3.0 * od)
	miss_window_ms = maxf(meh_window_ms, 188.0 - 3.0 * od)
	hold_release_window_ms = maxf(HOLD_RELEASE_WINDOW_MS, meh_window_ms)

func _change_health(delta: float) -> void:
	health = clampf(health + delta, 0.0, MAX_HEALTH)
	health_changed.emit(health, no_fail_mode, failed)
	if health <= 0.0 and not no_fail_mode and playing and not failed and not finish_queued:
		finish_queued = true
		call_deferred("_finish_play", true)

func _judge_lane_down(lane: int, forced_time_ms := -1.0e30) -> void:
	if not playing or paused:
		return
	var now := _song_time_ms() if forced_time_ms < -1.0e20 else forced_time_ms
	# Like osu!mania, both a missed head and an early release leave a live body
	# that can be held again. Re-pressing does not erase the original miss/break.
	for i in notes.size():
		var broken_hold: Dictionary = notes[i]
		if (broken_hold.state == "broken" or broken_hold.state == "hold_missed") and broken_hold.lane == lane and now < float(broken_hold.end):
			broken_hold.state = "holding"
			notes[i] = broken_hold
			note_state_changed.emit(i, broken_hold.duplicate())
			return
	var best_index := -1
	# A key press outside the last positive window must remain pending until
	# the normal miss point. It must not be upgraded to Meh merely because it
	# happened before the miss timeout.
	var best_distance := meh_window_ms + 1.0
	for i in notes.size():
		var note: Dictionary = notes[i]
		if note.state != "pending" or note.lane != lane:
			continue
		var distance: float = abs(float(note.time) - now)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index < 0:
		return
	var target: Dictionary = notes[best_index]
	var judgement := "Meh"
	var points := 50
	var accuracy_value := 1.0 / 6.0
	if best_distance <= perfect_window_ms:
		judgement = "Perfect"
		points = 320
		accuracy_value = 1.0
	elif best_distance <= great_window_ms:
		judgement = "Great"
		points = 300
		accuracy_value = 1.0
	elif best_distance <= good_window_ms:
		judgement = "Good"
		points = 200
		accuracy_value = 2.0 / 3.0
	elif best_distance <= ok_window_ms:
		judgement = "OK"
		points = 100
		accuracy_value = 1.0 / 3.0
	combo += 1
	best_combo = maxi(best_combo, combo)
	target.head_error_ms = now - float(target.time)
	_record_judgement(judgement, points, accuracy_value, now - float(target.time))
	if target.end > target.time:
		target.state = "holding"
	else:
		target.state = "completed"
	notes[best_index] = target
	note_state_changed.emit(best_index, target.duplicate())

func _judge_lane_up(lane: int, forced_time_ms := -1.0e30) -> void:
	if not playing or paused:
		return
	var now := _song_time_ms() if forced_time_ms < -1.0e20 else forced_time_ms
	for i in notes.size():
		var note: Dictionary = notes[i]
		if note.state != "holding" or note.lane != lane:
			continue
		if absf(now - float(note.end)) <= hold_release_window_ms:
			note.tail_error_ms = now - float(note.end)
			notes[i] = note
			_complete_hold(i)
		else:
			_break_hold(i)
		return

func _update_note_states() -> void:
	var now := _song_time_ms()
	for i in notes.size():
		var note: Dictionary = notes[i]
		if note.state == "pending" and now > float(note.time) + miss_window_ms:
			# Judgement and visual lifetime are separate: missing the head must
			# not remove the body/tail before their scheduled end.
			if float(note.end) > float(note.time):
				note.state = "hold_missed"
				note.hold_broken = true
			else:
				note.state = "missed"
			notes[i] = note
			note_state_changed.emit(i, note.duplicate())
			combo = 0
			_record_judgement("Miss", 0, 0.0)
		elif note.state == "holding" and now >= float(note.end):
			if lane_down[note.lane]:
				_complete_hold(i)
			else:
				_break_hold(i)
		elif (note.state == "hold_missed" or note.state == "broken") and now > float(note.end) + hold_release_window_ms:
			# The miss/break was already recorded; only retire the visual now.
			note.state = "missed"
			notes[i] = note
			note_state_changed.emit(i, note.duplicate())

func _complete_hold(index: int) -> void:
	var note: Dictionary = notes[index]
	if note.state != "holding":
		return
	note.state = "completed"
	notes[index] = note
	note_state_changed.emit(index, note.duplicate())
	if not bool(note.get("hold_broken", false)):
		var tail_error := absf(float(note.get("tail_error_ms", 0.0)))
		var tail_points := 50
		var tail_accuracy := 1.0 / 6.0
		if tail_error <= perfect_window_ms:
			tail_points = 100
			tail_accuracy = 1.0
		elif tail_error <= great_window_ms:
			tail_points = 90
			tail_accuracy = 1.0
		elif tail_error <= good_window_ms:
			tail_points = 70
			tail_accuracy = 2.0 / 3.0
		elif tail_error <= ok_window_ms:
			tail_points = 55
			tail_accuracy = 1.0 / 3.0
		combo += 1
		best_combo = maxi(best_combo, combo)
		_record_judgement("Hold OK", tail_points, tail_accuracy, float(note.get("tail_error_ms", 0.0)))

func _break_hold(index: int) -> void:
	var note: Dictionary = notes[index]
	if note.state != "holding":
		return
	var was_already_broken := bool(note.get("hold_broken", false))
	note.state = "broken"
	note.hold_broken = true
	notes[index] = note
	note_state_changed.emit(index, note.duplicate())
	combo = 0
	if not was_already_broken:
		_record_judgement("Hold Break", 0, 0.0, _song_time_ms() - float(note.end))

func _record_judgement(label: String, points: int, accuracy_value: float, timing_error_ms := 0.0) -> void:
	score += points
	last_judgement = label
	last_timing_error_ms = timing_error_ms
	if label != "Miss":
		if timing_error_ms < 0.0:
			early_hit_count += 1
		elif timing_error_ms > 0.0:
			late_hit_count += 1
	judgement_counts[label] = int(judgement_counts.get(label, 0)) + 1
	accuracy_points += accuracy_value
	accuracy_total += 1.0
	var health_delta := 0.0
	match label:
		"Perfect": health_delta = 2.0
		"Great": health_delta = 1.2
		"Good": health_delta = 0.5
		"OK": health_delta = 0.1
		"Meh": health_delta = -1.0
		"Miss": health_delta = -14.0
		"Hold OK": health_delta = 1.0
		"Hold Break": health_delta = -8.0
	_change_health(health_delta)
	judgement_label.text = label
	judgement_label.modulate = Color("8ee6b2") if accuracy_value >= 0.8 else Color("ffcf73") if accuracy_value > 0.0 else Color("ff8585")
	_play_hit_sound(label)
	judgement_made.emit({
		"label": label,
		"points": points,
		"accuracy_value": accuracy_value,
		"score": score,
		"combo": combo,
		"accuracy": _accuracy_percent(),
		"health": health,
		"no_fail": no_fail_mode,
		"failed": failed,
		"timing_error_ms": timing_error_ms,
		"timing_text": _timing_text(timing_error_ms),
		"song_time_ms": _song_time_ms(),
	})

func _toggle_pause() -> void:
	if not playing:
		return
	paused = not paused
	if audio_started:
		audio_player.stream_paused = paused
	pause_label.visible = paused
	_set_status("已暂停" if paused else "继续游戏")
	gameplay_paused.emit(paused)

func _adjust_offset(delta_ms: float) -> void:
	global_offset_ms = clampf(global_offset_ms + delta_ms, -250.0, 250.0)
	_save_settings()
	_update_timing_label()
	_set_status("全局延迟已调整为 %.0f ms" % global_offset_ms)
	timing_offset_changed.emit(global_offset_ms)

func _retry() -> void:
	if not playing and notes.is_empty():
		return
	practice_run = false
	replay_playing = false
	replay_cursor = 0
	replay_events.clear()
	run_offset_ms = 0.0
	_reset_run_state()
	replay_state_changed.emit(replay_complete_available and last_replay_path == chart_source_path, false)

func _reset_run_state() -> void:
	for i in notes.size():
		var note: Dictionary = notes[i]
		note.state = "pending"
		note.hold_broken = false
		note.head_error_ms = 0.0
		note.tail_error_ms = 0.0
		notes[i] = note
	score = 0
	combo = 0
	best_combo = 0
	accuracy_points = 0.0
	accuracy_total = 0.0
	judgement_counts = {"Perfect": 0, "Great": 0, "Good": 0, "OK": 0, "Meh": 0, "Miss": 0, "Hold OK": 0, "Hold Break": 0}
	last_judgement = ""
	last_timing_error_ms = 0.0
	early_hit_count = 0
	late_hit_count = 0
	health = MAX_HEALTH
	failed = false
	lane_down = [false, false, false, false]
	playing = true
	paused = false
	finish_queued = false
	audio_started = false
	audio_finished = false
	song_clock_ms = -approach_ms
	pause_label.visible = false
	result_label.visible = false
	audio_player.stop()
	_update_progress()
	gameplay_started.emit(get_chart_metadata())
	queue_redraw()

func _on_audio_finished() -> void:
	if playing:
		audio_finished = true

func _finish_play(was_failed := false) -> void:
	if not playing:
		return
	finish_queued = false
	var was_replay := replay_playing
	failed = was_failed
	playing = false
	paused = false
	audio_started = false
	audio_finished = true
	if audio_player != null:
		audio_player.stop()
	if was_replay:
		replay_playing = false
		replay_cursor = 0
	else:
		last_replay_events = replay_events.duplicate(true)
		last_replay_path = chart_source_path
		last_replay_offset_ms = global_offset_ms
		replay_complete_available = not last_replay_events.is_empty()
		if replay_complete_available:
			save_replay()
		replay_state_changed.emit(replay_complete_available and last_replay_path == chart_source_path, false)
	pause_label.visible = false
	result_label.visible = true
	result_label.text = ("失败" if failed else "完成") + "\n\n分数：%d\n准确率：%.2f%%\n最大连击：%d\n\nPerfect %d  Great %d  Good %d  OK %d  Meh %d\nMiss %d  Hold Break %d\n\n点击“重试”再来一次" % [score, _accuracy_percent(), best_combo, judgement_counts["Perfect"], judgement_counts["Great"], judgement_counts["Good"], judgement_counts["OK"], judgement_counts["Meh"], judgement_counts["Miss"], judgement_counts["Hold Break"]]
	_set_status("谱面结束")
	var result := {
		"score": score,
		"accuracy": _accuracy_percent(),
		"grade": _grade_for_accuracy(_accuracy_percent()),
		"best_combo": best_combo,
		"judgement_counts": judgement_counts.duplicate(),
		"early_hits": early_hit_count,
		"late_hits": late_hit_count,
		"last_timing_error_ms": last_timing_error_ms,
		"health": health,
		"failed": failed,
	}
	var is_new_record := false
	if not was_replay and not practice_run and not failed:
		is_new_record = _record_personal_best(result)
	result["is_new_record"] = is_new_record
	result["replay"] = was_replay
	result["practice"] = practice_run
	result_label.text = ("失败" if failed else "完成") + "\n\n段位：%s%s\n分数：%d\n准确率：%.2f%%\n最大连击：%d\n\nPerfect %d  Great %d  Good %d  OK %d  Meh %d\nMiss %d  Hold Break %d\n早击 %d  晚击 %d\n\n点击“重试”再来一次" % [_grade_for_accuracy(_accuracy_percent()), "  新纪录" if is_new_record else "", score, _accuracy_percent(), best_combo, judgement_counts["Perfect"], judgement_counts["Great"], judgement_counts["Good"], judgement_counts["OK"], judgement_counts["Meh"], judgement_counts["Miss"], judgement_counts["Hold Break"], early_hit_count, late_hit_count]
	if progress_bar != null:
		progress_bar.value = 100.0
	gameplay_finished.emit(result)
	queue_redraw()

func _accuracy_percent() -> float:
	if accuracy_total <= 0.0:
		return 0.0
	return accuracy_points / accuracy_total * 100.0

func _grade_for_accuracy(value: float) -> String:
	if value >= 99.0:
		return "SS"
	if value >= 95.0:
		return "S"
	if value >= 90.0:
		return "A"
	if value >= 80.0:
		return "B"
	if value >= 70.0:
		return "C"
	if value >= 60.0:
		return "D"
	return "F"

func _timing_text(error_ms: float) -> String:
	if absf(error_ms) < 0.5:
		return "±0 ms"
	return ("早 %.0f ms" % absf(error_ms)) if error_ms < 0.0 else ("晚 %.0f ms" % error_ms)

func _make_hit_sound(frequency: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * 0.055)
	var data := PackedByteArray()
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var envelope := exp(-t * 55.0)
		var sample := int(round(sin(TAU * frequency * t) * envelope * 0.28 * 32767.0))
		data.append(sample & 0xff)
		data.append((sample >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _make_calibration_track() -> AudioStreamWAV:
	var mix_rate := 44100
	var beat_count := 11
	var total_samples := int(mix_rate * 5.7)
	var data := PackedByteArray()
	for i in total_samples:
		var t := float(i) / float(mix_rate)
		var beat_position := t / (CALIBRATION_BEAT_MS / 1000.0)
		var beat_index := int(floor(beat_position))
		var within_beat := t - float(beat_index) * CALIBRATION_BEAT_MS / 1000.0
		var sample_value := 0.0
		if beat_index >= 0 and beat_index < beat_count and within_beat < 0.08:
			var frequency := 500.0 if beat_index < 3 else 900.0
			var envelope := exp(-within_beat * 48.0)
			sample_value = sin(TAU * frequency * within_beat) * envelope * 0.3
		var sample := int(round(sample_value * 32767.0))
		data.append(sample & 0xff)
		data.append((sample >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _load_audio_buffer(path: String, data: PackedByteArray) -> AudioStream:
	var lower := path.to_lower()
	if lower.ends_with(".mp3"):
		return AudioStreamMP3.load_from_buffer(data)
	if lower.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_buffer(data)
	if lower.ends_with(".wav"):
		return AudioStreamWAV.load_from_buffer(data)
	return null

func _play_hit_sound(label: String) -> void:
	if not hit_sounds_enabled or hit_sound_players.is_empty():
		return
	var stream: AudioStream = hit_sound_streams.get(label, hit_sound_streams.get("Good"))
	if stream == null:
		return
	var player := hit_sound_players[hit_sound_cursor % hit_sound_players.size()]
	hit_sound_cursor = (hit_sound_cursor + 1) % hit_sound_players.size()
	player.stream = stream
	player.play()

func _record_personal_best(result: Dictionary) -> bool:
	var current := get_personal_best()
	var score_value := int(result.get("score", 0))
	var accuracy_value := float(result.get("accuracy", 0.0))
	var is_better := current.is_empty() or score_value > int(current.get("score", 0)) or (score_value == int(current.get("score", 0)) and accuracy_value > float(current.get("accuracy", 0.0)))
	if not is_better:
		return false
	var entry := result.duplicate(true)
	entry["path"] = chart_source_path
	entry["title"] = song_title
	entry["artist"] = song_artist
	entry["version"] = song_version
	var replaced := false
	for i in personal_best_entries.size():
		if str(personal_best_entries[i].get("path", "")) == chart_source_path:
			personal_best_entries[i] = entry
			replaced = true
			break
	if not replaced:
		personal_best_entries.append(entry)
	_save_settings()
	personal_best_changed.emit(entry.duplicate(true))
	return true

func _update_score_text() -> void:
	if score_label == null:
		return
	score_label.text = "Score %06d\nCombo %d\nAcc %.2f%%" % [score, combo, _accuracy_percent()]

func _update_timing_label() -> void:
	if timing_label == null:
		return
	timing_label.text = "偏移：%+.0f ms" % global_offset_ms

func _update_progress() -> void:
	if progress_bar == null:
		return
	var duration_ms := chart_end_ms
	if audio_player != null and audio_player.stream != null:
		duration_ms = maxf(duration_ms, audio_player.stream.get_length() * 1000.0)
	if duration_ms <= 0.0:
		progress_bar.value = 0.0
		return
	var progress := clampf(_song_time_ms() / duration_ms * 100.0, 0.0, 100.0)
	progress_bar.value = progress
	progress_changed.emit(progress, _song_time_ms(), duration_ms)

func _begin_rebind(lane: int, button: Button) -> void:
	begin_key_rebind(lane)
	button.text = "请按键…"

func _cancel_rebind() -> void:
	if capture_lane >= 0:
		key_buttons[capture_lane].text = "轨道 %d：%s" % [capture_lane + 1, key_labels[capture_lane]]
	capture_lane = -1
	_set_status("已取消改键")

func _set_status(message: String, error := false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ff9c9c") if error else Color("8ee6b2"))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for lane in LANE_COUNT:
		key_codes[lane] = int(config.get_value("keys", str(lane), key_codes[lane]))
		key_labels[lane] = OS.get_keycode_string(key_codes[lane])
	global_offset_ms = float(config.get_value("timing", "global_offset_ms", 0.0))
	volume_percent = clampf(float(config.get_value("audio", "volume_percent", 100.0)), 0.0, 100.0)
	hit_sounds_enabled = bool(config.get_value("audio", "hit_sounds_enabled", true))
	scroll_speed_percent = clampf(float(config.get_value("gameplay", "scroll_speed_percent", 100.0)), 50.0, 200.0)
	no_fail_mode = bool(config.get_value("gameplay", "no_fail_mode", true))
	approach_ms = DEFAULT_APPROACH_MS * 100.0 / scroll_speed_percent
	recent_charts.clear()
	for saved_path in config.get_value("recent", "paths", []):
		var chart_path := str(saved_path)
		if chart_path != "" and FileAccess.file_exists(chart_path):
			recent_charts.append(chart_path)
	personal_best_entries.clear()
	for saved_entry in config.get_value("scores", "personal_bests", []):
		if saved_entry is Dictionary and str(saved_entry.get("path", "")) != "":
			personal_best_entries.append(saved_entry.duplicate(true))
	file_dialog_dir = str(config.get_value("files", "last_dialog_dir", ""))

func _save_settings() -> void:
	var config := ConfigFile.new()
	for lane in LANE_COUNT:
		config.set_value("keys", str(lane), key_codes[lane])
	config.set_value("timing", "global_offset_ms", global_offset_ms)
	config.set_value("audio", "volume_percent", volume_percent)
	config.set_value("audio", "hit_sounds_enabled", hit_sounds_enabled)
	config.set_value("gameplay", "scroll_speed_percent", scroll_speed_percent)
	config.set_value("gameplay", "no_fail_mode", no_fail_mode)
	config.set_value("recent", "paths", recent_charts)
	config.set_value("scores", "personal_bests", personal_best_entries)
	config.set_value("files", "last_dialog_dir", file_dialog_dir)
	config.save(CONFIG_PATH)

func _remember_chart(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	recent_charts.erase(path)
	recent_charts.push_front(path)
	while recent_charts.size() > 8:
		recent_charts.pop_back()
	_save_settings()
	recent_charts_changed.emit(get_recent_charts())

func _library_roots() -> Array[String]:
	var roots: Array[String] = []
	var user_root := ProjectSettings.globalize_path("user://songs")
	if DirAccess.dir_exists_absolute(user_root):
		roots.append(user_root)
	var bundled_root := ProjectSettings.globalize_path("res://Songs")
	if DirAccess.dir_exists_absolute(bundled_root):
		roots.append(bundled_root)
	var packaged_root := ProjectSettings.globalize_path("res://BundledSongs")
	if DirAccess.dir_exists_absolute(packaged_root) and not roots.has(packaged_root):
		roots.append(packaged_root)
	var local_root := ProjectSettings.globalize_path("res://.library")
	if DirAccess.dir_exists_absolute(local_root) and not roots.has(local_root):
		roots.append(local_root)
	return roots

func _writable_library_root() -> String:
	var candidates: Array[String] = [ProjectSettings.globalize_path("user://songs"), ProjectSettings.globalize_path("res://.library")]
	for candidate: String in candidates:
		if DirAccess.make_dir_recursive_absolute(candidate) != OK:
			continue
		var probe_path: String = candidate.path_join(".write_probe")
		var probe := FileAccess.open(probe_path, FileAccess.WRITE)
		if probe != null:
			probe.store_string("ok")
			probe.close()
			DirAccess.remove_absolute(probe_path)
			return candidate
	return ""

func _collect_library_files(root: String, result: Array[Dictionary]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path := root.path_join(name)
		if dir.current_is_dir():
			_collect_library_files(path, result)
		elif name.to_lower().ends_with(".osu") or name.to_lower().ends_with(".osz"):
			var label := name.get_basename()
			if name.to_lower().ends_with(".osu"):
				var chart_file := FileAccess.open(path, FileAccess.READ)
				if chart_file != null:
					var parsed := _parse_osu(chart_file.get_as_text())
					chart_file.close()
					if parsed.mode != 3 or parsed.keys != 4:
						continue
					label = str(parsed.title if parsed.title != "" else label) + (" [" + str(parsed.version) + "]" if parsed.version != "" else "")
					result.append({"path": path, "label": label, "artist": str(parsed.artist), "audio_path": path.get_base_dir().path_join(str(parsed.audio_filename).replace("\\", "/")), "preview_ms": int(parsed.preview_time)})
			else:
				var reader := ZIPReader.new()
				if reader.open(path) == OK:
					for package_file in reader.get_files():
						if not package_file.to_lower().ends_with(".osu"):
							continue
						var package_parsed := _parse_osu(reader.read_file(package_file).get_string_from_utf8())
						if package_parsed.mode != 3 or package_parsed.keys != 4:
							continue
						label = str(package_parsed.title if package_parsed.title != "" else label) + (" [" + str(package_parsed.version) + "]" if package_parsed.version != "" else "")
						result.append({"path": path, "label": label, "artist": str(package_parsed.artist), "package_path": path, "audio_path": str(package_parsed.audio_filename).replace("\\", "/"), "preview_ms": int(package_parsed.preview_time)})
						break
					reader.close()
			continue
	dir.list_dir_end()

func _copy_file(source: String, target: String) -> bool:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return false
	var data := input.get_buffer(input.get_length())
	input.close()
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(data)
	output.close()
	return true

func _draw() -> void:
	if not default_playfield_visible:
		return
	var left := (size.x - LANE_WIDTH * LANE_COUNT) * 0.5
	for lane in LANE_COUNT:
		var x: float = left + lane * LANE_WIDTH
		draw_rect(Rect2(x, SPAWN_Y, LANE_WIDTH - 2, HIT_LINE_Y - SPAWN_Y + 28), Color("182235"), true)
		draw_line(Vector2(x, SPAWN_Y), Vector2(x, HIT_LINE_Y + 28), Color("30415d"), 2.0)
		var receptor_color := Color("8ee6b2") if lane_down[lane] else Color("405577")
		draw_rect(Rect2(x + 10, HIT_LINE_Y - 8, LANE_WIDTH - 22, 16), receptor_color, true)
		draw_string(ThemeDB.fallback_font, Vector2(x + LANE_WIDTH * 0.5 - 8, HIT_LINE_Y + 48), key_labels[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("dce7ff"))
	draw_line(Vector2(left, HIT_LINE_Y), Vector2(left + LANE_WIDTH * LANE_COUNT, HIT_LINE_Y), Color("8ee6b2"), 3.0)
	if not playing:
		return
	var now := _song_time_ms()
	for raw_note in notes:
		var note: Dictionary = raw_note
		if note.state != "pending" and note.state != "holding" and note.state != "broken" and note.state != "hold_missed":
			continue
		var head_time: float = note.time
		var tail_time: float = note.end
		var head_delta := head_time - now
		var tail_delta := tail_time - now
		if tail_delta < -hold_release_window_ms or head_delta > approach_ms:
			continue
		# Only a successfully held, unbroken head freezes at the judgement line.
		# A missed/broken head scrolls below it while the remaining body and tail
		# continue to render; judging the head must not hide the whole object.
		var pin_head: bool = note.state == "holding" and not bool(note.get("hold_broken", false)) and head_delta <= 0.0
		var head_y := HIT_LINE_Y if pin_head else HIT_LINE_Y - (head_delta / approach_ms) * (HIT_LINE_Y - SPAWN_Y)
		var tail_y := HIT_LINE_Y - (tail_delta / approach_ms) * (HIT_LINE_Y - SPAWN_Y)
		var x: float = left + note.lane * LANE_WIDTH + 14.0
		var w := LANE_WIDTH - 30.0
		var playfield_bottom := HIT_LINE_Y + 28.0
		if tail_time > head_time:
			var body_top := clampf(minf(head_y, tail_y), SPAWN_Y, playfield_bottom)
			var body_bottom := clampf(maxf(head_y, tail_y), SPAWN_Y, playfield_bottom)
			var body_color := Color("56a8ff") if note.state == "holding" else Color("d66b78") if note.state == "broken" else Color("8d98aa") if note.state == "hold_missed" else Color("3b78bd")
			var tail_color := Color("9bcfff") if note.state == "holding" else Color("ff9c9c") if note.state == "broken" else Color("b0b7c4") if note.state == "hold_missed" else Color("9bcfff")
			if body_bottom >= body_top:
				draw_rect(Rect2(x + w * 0.25, body_top, w * 0.5, maxf(body_bottom - body_top, 3.0)), body_color, true)
			if tail_y >= SPAWN_Y - 6.0 and tail_y <= playfield_bottom + 6.0:
				draw_rect(Rect2(x + 2, clampf(tail_y, SPAWN_Y, playfield_bottom) - 6, w - 4, 12), tail_color, true)
		var head_color := Color("56a8ff") if note.state == "holding" else Color("d66b78") if note.state == "broken" else Color("7d8798") if note.state == "hold_missed" else Color("f2cf63")
		if head_y >= SPAWN_Y - 8.0 and head_y <= playfield_bottom + 8.0:
			draw_rect(Rect2(x, clampf(head_y, SPAWN_Y, playfield_bottom) - 8, w, 16), head_color, true)
