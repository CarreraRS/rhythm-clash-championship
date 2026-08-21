extends CanvasLayer

var resume_button : Button
var volume_slider : HSlider
var menu_button : Button

var master_bus_index : int = 0

func _ready():
	hide()
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# ค้นหา Node ตามชื่อใน Scene Tree โดยตรง
	resume_button = find_child("ResumeButton", true, false) as Button
	volume_slider = find_child("VolumeSlider", true, false) as HSlider
	menu_button = find_child("MenuButton", true, false) as Button
	
	# เชื่อมต่อ Event สัญญาณ
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	else:
		print("Warning: ResumeButton not found in PauseUI scene!")
		
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		print("Warning: MenuButton not found in PauseUI scene!")
		
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_slider_value_changed)
		var current_db = AudioServer.get_bus_volume_db(master_bus_index)
		volume_slider.value = current_db
	else:
		print("Warning: VolumeSlider not found in PauseUI scene!")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	get_tree().paused = true
	show()

func resume_game():
	get_tree().paused = false
	hide()

func _on_resume_button_pressed():
	resume_game()

func _on_menu_button_pressed():
	get_tree().paused = false
	GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_volume_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_index, value)
	if value <= -39.0:
		AudioServer.set_bus_mute(master_bus_index, true)
	else:
		AudioServer.set_bus_mute(master_bus_index, false)
