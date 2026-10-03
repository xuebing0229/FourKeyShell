extends Control

enum Page { HOME, LIBRARY, ACHIEVEMENTS, SETTINGS, GAMEPLAY, RESULTS }

const NAV_WIDTH := 236.0
const CONTENT_LEFT := 268.0
const CONTENT_WIDTH := 804.0
const BG := Color("0a1020")
const SURFACE := Color("121b31")
const SURFACE_2 := Color("17243d")
const SURFACE_3 := Color("1d2d4b")
const TEXT := Color("eef4ff")
const MUTED := Color("91a3c2")
const ACCENT := Color("72e3c0")
const ACCENT_2 := Color("86a7ff")
const WARNING := Color("ffd166")

var shell: Control
var current_page := Page.HOME
var return_page := Page.HOME
var settings_paused_by_ui := false
var page_host: Control
var pages: Dictionary = {}
var nav_root: Control
var nav_buttons: Dictionary = {}
var status_label: Label

var home_page: Control
var home_title: Label
var home_artist: Label
var home_meta: Label
var home_play_button: Button
var home_recent_root: Control

var library_page: Control
var library_search: LineEdit
var library_list_root: Control
var library_scroll: ScrollContainer
var library_detail_title: Label
var library_detail_artist: Label
var library_detail_meta: Label
var library_detail_path: Label
var library_empty_label: Label
var library_preview_button: Button
var library_play_button: Button
var filtered_library_indices: Array[int] = []
var selected_library_visible := -1

var achievements_page: Control
var achievements_stats_root: Control
var achievements_records_root: Control
var settings_page: Control

var settings_key_buttons: Array[Button] = []
var settings_status: Label
var volume_slider: HSlider
var speed_slider: HSlider
var hit_sounds_toggle: CheckButton
var no_fail_toggle: CheckButton
var offset_label: Label

var gameplay_page: Control
var game_title: Label
var game_artist: Label
var game_score: Label
var health_bar: ProgressBar
var health_status: Label
var judgement_label: Label
var timing_feedback_label: Label
var game_status: Label
var game_progress: ProgressBar
var chart_selector: OptionButton
var replay_button: Button
var practice_loop_label: Label
var pause_overlay: Control

var results_page: Control
var result_grade: Label
var result_summary: Label
var result_detail: Label
var result_replay_button: Button

func _ready() -> void:
	_build_visual_shell()

func attach_shell(runtime: Control) -> void:
	shell = runtime
	shell.chart_loaded.connect(_on_chart_loaded)
	shell.chart_load_failed.connect(_on_chart_load_failed)
	shell.gameplay_started.connect(_on_gameplay_started)
	shell.gameplay_paused.connect(_on_gameplay_paused)
	shell.judgement_made.connect(_on_judgement_made)
	shell.progress_changed.connect(_on_progress_changed)
	shell.gameplay_finished.connect(_on_gameplay_finished)
	shell.personal_best_changed.connect(_on_personal_best_changed)
	shell.bindings_changed.connect(_on_bindings_changed)
	shell.timing_offset_changed.connect(_on_timing_offset_changed)
	shell.volume_changed.connect(_on_volume_changed)
	shell.hit_sounds_changed.connect(_on_hit_sounds_changed)
	shell.health_changed.connect(_on_health_changed)
	shell.scroll_speed_changed.connect(_on_scroll_speed_changed)
	shell.recent_charts_changed.connect(_on_recent_charts_changed)
	shell.library_changed.connect(_on_library_changed)
	shell.practice_loop_changed.connect(_on_practice_loop_changed)
	shell.timing_calibration_changed.connect(_on_timing_calibration_changed)
	shell.replay_state_changed.connect(_on_replay_state_changed)
	shell.preview_changed.connect(_on_preview_changed)
	shell.set_default_playfield_visible(false)
	if volume_slider != null:
		volume_slider.value = shell.get_volume_percent()
	if speed_slider != null:
		speed_slider.value = shell.get_scroll_speed_percent()
	if hit_sounds_toggle != null:
		hit_sounds_toggle.button_pressed = shell.get_hit_sounds_enabled()
	if no_fail_toggle != null:
		no_fail_toggle.button_pressed = shell.get_no_fail_mode()
	_refresh_bindings()
	_refresh_library()
	_refresh_home()
	_refresh_achievements()
	var replay_info: Dictionary = shell.get_replay_info()
	_on_replay_state_changed(bool(replay_info.get("available", false)), bool(replay_info.get("playing", false)))
	_show_page(Page.HOME)

func _build_visual_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_host = Control.new()
	page_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_host)
	_build_pages()
	_build_nav()
	_build_pause_overlay()
	queue_redraw()

func _draw() -> void:
	if current_page == Page.GAMEPLAY:
		# Leave the native four-lane playfield transparent and decorate around it.
		draw_rect(Rect2(0, 0, size.x, 190), BG, true)
		draw_rect(Rect2(0, 190, 248, size.y - 190), BG, true)
		draw_rect(Rect2(852, 190, size.x - 852, size.y - 190), BG, true)
		draw_rect(Rect2(0, 665, size.x, size.y - 665), BG, true)
		draw_line(Vector2(0, 188), Vector2(size.x, 188), Color("223552"), 1.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), BG, true)
		draw_circle(Vector2(size.x - 80, 80), 250.0, Color(0.15, 0.27, 0.48, 0.18))
		draw_circle(Vector2(150, size.y + 40), 220.0, Color(0.08, 0.62, 0.55, 0.08))
		draw_line(Vector2(NAV_WIDTH, 0), Vector2(NAV_WIDTH, size.y), Color("1b2b48"), 1.0)

