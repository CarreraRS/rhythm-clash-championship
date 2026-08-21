extends Control

# --- Panels & UI ---
var main_buttons : VBoxContainer
var single_player_panel : Panel
var song_select_panel : Panel
var settings_panel : Panel
var credits_panel : Panel
var notice_dialog : AcceptDialog

# --- Audio Elements (สร้างผ่าน Code อัตโนมัติถ้าไม่มี Node) ---
var menu_bgm : AudioStreamPlayer
var preview_player : AudioStreamPlayer
var preview_timer : Timer

# --- High Score Labels (ถ้ามีใน Scene) ---
var song1_highscore_label : Label
var song2_highscore_label : Label
var song3_highscore_label : Label
var song4_highscore_label : Label

var master_bus_index : int = 0
var default_bgm_db : float = 0.0
var dimmed_bgm_db : float = -40.0
var is_previewing : bool = false
var preview_tween : Tween

func _ready():
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# 1. จัดการระบบ Audio Players
	_setup_audio_nodes()

	# 2. ดึง Panels
	main_buttons = find_child("MainButtons", true, false) as VBoxContainer
	single_player_panel = find_child("SinglePlayerPanel", true, false) as Panel
	song_select_panel = find_child("SongSelectPanel", true, false) as Panel
	settings_panel = find_child("SettingsPanel", true, false) as Panel
	credits_panel = find_child("CreditsPanel", true, false) as Panel
	notice_dialog = find_child("NoticeDialog", true, false) as AcceptDialog

	# ดึง High Score Labels (ถ้าคุณใส่ Label ไว้ใน SongSelectPanel)
	song1_highscore_label = find_child("Song1HighScoreLabel", true, false) as Label
	song2_highscore_label = find_child("Song2HighScoreLabel", true, false) as Label
	song3_highscore_label = find_child("Song3HighScoreLabel", true, false) as Label
	song4_highscore_label = find_child("Song4HighScoreLabel", true, false) as Label

	# 3. เชื่อมต่อปุ่มเมนูหลัก
	_connect_button("SinglePlayerButton", _on_single_player_pressed)
	_connect_button("MultiplayerButton", func(): _show_notice("Multiplayer ยังไม่เปิดให้บริการ (รออัพเดท)"))
	_connect_button("SettingsButton", _on_settings_pressed)
	_connect_button("CreditsButton", _on_credits_pressed)
	_connect_button("ExitButton", func(): get_tree().quit())

	# 4. เชื่อมต่อปุ่มย่อย Single Player
	_connect_button("StoryButton", func(): _show_notice("Story Mode กำลังพัฒนา (รออัพเดท)"))
	_connect_button("FreePlayButton", _on_freeplay_pressed)

	# 5. เชื่อมต่อปุ่มเลือกเพลงเข้าเล่น
	_connect_button("Song1Button", func(): _start_game("song1"))
	_connect_button("Song2Button", func(): _start_game("song2"))
	_connect_button("Song3Button", func(): _start_game("song3"))
	_connect_button("Song4Button", func(): _start_game("song4"))

	# 6. เชื่อมต่อปุ่มพรีวิวฟังเพลงตัวอย่าง (ถ้าสร้างปุ่มชื่อ Song1PreviewButton / Song2PreviewButton ไว้)
	_connect_button("Song1PreviewButton", func(): _toggle_preview("song1"))
	_connect_button("Song2PreviewButton", func(): _toggle_preview("song2"))
	_connect_button("Song3PreviewButton", func(): _toggle_preview("song3"))
	_connect_button("Song4PreviewButton", func(): _toggle_preview("song4"))
	# 7. เชื่อมต่อ Slider เสียง
	var volume_slider = find_child("VolumeSlider", true, false) as HSlider
	if volume_slider:
		volume_slider.value = AudioServer.get_bus_volume_db(master_bus_index)
		volume_slider.value_changed.connect(_on_volume_changed)

	# 8. เชื่อมต่อปุ่ม Back ทั้งหมด
	_connect_all_back_buttons()

	# ซ่อนหน้าย่อยทั้งหมด โชว์เฉพาะเมนูหลัก
	_show_main_buttons_only()

# --- ระบบ Audio & Preview ---

func _setup_audio_nodes():
	# ตรวจหา Node เดิม หรือสร้างขึ้นใหม่ถ้ายังไม่มีใน Scene Tree
	menu_bgm = find_child("MenuBGM", true, false) as AudioStreamPlayer
	if not menu_bgm:
		menu_bgm = AudioStreamPlayer.new()
		menu_bgm.name = "MenuBGM"
		add_child(menu_bgm)

	preview_player = find_child("PreviewPlayer", true, false) as AudioStreamPlayer
	if not preview_player:
		preview_player = AudioStreamPlayer.new()
		preview_player.name = "PreviewPlayer"
		add_child(preview_player)

	preview_timer = find_child("PreviewTimer", true, false) as Timer
	if not preview_timer:
		preview_timer = Timer.new()
		preview_timer.name = "PreviewTimer"
		add_child(preview_timer)

	preview_timer.one_shot = true
	preview_timer.wait_time = 8.0
	if not preview_timer.timeout.is_connected(_on_preview_timer_timeout):
		preview_timer.timeout.connect(_on_preview_timer_timeout)

	# ตัวอย่างใส่เสียง BGM เมนูหลัก (ปรับ Path ไฟล์ BGM เมนูของคุณที่นี่)
	# if ResourceLoader.exists("res://Audio/menu_bgm.mp3"):
	# 	menu_bgm.stream = load("res://Audio/menu_bgm.mp3")
	# 	menu_bgm.play()

