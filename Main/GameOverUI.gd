extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/ScoreLabel
@onready var restart_button = $Control/VBoxContainer/RestartButton
@onready var menu_button = $Control/VBoxContainer/MenuButton
@onready var game_over_sound = $Control/GameOverSound

func _ready():
	# ซ่อนหน้า Game Over ไว้ก่อนตอนเริ่มเกม
	hide()
	
	# เชื่อมต่อปุ่มกด
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)

func show_game_over(final_score: int):
	show()
	
	# แสดงคะแนนสุดท้ายที่ทำได้
	if score_label:
		score_label.text = "FINAL SCORE: " + str(final_score)
		
	# เล่นเสียง Game Over
	if game_over_sound and game_over_sound.stream:
		game_over_sound.play()

func _on_restart_button_pressed():
	# รีเซ็ตค่าใน GameManager ก่อนเริ่มเกมใหม่
	GameManager.reset_game_state()
	
	# โหลด Scene ปัจจุบันใหม่ (Restart)
	get_tree().reload_current_scene()

func _on_menu_button_pressed():
	# รีเซ็ตค่าใน GameManager
	GameManager.reset_game_state()
	
	# เปลี่ยนไป Scene หน้า Main Menu (แก้ไข path ให้ตรงกับไฟล์ในโปรเจกต์ของคุณ)
	get_tree().change_scene_to_file("res://Main/MainMenu.tscn")