func _build_nav() -> void:
	nav_root = Control.new()
	# The rail used to be a full-screen Control. Even empty space on its
	# right side then swallowed clicks intended for the page content.
	nav_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	nav_root.size = Vector2(NAV_WIDTH, 700)
	add_child(nav_root)
	var rail := _panel(nav_root, Vector2(0, 0), Vector2(NAV_WIDTH, 700), Color("0d1629"), 0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := _label(nav_root, "FOUR / KEY", Vector2(28, 30), Vector2(190, 34), 22, TEXT)
	logo.add_theme_color_override("font_color", ACCENT)
	_label(nav_root, "MANIA SHELL", Vector2(30, 65), Vector2(180, 20), 11, MUTED)
	_label(nav_root, "本地 4K 音游", Vector2(30, 95), Vector2(180, 22), 13, TEXT)
	_add_nav_button("首页", "⌂", Page.HOME, 145)
	_add_nav_button("曲库 / 选曲", "♫", Page.LIBRARY, 197)
	_add_nav_button("成就 / 成绩", "✦", Page.ACHIEVEMENTS, 249)
	_add_nav_button("设置", "⚙", Page.SETTINGS, 301)
	var divider := ColorRect.new()
	divider.position = Vector2(28, 385)
	divider.size = Vector2(180, 1)
	divider.color = Color("243654")
	nav_root.add_child(divider)
	_label(nav_root, "PLAY LOCAL", Vector2(30, 410), Vector2(180, 20), 11, MUTED)
	status_label = _label(nav_root, "等待载入谱面", Vector2(30, 438), Vector2(178, 70), 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(nav_root, "v0.2  ·  OFFLINE", Vector2(30, 650), Vector2(180, 20), 11, Color("536886"))

func _add_nav_button(text: String, icon: String, page: int, y: float) -> void:
	var button := _make_button(nav_root, icon + "   " + text, Vector2(18, y), Vector2(200, 42), _navigate.bind(page), false)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	nav_buttons[page] = button

func _build_pages() -> void:
	home_page = _new_page(Page.HOME)
	library_page = _new_page(Page.LIBRARY)
	achievements_page = _new_page(Page.ACHIEVEMENTS)
	settings_page = _new_page(Page.SETTINGS)
	gameplay_page = _new_page(Page.GAMEPLAY)
	results_page = _new_page(Page.RESULTS)
	_build_home_page()
	_build_library_page()
	_build_achievements_page()
	_build_settings_page()
	_build_gameplay_page()
	_build_results_page()

func _new_page(page: int) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	page_host.add_child(root)
	pages[page] = root
	return root

func _build_home_page() -> void:
	_label(home_page, "WELCOME BACK", Vector2(CONTENT_LEFT, 38), Vector2(300, 22), 12, ACCENT)
	_label(home_page, "你的 4K 舞台", Vector2(CONTENT_LEFT, 63), Vector2(560, 52), 34, TEXT)
	_label(home_page, "从本地曲库开始一局，或导入一张完整的 .osu / .osz 谱面。", Vector2(CONTENT_LEFT, 112), Vector2(650, 28), 14, MUTED)
	var current_card := _panel(home_page, Vector2(CONTENT_LEFT, 168), Vector2(500, 246), SURFACE, 18)
	_label(current_card, "CURRENT CHART", Vector2(28, 24), Vector2(220, 18), 11, ACCENT)
	home_title = _label(current_card, "还没有载入谱面", Vector2(28, 55), Vector2(440, 42), 25, TEXT)
	home_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home_artist = _label(current_card, "从曲库选择一首歌开始", Vector2(28, 104), Vector2(430, 26), 14, MUTED)
	home_meta = _label(current_card, "4K  ·  本地离线游玩", Vector2(28, 137), Vector2(430, 24), 12, MUTED)
	home_play_button = _make_button(current_card, "打开谱面", Vector2(28, 184), Vector2(145, 42), _home_play, true)
	_make_button(current_card, "去曲库", Vector2(185, 184), Vector2(110, 42), _navigate.bind(Page.LIBRARY), false)
	var quick := _panel(home_page, Vector2(790, 168), Vector2(280, 246), SURFACE, 18)
	_label(quick, "QUICK ACCESS", Vector2(24, 24), Vector2(220, 18), 11, ACCENT_2)
	_label(quick, "准备好了吗？", Vector2(24, 58), Vector2(220, 30), 20, TEXT)
	_label(quick, "D F J K\n默认 4K 操作轨道", Vector2(24, 103), Vector2(220, 50), 15, MUTED)
	_make_button(quick, "打开设置", Vector2(24, 178), Vector2(150, 40), _open_settings, false)
	_label(home_page, "RECENTLY PLAYED", Vector2(CONTENT_LEFT, 458), Vector2(300, 22), 12, MUTED)
	home_recent_root = Control.new()
	home_recent_root.position = Vector2(CONTENT_LEFT, 490)
	home_recent_root.size = Vector2(CONTENT_WIDTH, 135)
	home_page.add_child(home_recent_root)

func _build_library_page() -> void:
	_label(library_page, "SELECT MUSIC", Vector2(CONTENT_LEFT, 38), Vector2(300, 22), 12, ACCENT)
	_label(library_page, "曲库 / 选曲", Vector2(CONTENT_LEFT, 63), Vector2(420, 48), 32, TEXT)
	_label(library_page, "所有谱面都保存在本机，不需要账号或联网。", Vector2(CONTENT_LEFT, 112), Vector2(500, 24), 14, MUTED)
	library_search = LineEdit.new()
	library_search.position = Vector2(610, 37)
	library_search.size = Vector2(240, 38)
	library_search.placeholder_text = "搜索曲名、作者或文件名"
	library_search.clear_button_enabled = true
	_apply_input_theme(library_search)
	library_search.text_changed.connect(_on_library_search_changed)
	library_page.add_child(library_search)
	_make_button(library_page, "＋ 导入", Vector2(610, 88), Vector2(112, 36), _import_chart, true)
	_make_button(library_page, "刷新", Vector2(730, 88), Vector2(80, 36), _refresh_library, false)
	var list_panel := _panel(library_page, Vector2(CONTENT_LEFT, 148), Vector2(480, 475), SURFACE, 18)
	_label(list_panel, "曲目列表", Vector2(22, 20), Vector2(200, 24), 16, TEXT)
	_label(list_panel, "选择后在右侧查看详情", Vector2(22, 48), Vector2(300, 20), 12, MUTED)
	library_scroll = ScrollContainer.new()
	library_scroll.position = Vector2(18, 82)
	library_scroll.size = Vector2(444, 370)
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(library_scroll)
	library_list_root = Control.new()
	library_list_root.custom_minimum_size = Vector2(444, 370)
	library_scroll.add_child(library_list_root)
	library_empty_label = _label(list_panel, "曲库还是空的\n导入一张 4K .osu / .osz 开始吧", Vector2(36, 190), Vector2(405, 70), 15, MUTED)
	library_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	library_empty_label.visible = false
	var detail := _panel(library_page, Vector2(770, 148), Vector2(300, 475), SURFACE, 18)
	_label(detail, "SELECTED CHART", Vector2(22, 22), Vector2(240, 18), 11, ACCENT_2)
	library_detail_title = _label(detail, "未选择曲目", Vector2(22, 58), Vector2(250, 72), 22, TEXT)
	library_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_detail_artist = _label(detail, "", Vector2(22, 136), Vector2(250, 24), 14, MUTED)
	library_detail_meta = _label(detail, "", Vector2(22, 176), Vector2(250, 60), 13, MUTED)
	library_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_detail_path = _label(detail, "", Vector2(22, 250), Vector2(250, 80), 11, Color("617495"))
	library_detail_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_preview_button = _make_button(detail, "试听 15 秒", Vector2(22, 366), Vector2(118, 40), _preview_selected_library, false)
	library_play_button = _make_button(detail, "开始游戏", Vector2(150, 366), Vector2(126, 40), _play_selected_library, true)
	library_preview_button.disabled = true
	library_play_button.disabled = true

func _build_achievements_page() -> void:
	_label(achievements_page, "LOCAL PROFILE", Vector2(CONTENT_LEFT, 38), Vector2(300, 22), 12, ACCENT)
	_label(achievements_page, "成就 / 成绩", Vector2(CONTENT_LEFT, 63), Vector2(420, 48), 32, TEXT)
	_label(achievements_page, "只记录在这台电脑上的游玩，不做联网排名。", Vector2(CONTENT_LEFT, 112), Vector2(500, 24), 14, MUTED)
	achievements_stats_root = Control.new()
	achievements_stats_root.position = Vector2(CONTENT_LEFT, 160)
	achievements_stats_root.size = Vector2(CONTENT_WIDTH, 120)
	achievements_page.add_child(achievements_stats_root)
	var record_panel := _panel(achievements_page, Vector2(CONTENT_LEFT, 305), Vector2(CONTENT_WIDTH, 318), SURFACE, 18)
	_label(record_panel, "BEST RUNS", Vector2(22, 20), Vector2(220, 20), 12, ACCENT_2)
	_label(record_panel, "你的最佳表现会自动保存在本地", Vector2(22, 48), Vector2(360, 20), 12, MUTED)
	achievements_records_root = Control.new()
	achievements_records_root.position = Vector2(22, 83)
	achievements_records_root.size = Vector2(760, 220)
	record_panel.add_child(achievements_records_root)

func _build_settings_page() -> void:
	_label(settings_page, "CONFIGURATION", Vector2(CONTENT_LEFT, 38), Vector2(300, 22), 12, ACCENT)
	_label(settings_page, "设置", Vector2(CONTENT_LEFT, 63), Vector2(420, 48), 32, TEXT)
	_label(settings_page, "把操作、音频和视觉节奏调成你的手感。", Vector2(CONTENT_LEFT, 112), Vector2(500, 24), 14, MUTED)
	var controls := _panel(settings_page, Vector2(CONTENT_LEFT, 160), Vector2(382, 463), SURFACE, 18)
	_label(controls, "GAMEPLAY", Vector2(22, 22), Vector2(220, 18), 11, ACCENT_2)
	_label(controls, "轨道键位", Vector2(22, 58), Vector2(180, 22), 15, TEXT)
	_label(controls, "点击后按下新键", Vector2(22, 84), Vector2(220, 20), 12, MUTED)
	for lane in 4:
		var binding := _make_button(controls, "轨道 %d" % (lane + 1), Vector2(20 + lane * 84, 118), Vector2(76, 44), _begin_rebind.bind(lane), false)
		binding.add_theme_font_size_override("font_size", 12)
		settings_key_buttons.append(binding)
	_make_button(controls, "恢复默认 D F J K", Vector2(20, 180), Vector2(190, 38), _reset_bindings, false)
	_label(controls, "下落速度", Vector2(22, 246), Vector2(120, 20), 14, TEXT)
	speed_slider = HSlider.new()
	speed_slider.position = Vector2(20, 276)
	speed_slider.size = Vector2(310, 24)
	speed_slider.min_value = 50.0
	speed_slider.max_value = 200.0
	speed_slider.step = 5.0
	speed_slider.value_changed.connect(_on_scroll_speed_slider_changed)
	controls.add_child(speed_slider)
	_label(controls, "50%", Vector2(20, 302), Vector2(40, 18), 11, MUTED)
	_label(controls, "200%", Vector2(290, 302), Vector2(45, 18), 11, MUTED)
	_label(controls, "音量", Vector2(22, 337), Vector2(120, 20), 14, TEXT)
	volume_slider = HSlider.new()
	volume_slider.position = Vector2(20, 367)
	volume_slider.size = Vector2(310, 24)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	controls.add_child(volume_slider)
	hit_sounds_toggle = CheckButton.new()
	hit_sounds_toggle.text = "判定音效"
	hit_sounds_toggle.position = Vector2(20, 405)
	hit_sounds_toggle.toggled.connect(_toggle_hit_sounds)
	controls.add_child(hit_sounds_toggle)
	no_fail_toggle = CheckButton.new()
	no_fail_toggle.text = "练习模式（不因血量失败）"
	no_fail_toggle.position = Vector2(20, 438)
	no_fail_toggle.toggled.connect(_toggle_no_fail)
	controls.add_child(no_fail_toggle)
	var timing := _panel(settings_page, Vector2(670, 160), Vector2(400, 220), SURFACE, 18)
	_label(timing, "AUDIO TIMING", Vector2(22, 22), Vector2(220, 18), 11, ACCENT_2)
	_label(timing, "全局偏移", Vector2(22, 58), Vector2(130, 22), 15, TEXT)
	offset_label = _label(timing, "+0 ms", Vector2(22, 86), Vector2(130, 28), 22, ACCENT)
	_make_button(timing, "−5 ms", Vector2(178, 56), Vector2(82, 38), _adjust_offset.bind(-5.0), false)
	_make_button(timing, "+5 ms", Vector2(270, 56), Vector2(82, 38), _adjust_offset.bind(5.0), false)
	_make_button(timing, "自动跟拍校准", Vector2(22, 135), Vector2(150, 40), _start_timing_calibration, true)
	_make_button(timing, "归零", Vector2(184, 135), Vector2(82, 40), _reset_offset, false)
	settings_status = _label(timing, "", Vector2(22, 184), Vector2(350, 24), 12, MUTED)
	var app_settings := _panel(settings_page, Vector2(670, 400), Vector2(400, 223), SURFACE, 18)
	_label(app_settings, "APP", Vector2(22, 22), Vector2(220, 18), 11, ACCENT_2)
	_label(app_settings, "窗口与本地体验", Vector2(22, 56), Vector2(260, 25), 15, TEXT)
	_label(app_settings, "设置会自动保存到本机。", Vector2(22, 86), Vector2(280, 22), 12, MUTED)
	_make_button(app_settings, "切换全屏", Vector2(22, 130), Vector2(120, 40), _toggle_fullscreen, false)
	_make_button(app_settings, "返回首页", Vector2(154, 130), Vector2(120, 40), _close_settings, true)

func _build_gameplay_page() -> void:
	_make_button(gameplay_page, "← 退出选曲", Vector2(22, 22), Vector2(118, 34), _leave_gameplay, false)
	game_title = _label(gameplay_page, "未载入谱面", Vector2(160, 20), Vector2(430, 32), 20, TEXT)
	game_artist = _label(gameplay_page, "", Vector2(160, 52), Vector2(430, 20), 12, MUTED)
	judgement_label = _label(gameplay_page, "", Vector2(455, 24), Vector2(170, 34), 22, TEXT)
	judgement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_feedback_label = _label(gameplay_page, "", Vector2(455, 58), Vector2(170, 22), 12, MUTED)
	timing_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_score = _label(gameplay_page, "SCORE 000000\nCOMBO 0\nACC 0.00%", Vector2(884, 24), Vector2(185, 66), 14, TEXT)
	health_status = _label(gameplay_page, "LIFE 100%", Vector2(650, 24), Vector2(110, 20), 12, TEXT)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(650, 48)
	health_bar.size = Vector2(210, 10)
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	gameplay_page.add_child(health_bar)
	chart_selector = OptionButton.new()
	chart_selector.position = Vector2(884, 98)
	chart_selector.size = Vector2(185, 32)
	chart_selector.item_selected.connect(_select_chart)
	_apply_option_theme(chart_selector)
	gameplay_page.add_child(chart_selector)
	game_status = _label(gameplay_page, "", Vector2(22, 75), Vector2(380, 24), 12, ACCENT)
	_make_button(gameplay_page, "暂停 / 继续", Vector2(22, 112), Vector2(118, 34), _toggle_pause, false)
	_make_button(gameplay_page, "重试", Vector2(150, 112), Vector2(76, 34), _retry, false)
	replay_button = _make_button(gameplay_page, "回放上一局", Vector2(238, 112), Vector2(118, 34), _replay_last, false)
	replay_button.disabled = true
	_make_button(gameplay_page, "设置", Vector2(368, 112), Vector2(76, 34), _open_settings, false)
	game_progress = ProgressBar.new()
	game_progress.position = Vector2(270, 682)
	game_progress.size = Vector2(580, 8)
	game_progress.show_percentage = false
	gameplay_page.add_child(game_progress)
	_make_button(gameplay_page, "−10 秒", Vector2(22, 622), Vector2(78, 32), _seek_practice.bind(-10000.0), false)
	_make_button(gameplay_page, "+10 秒", Vector2(108, 622), Vector2(78, 32), _seek_practice.bind(10000.0), false)
	_make_button(gameplay_page, "设起点", Vector2(22, 660), Vector2(78, 28), _set_loop_start, false)
	_make_button(gameplay_page, "设终点", Vector2(108, 660), Vector2(78, 28), _set_loop_end, false)
	_make_button(gameplay_page, "清循环", Vector2(194, 660), Vector2(78, 28), _clear_loop, false)
	practice_loop_label = _label(gameplay_page, "循环：关闭", Vector2(870, 618), Vector2(205, 24), 12, MUTED)
	practice_loop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(gameplay_page, "滚动速度", Vector2(870, 650), Vector2(100, 20), 11, MUTED)
	var game_speed := HSlider.new()
	game_speed.position = Vector2(958, 646)
	game_speed.size = Vector2(115, 24)
	game_speed.min_value = 50.0
	game_speed.max_value = 200.0
	game_speed.step = 5.0
	game_speed.value_changed.connect(_on_scroll_speed_slider_changed)
	gameplay_page.add_child(game_speed)

func _build_results_page() -> void:
	_label(results_page, "RUN COMPLETE", Vector2(CONTENT_LEFT, 38), Vector2(300, 22), 12, ACCENT)
	_label(results_page, "这一局结束了", Vector2(CONTENT_LEFT, 63), Vector2(500, 48), 32, TEXT)
	var card := _panel(results_page, Vector2(350, 150), Vector2(500, 420), SURFACE, 20)
	result_grade = _label(card, "A", Vector2(30, 35), Vector2(440, 78), 62, ACCENT)
	result_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_summary = _label(card, "", Vector2(30, 122), Vector2(440, 80), 17, TEXT)
	result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail = _label(card, "", Vector2(30, 220), Vector2(440, 80), 13, MUTED)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_replay_button = _make_button(card, "回放上一局", Vector2(52, 332), Vector2(180, 42), _replay_last, false)
	result_replay_button.disabled = true
	_make_button(card, "再来一次", Vector2(268, 332), Vector2(180, 42), _retry, true)
	_make_button(results_page, "返回曲库", Vector2(350, 592), Vector2(150, 38), _navigate.bind(Page.LIBRARY), false)
	_make_button(results_page, "回到首页", Vector2(520, 592), Vector2(150, 38), _navigate.bind(Page.HOME), false)

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.z_index = 30
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	add_child(pause_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(dim)
	var card := _panel(pause_overlay, Vector2(350, 245), Vector2(400, 220), SURFACE_2, 20)
	var pause_title := _label(card, "暂停中", Vector2(24, 28), Vector2(352, 42), 28, TEXT)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_hint := _label(card, "你的进度已经停住了", Vector2(24, 76), Vector2(352, 22), 13, MUTED)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_button(card, "继续", Vector2(28, 135), Vector2(104, 40), _resume_from_pause, true)
	_make_button(card, "重试", Vector2(148, 135), Vector2(104, 40), _retry, false)
	_make_button(card, "设置", Vector2(268, 135), Vector2(104, 40), _open_settings, false)

func _show_page(page: int) -> void:
	current_page = page
	for key in pages.keys():
		pages[key].visible = key == page
	if nav_root != null:
		nav_root.visible = page != Page.GAMEPLAY
	if shell != null:
		shell.set_default_playfield_visible(page == Page.GAMEPLAY)
	if page == Page.GAMEPLAY:
		_update_game_title()
	elif page == Page.HOME:
		_refresh_home()
	elif page == Page.ACHIEVEMENTS:
		_refresh_achievements()
	_update_nav_styles()
	queue_redraw()

func _navigate(page: int) -> void:
	if page == Page.SETTINGS:
		_open_settings()
		return
	if current_page == Page.SETTINGS:
		if shell != null and settings_paused_by_ui:
			settings_paused_by_ui = false
			shell.resume_game()
		settings_paused_by_ui = false
	if shell != null:
		var snapshot: Dictionary = shell.get_gameplay_snapshot()
		if snapshot.get("playing", false) and not snapshot.get("paused", false) and page != Page.GAMEPLAY:
			shell.pause_game()
	if page == Page.GAMEPLAY:
		if shell == null or shell.get_chart_metadata().get("source_path", "") == "":
			_show_page(Page.LIBRARY)
			return
		if shell.get_gameplay_snapshot().get("paused", false):
			shell.resume_game()
	_show_page(page)

func _update_nav_styles() -> void:
	for page in nav_buttons.keys():
		var button: Button = nav_buttons[page]
		_apply_button_theme(button, page == current_page, false)

func _open_chart() -> void:
	if shell != null:
		shell.open_file_dialog()

func _home_play() -> void:
	if shell == null:
		return
	if str(shell.get_chart_metadata().get("source_path", "")) == "":
		shell.open_file_dialog()
	else:
		var snapshot: Dictionary = shell.get_gameplay_snapshot()
		if not bool(snapshot.get("playing", false)):
			shell.retry_run()
		_show_page(Page.GAMEPLAY)
		if shell.get_gameplay_snapshot().get("paused", false):
			shell.resume_game()

func _open_settings() -> void:
	if shell == null:
		return
	return_page = current_page if current_page != Page.SETTINGS else Page.HOME
	var snapshot: Dictionary = shell.get_gameplay_snapshot()
	settings_paused_by_ui = bool(snapshot.get("playing", false)) and not bool(snapshot.get("paused", false))
	if settings_paused_by_ui:
		shell.pause_game()
	_show_page(Page.SETTINGS)
	_refresh_bindings()
	_update_offset_label()
	settings_status.text = "设置会自动保存到本机"

func _close_settings() -> void:
	if shell != null and settings_paused_by_ui:
		settings_paused_by_ui = false
		shell.resume_game()
	_show_page(return_page if return_page != Page.SETTINGS else Page.HOME)

func _leave_gameplay() -> void:
	if shell != null and shell.get_gameplay_snapshot().get("playing", false) and not shell.get_gameplay_snapshot().get("paused", false):
		shell.pause_game()
	_show_page(Page.LIBRARY)

func _toggle_pause() -> void:
	if shell == null:
		return
	var snapshot: Dictionary = shell.get_gameplay_snapshot()
	if snapshot.get("paused", false):
		shell.resume_game()
	else:
		shell.pause_game()

func _resume_from_pause() -> void:
	if shell != null:
		shell.resume_game()

func _retry() -> void:
	if shell != null:
		shell.retry_run()

func _select_chart(index: int) -> void:
	if shell != null:
		shell.select_chart(index)

func _select_recent_chart(index: int) -> void:
	if shell == null:
		return
	var charts: Array = shell.get_recent_charts()
	if index >= 0 and index < charts.size():
		shell.load_path(str(charts[index]))

func _select_library_visible(index: int) -> void:
	if index < 0 or index >= filtered_library_indices.size():
		return
	selected_library_visible = index
	_refresh_library_detail()

func _play_selected_library() -> void:
	if shell == null or selected_library_visible < 0 or selected_library_visible >= filtered_library_indices.size():
		return
	shell.load_library_entry(filtered_library_indices[selected_library_visible])

func _preview_selected_library() -> void:
	if shell == null or selected_library_visible < 0 or selected_library_visible >= filtered_library_indices.size():
		return
	var preview_state: Dictionary = shell.get_preview_state()
	if bool(preview_state.get("active", false)):
		shell.stop_preview()
	else:
		shell.preview_library_entry(filtered_library_indices[selected_library_visible])

func _import_chart() -> void:
	if shell != null:
		shell.open_import_dialog()

func _refresh_library() -> void:
	if shell == null or library_list_root == null:
		return
	for child in library_list_root.get_children():
		child.queue_free()
	filtered_library_indices.clear()
	var entries: Array = shell.get_library_entries()
	var query := library_search.text.strip_edges().to_lower() if library_search != null else ""
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var label := str(entry.get("label", "未命名谱面"))
		var artist := str(entry.get("artist", ""))
		if query != "" and not label.to_lower().contains(query) and not artist.to_lower().contains(query) and not str(entry.get("path", "")).to_lower().contains(query):
			continue
		filtered_library_indices.append(index)
		var visible_index := filtered_library_indices.size() - 1
		var row := _make_button(library_list_root, label, Vector2(0, visible_index * 52), Vector2(444, 42), _select_library_visible.bind(visible_index), false)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 13)
		var artist_label := _label(library_list_root, artist, Vector2(18, visible_index * 52 + 24), Vector2(400, 18), 10, MUTED)
		artist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	library_list_root.custom_minimum_size = Vector2(444, maxf(370.0, filtered_library_indices.size() * 52.0))
	library_empty_label.visible = filtered_library_indices.is_empty()
	if filtered_library_indices.is_empty():
		selected_library_visible = -1
	else:
		if selected_library_visible < 0 or selected_library_visible >= filtered_library_indices.size():
			selected_library_visible = 0
	_refresh_library_detail()

func _refresh_library_detail() -> void:
	if selected_library_visible < 0 or selected_library_visible >= filtered_library_indices.size() or shell == null:
		library_detail_title.text = "未选择曲目"
		library_detail_artist.text = ""
		library_detail_meta.text = ""
		library_detail_path.text = ""
		library_preview_button.disabled = true
		library_play_button.disabled = true
		return
	var entries: Array = shell.get_library_entries()
	var entry: Dictionary = entries[filtered_library_indices[selected_library_visible]]
	library_detail_title.text = str(entry.get("label", "未命名谱面"))
	library_detail_artist.text = str(entry.get("artist", "未知作者"))
	library_detail_meta.text = "4K Mania\n" + ("可试听 · " if str(entry.get("audio_path", "")) != "" else "") + "本地曲库"
	library_detail_path.text = str(entry.get("path", ""))
	library_preview_button.disabled = false
	library_play_button.disabled = false

func _refresh_home() -> void:
	if shell == null or home_title == null:
		return
	var meta: Dictionary = shell.get_chart_metadata()
	var source := str(meta.get("source_path", ""))
	if source == "":
		home_title.text = "还没有载入谱面"
		home_artist.text = "从曲库选择一首歌开始"
		home_meta.text = "4K  ·  本地离线游玩"
		home_play_button.text = "打开谱面"
	else:
		home_title.text = str(meta.get("title", "未命名谱面"))
		home_artist.text = str(meta.get("artist", "未知作者"))
		home_meta.text = "4K  ·  %d 音符  ·  %d 长键" % [meta.get("note_count", 0), meta.get("hold_count", 0)]
		home_play_button.text = "继续演奏"
	for child in home_recent_root.get_children():
		child.queue_free()
	var recent: Array = shell.get_recent_charts()
	if recent.is_empty():
		_label(home_recent_root, "还没有最近谱面。导入或从曲库选择后，它们会出现在这里。", Vector2(0, 10), Vector2(750, 28), 13, MUTED)
		return
	for index in min(recent.size(), 3):
		var path := str(recent[index])
		var button := _make_button(home_recent_root, path.get_file(), Vector2(index * 260, 0), Vector2(245, 64), _select_recent_chart.bind(index), false)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)

func _refresh_achievements() -> void:
	if shell == null or achievements_stats_root == null:
		return
	for child in achievements_stats_root.get_children():
		child.queue_free()
	for child in achievements_records_root.get_children():
		child.queue_free()
	var records: Array = shell.get_personal_bests()
	var total := records.size()
	var best_accuracy := 0.0
	var best_grade := "—"
	for entry in records:
		best_accuracy = maxf(best_accuracy, float(entry.get("accuracy", 0.0)))
		if best_grade == "—" or _grade_rank(str(entry.get("grade", "F"))) > _grade_rank(best_grade):
			best_grade = str(entry.get("grade", "F"))
	_add_stat_card(achievements_stats_root, 0, "已完成谱面", str(total), "本地记录")
	_add_stat_card(achievements_stats_root, 1, "最高评价", best_grade, "SS / S / A / B …")
	_add_stat_card(achievements_stats_root, 2, "最佳准确率", "%.2f%%" % best_accuracy, "只统计正式演奏")
	var badges := [["FIRST STEP", "完成第一次正式演奏", total > 0], ["STEADY HAND", "拿到 95% 以上准确率", best_accuracy >= 95.0], ["PERFECT RUN", "拿到 SS 评价", best_grade == "SS"]]
	for i in badges.size():
		var badge: Array = badges[i]
		var card := _panel(achievements_records_root, Vector2(i * 250, 0), Vector2(232, 72), SURFACE_2 if bool(badge[2]) else Color("111a2b"), 12)
		_label(card, str(badge[0]), Vector2(14, 12), Vector2(200, 18), 11, ACCENT if bool(badge[2]) else Color("52627e"))
		_label(card, str(badge[1]), Vector2(14, 36), Vector2(205, 20), 11, TEXT if bool(badge[2]) else MUTED)
	if records.is_empty():
		_label(achievements_records_root, "完成一局后，这里会出现你的最佳成绩和本地成就。", Vector2(0, 112), Vector2(760, 28), 13, MUTED)
	else:
		for i in min(records.size(), 3):
			var entry: Dictionary = records[i]
			var row := _panel(achievements_records_root, Vector2(0, 96 + i * 54), Vector2(760, 45), Color("111b30"), 10)
			_label(row, str(entry.get("title", "未命名")), Vector2(14, 12), Vector2(380, 22), 13, TEXT)
			_label(row, str(entry.get("grade", "F")), Vector2(500, 10), Vector2(60, 28), 18, ACCENT)
			_label(row, "%.2f%%   %d 分" % [float(entry.get("accuracy", 0.0)), int(entry.get("score", 0))], Vector2(570, 13), Vector2(170, 20), 12, MUTED)

func _add_stat_card(parent: Control, index: int, caption: String, value: String, hint: String) -> void:
	var card := _panel(parent, Vector2(index * 264, 0), Vector2(248, 105), SURFACE, 16)
	_label(card, caption, Vector2(18, 16), Vector2(210, 20), 12, MUTED)
	_label(card, value, Vector2(18, 40), Vector2(210, 36), 26, TEXT)
	_label(card, hint, Vector2(18, 80), Vector2(210, 16), 10, Color("617495"))

func _grade_rank(grade: String) -> int:
	return ["F", "D", "C", "B", "A", "S", "SS"].find(grade)

func _update_game_title() -> void:
	if shell == null:
		return
	var meta: Dictionary = shell.get_chart_metadata()
	game_title.text = str(meta.get("title", "未载入谱面"))
	game_artist.text = str(meta.get("artist", "")) + ("  ·  " + str(meta.get("version", "")) if str(meta.get("version", "")) != "" else "")
	_refresh_chart_selector()

func _refresh_chart_selector() -> void:
	if shell == null or chart_selector == null:
		return
	var candidates: Array = shell.get_chart_candidates()
	chart_selector.clear()
	for candidate in candidates:
		var label := str(candidate.get("version", "4K 谱面"))
		var note_count := int(candidate.get("note_count", 0))
		if note_count > 0:
			label += "  ·  %d 音符" % note_count
		chart_selector.add_item(label)
	chart_selector.visible = candidates.size() > 1
	if not candidates.is_empty():
		chart_selector.select(0)

func _on_chart_loaded(metadata: Dictionary) -> void:
	_refresh_home()
	_refresh_chart_selector()
	game_title.text = str(metadata.get("title", "未命名谱面"))
	game_artist.text = str(metadata.get("artist", ""))
	status_label.text = "%s  ·  %d 音符" % [metadata.get("artist", ""), metadata.get("note_count", 0)]
	_show_page(Page.GAMEPLAY)

func _on_chart_load_failed(message: String) -> void:
	status_label.text = message
	_show_page(Page.LIBRARY)

func _on_gameplay_started(metadata: Dictionary) -> void:
	game_title.text = str(metadata.get("title", "未命名谱面"))
	game_artist.text = str(metadata.get("artist", ""))
	game_status.text = "%d 音符  ·  %d 长键" % [metadata.get("note_count", 0), metadata.get("hold_count", 0)]
	_on_health_changed(float(shell.get_health()), bool(shell.get_no_fail_mode()), false)
	judgement_label.text = ""
	timing_feedback_label.text = ""
	if pause_overlay != null:
		pause_overlay.visible = false
	_show_page(Page.GAMEPLAY)

func _on_gameplay_paused(is_paused: bool) -> void:
	game_status.text = "已暂停" if is_paused else "继续演奏"
	if pause_overlay != null:
		pause_overlay.visible = is_paused and current_page == Page.GAMEPLAY

func _on_judgement_made(judgement: Dictionary) -> void:
	judgement_label.text = str(judgement.get("label", ""))
	timing_feedback_label.text = str(judgement.get("timing_text", ""))
	timing_feedback_label.modulate = ACCENT if absf(float(judgement.get("timing_error_ms", 0.0))) <= 45.0 else WARNING
	game_score.text = "SCORE %06d\nCOMBO %d\nACC %.2f%%" % [judgement.get("score", 0), judgement.get("combo", 0), judgement.get("accuracy", 0.0)]
	_on_health_changed(float(judgement.get("health", shell.get_health())), bool(judgement.get("no_fail", shell.get_no_fail_mode())), bool(judgement.get("failed", false)))

func _on_progress_changed(progress: float, _song_time_ms: float, _duration_ms: float) -> void:
	if game_progress != null:
		game_progress.value = progress
	if shell != null:
		var snapshot: Dictionary = shell.get_gameplay_snapshot()
		game_score.text = "SCORE %06d\nCOMBO %d\nACC %.2f%%" % [snapshot.get("score", 0), snapshot.get("combo", 0), snapshot.get("accuracy", 0.0)]

func _on_gameplay_finished(result: Dictionary) -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	result_grade.text = str(result.get("grade", "F"))
	result_grade.add_theme_color_override("font_color", ACCENT if str(result.get("grade", "F")) in ["SS", "S", "A"] else WARNING)
	result_summary.text = "%.2f%% 准确率\n%d 分 · 最大连击 %d" % [float(result.get("accuracy", 0.0)), int(result.get("score", 0)), int(result.get("best_combo", 0))]
	var counts: Dictionary = result.get("judgement_counts", {})
	result_detail.text = "Perfect %d   Great %d   Good %d\nOK %d   Meh %d   Miss %d\nHold Break %d   LIFE %.0f%%\n早击 %d   晚击 %d" % [counts.get("Perfect", 0), counts.get("Great", 0), counts.get("Good", 0), counts.get("OK", 0), counts.get("Meh", 0), counts.get("Miss", 0), counts.get("Hold Break", 0), result.get("health", 100.0), result.get("early_hits", 0), result.get("late_hits", 0)]
	result_replay_button.disabled = not bool(shell.get_replay_info().get("available", false))
	_refresh_achievements()
	_show_page(Page.RESULTS)

func _on_personal_best_changed(_best: Dictionary) -> void:
	_refresh_achievements()

func _on_bindings_changed(_bindings: Array) -> void:
	_refresh_bindings()
	if settings_status != null:
		settings_status.text = "键位已保存"

func _refresh_bindings() -> void:
	if shell == null:
		return
	var bindings: Array = shell.get_lane_bindings()
	for lane in min(4, settings_key_buttons.size()):
		settings_key_buttons[lane].text = "%d   %s" % [lane + 1, bindings[lane]]

func _begin_rebind(lane: int) -> void:
	if shell != null:
		shell.begin_key_rebind(lane)
		settings_status.text = "正在修改轨道 %d，请按下新键" % (lane + 1)

func _reset_bindings() -> void:
	if shell != null:
		shell.reset_lane_bindings()
		settings_status.text = "已恢复默认键位：D F J K"

func _on_volume_slider_changed(value: float) -> void:
	if shell != null:
		shell.set_volume_percent(value)

func _on_volume_changed(value: float) -> void:
	if volume_slider != null:
		volume_slider.value = value

func _on_scroll_speed_slider_changed(value: float) -> void:
	if shell != null:
		shell.set_scroll_speed_percent(value)

func _on_scroll_speed_changed(value: float) -> void:
	if speed_slider != null:
		speed_slider.value = value

func _toggle_hit_sounds(enabled: bool) -> void:
	if shell != null:
		shell.set_hit_sounds_enabled(enabled)
		settings_status.text = "判定音效：" + ("已开启" if enabled else "已关闭")

func _toggle_no_fail(enabled: bool) -> void:
	if shell != null:
		shell.set_no_fail_mode(enabled)
		settings_status.text = "练习模式：" + ("开启" if enabled else "关闭")

func _on_hit_sounds_changed(value: bool) -> void:
	if hit_sounds_toggle != null:
		hit_sounds_toggle.button_pressed = value

func _on_health_changed(value: float, no_fail: bool, failed: bool) -> void:
	if health_bar != null:
		health_bar.value = value
		health_bar.modulate = Color("72e3c0") if value > 45.0 else Color("ffd166") if value > 20.0 else Color("ff8585")
	if health_status != null:
		health_status.text = ("LIFE %.0f%%" % value) + (" · NO FAIL" if no_fail else "") + (" · FAILED" if failed else "")

func _start_timing_calibration() -> void:
	if shell != null and shell.start_timing_calibration():
		settings_status.text = "校准中：先听两拍，再跟着节拍按 8 次"

func _on_timing_calibration_changed(state: Dictionary) -> void:
	if settings_status == null:
		return
	if bool(state.get("active", false)):
		settings_status.text = "校准中：已记录 %d / %d 次" % [state.get("tap_count", 0), state.get("required_taps", 8)]
	elif bool(state.get("applied", false)):
		settings_status.text = "校准完成：平均偏差 %+.1f ms" % float(state.get("last_average_error_ms", 0.0))
	elif bool(state.get("unstable", false)):
		settings_status.text = "跟拍不稳定，未修改偏移；请重新校准"
	_update_offset_label()

func _on_timing_offset_changed(_offset_ms: float) -> void:
	_update_offset_label()

func _adjust_offset(delta_ms: float) -> void:
	if shell != null:
		shell._adjust_offset(delta_ms)
		_update_offset_label()

func _reset_offset() -> void:
	if shell != null:
		shell.reset_timing_offset()
		_update_offset_label()

func _update_offset_label() -> void:
	if shell == null or offset_label == null:
		return
	var state: Dictionary = shell.get_timing_calibration_state()
	offset_label.text = "%+.0f ms" % float(state.get("offset_ms", 0.0))

func _toggle_fullscreen() -> void:
	if shell != null:
		settings_status.text = "全屏状态：" + ("已开启" if shell.toggle_fullscreen() else "已关闭")

func _seek_practice(delta_ms: float) -> void:
	if shell != null:
		shell.seek_practice_ms(delta_ms)

func _set_loop_start() -> void:
	if shell != null:
		shell.set_practice_loop_start()

func _set_loop_end() -> void:
	if shell != null:
		shell.set_practice_loop_end()

func _clear_loop() -> void:
	if shell != null:
		shell.clear_practice_loop()

func _on_practice_loop_changed(start_ms: float, end_ms: float) -> void:
	if practice_loop_label == null:
		return
	if start_ms < 0.0 or end_ms <= start_ms:
		practice_loop_label.text = "循环：关闭"
	else:
		practice_loop_label.text = "循环：%.1f–%.1f 秒" % [start_ms / 1000.0, end_ms / 1000.0]

func _replay_last() -> void:
	if shell == null:
		return
	var info: Dictionary = shell.get_replay_info()
	if bool(info.get("playing", false)):
		shell.stop_replay()
	else:
		shell.start_replay()

func _on_replay_state_changed(available: bool, playing: bool) -> void:
	if replay_button != null:
		replay_button.text = "停止回放" if playing else "回放上一局"
		replay_button.disabled = not available and not playing
	if result_replay_button != null:
		result_replay_button.text = "停止回放" if playing else "回放上一局"
		result_replay_button.disabled = not available and not playing
	if playing:
		_show_page(Page.GAMEPLAY)

func _on_preview_changed(active: bool, label: String) -> void:
	if library_preview_button == null:
		return
	library_preview_button.text = "停止试听" if active else "试听 15 秒"
	if active:
		status_label.text = "试听：" + label

func _on_recent_charts_changed(_charts: Array) -> void:
	_refresh_home()

func _on_library_changed(_entries: Array) -> void:
	_refresh_library()
	_refresh_home()

func _on_library_search_changed(_query: String) -> void:
	selected_library_visible = -1
	_refresh_library()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and current_page == Page.SETTINGS:
		_close_settings()
		get_viewport().set_input_as_handled()

func _label(parent: Control, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _panel(parent: Control, position: Vector2, panel_size: Vector2, color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, radius))
	parent.add_child(panel)
	return panel

func _make_button(parent: Control, text: String, position: Vector2, button_size: Vector2, action: Callable, accent: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = button_size
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	_apply_button_theme(button, accent, false)
	parent.add_child(button)
	return button

func _apply_button_theme(button: Button, selected: bool, _unused: bool) -> void:
	var base := ACCENT if selected else SURFACE_2
	button.add_theme_stylebox_override("normal", _style(base, 10, Color("2b4163"), 1))
	button.add_theme_stylebox_override("hover", _style(ACCENT if selected else SURFACE_3, 10, ACCENT, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("355479"), 10, ACCENT, 1))
	button.add_theme_stylebox_override("disabled", _style(Color("111a2b"), 10, Color("1b2942"), 1))
	button.add_theme_color_override("font_color", BG if selected else TEXT)
	button.add_theme_color_override("font_hover_color", BG if selected else TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("53627c"))

func _apply_input_theme(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", _style(SURFACE, 10, Color("2b4163"), 1))
	input.add_theme_stylebox_override("focus", _style(SURFACE_2, 10, ACCENT, 1))
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_font_size_override("font_size", 12)

func _apply_option_theme(option: OptionButton) -> void:
	_apply_button_theme(option, false, false)
	option.add_theme_font_size_override("font_size", 12)

func _style(color: Color, radius: int, border_color := Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