func _toggle_preview(song_key: String):
	if is_previewing and GameManager.selected_song_key == song_key:
		_stop_preview()
	else:
		_start_preview(song_key)

func _start_preview(song_key: String):
	GameManager.selected_song_key = song_key
	var song_data = GameManager.get_current_song_data()
	var stream_path = song_data.get("stream_path", "")
	var start_time = song_data.get("preview_start", 0.0)

	if not FileAccess.file_exists(stream_path):
		print("[PREVIEW ERROR] Audio file not found at: ", stream_path)
		return

	is_previewing = true
	preview_player.stream = load(stream_path)
	preview_player.play(start_time)

	# จางเสียง BGM หน้าเมนูลง
	_fade_menu_bgm(dimmed_bgm_db, 0.5)

	# จับเวลา 8 วินาที
	preview_timer.start(8.0)
	print("[PREVIEW] Playing preview for: ", song_key, " (8 sec)")

func _stop_preview():
	if not is_previewing:
		return

	is_previewing = false
	preview_player.stop()
	preview_timer.stop()

	# เร่งเสียง BGM หน้าเมนูกลับมาปกติ
	_fade_menu_bgm(default_bgm_db, 0.8)
	print("[PREVIEW] Preview stopped.")

func _on_preview_timer_timeout():
	_stop_preview()

func _fade_menu_bgm(target_db: float, duration: float):
	if not menu_bgm or not menu_bgm.playing:
		return

	if preview_tween and preview_tween.is_running():
		preview_tween.kill()

	preview_tween = create_tween()
	preview_tween.tween_property(menu_bgm, "volume_db", target_db, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# --- ฟังก์ชันช่วยเชื่อมต่อปุ่ม ---

func _connect_button(button_name: String, callable: Callable):
	var btn = find_child(button_name, true, false) as Button
	if btn:
		if not btn.pressed.is_connected(callable):
			btn.pressed.connect(callable)
	else:
		# แสดง Warning เฉพาะปุ่มหลักที่จำเป็น
		if not button_name.contains("Preview"):
			print("Warning: Button not found -> ", button_name)

func _connect_all_back_buttons():
	for node in get_tree().get_nodes_in_group("back_buttons"):
		if node is Button:
			if not node.pressed.is_connected(_on_back_pressed):
				node.pressed.connect(_on_back_pressed)

	var back_btns = find_children("BackButton", "Button", true, false)
	for btn in back_btns:
		if not btn.pressed.is_connected(_on_back_pressed):
			btn.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	_stop_preview()
	_show_main_buttons_only()

# --- การสลับหน้า & อัปเดต UI ---

func _update_high_scores_ui():
	# อัปเดต High Score ของเพลง 1 และ 2 บน Label (ถ้าหาเจอใน Scene)
	if song1_highscore_label:
		var hs1 = GameManager.get_high_score_for_song("song1")
		song1_highscore_label.text = "HIGH SCORE: " + str(hs1)

	if song2_highscore_label:
		var hs2 = GameManager.get_high_score_for_song("song2")
		song2_highscore_label.text = "HIGH SCORE: " + str(hs2)
	
	if song3_highscore_label:
		var hs3 = GameManager.get_high_score_for_song("song3")
		song3_highscore_label.text = "HIGH SCORE: " + str(hs3)
	
	if song4_highscore_label:
		var hs4 = GameManager.get_high_score_for_song("song4")
		song4_highscore_label.text = "HIGH SCORE: " + str(hs4)

func _hide_all_panels():
	if single_player_panel: single_player_panel.hide()
	if song_select_panel: song_select_panel.hide()
	if settings_panel: settings_panel.hide()
	if credits_panel: credits_panel.hide()

func _show_main_buttons_only():
	_hide_all_panels()
	if main_buttons: main_buttons.show()

func _on_single_player_pressed():
	if main_buttons: main_buttons.hide()
	_hide_all_panels()
	if single_player_panel: single_player_panel.show()

func _on_freeplay_pressed():
	_hide_all_panels()
	_update_high_scores_ui() # ดึงคะแนน High Score มาแสดง
	if song_select_panel: song_select_panel.show()

func _on_settings_pressed():
	if main_buttons: main_buttons.hide()
	_hide_all_panels()
	if settings_panel: settings_panel.show()

func _on_credits_pressed():
	if main_buttons: main_buttons.hide()
	_hide_all_panels()
	if credits_panel: credits_panel.show()

func _show_notice(message: String):
	if notice_dialog:
		notice_dialog.dialog_text = message
		notice_dialog.popup_centered()

func _on_volume_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_index, value)
	AudioServer.set_bus_mute(master_bus_index, value <= -39.0)

func _start_game(song_key: String):
	_stop_preview()
	if menu_bgm:
		menu_bgm.stop()

	GameManager.selected_song_key = song_key
	GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Main/Main.tscn")
