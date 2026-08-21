extends Node

@onready var conductor = $Conductor
@onready var track_manager = $TrackManager
@onready var camera = $Camera2D
@onready var image_bg = $ImageBackground
@onready var video_bg = $VideoBackground
@onready var rating_label = $CanvasLayer/RatingLabel
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var multiplier_label = $CanvasLayer/MultiplierLabel
@onready var bonus_label = $CanvasLayer/BonusLabel
@onready var health_bar = $CanvasLayer/HealthBar
@onready var target_score_label = $CanvasLayer/TargetScoreLabel

var victory_ui_scene = preload("res://Main/VictoryUI.tscn")
var game_over_scene = preload("res://Main/GameOverUI.tscn")

var victory_ui_instance = null
var game_over_ui_instance = null

var shake_intensity : float = 0.0
var shake_decay : float = 15.0
var is_game_over : bool = false
var is_song_ended : bool = false

func _ready():
	# 1. รีเซ็ตสถานะเกม (คะแนน, หลอดเลือด, คอมโบ)
	GameManager.reset_game_state()
	
	# 2. ดึงข้อมูลเพลงปัจจุบันจาก GameManager
	var song_data = GameManager.get_current_song_data()
	
	# 3. เชื่อมต่อ Signal วิดีโอพื้นหลัง (ถ้ามี)
	if video_bg:
		if not video_bg.finished.is_connected(_on_video_finished):
			video_bg.finished.connect(_on_video_finished)
	
	# 4. โหลดและแสดงวิดีโอ/ภาพพื้นหลัง
	_setup_background(song_data)
	
	# 5. ตั้งค่า Breaking Point สำหรับคะแนน
	GameManager.breaking_point = song_data.get("breaking_point", 3000)
	
	# 6. ตั้งค่า Audio Stream และ BPM ให้ Conductor
	if conductor and conductor.music_player:
		var stream_p = song_data.get("stream_path", "")
		if ResourceLoader.exists(stream_p):
			conductor.music_player.stream = load(stream_p)
			conductor.bpm = song_data.get("bpm", 120)
			
			# เชื่อมต่อ Signal เมื่อเพลงเล่นจบ
			if not conductor.music_player.finished.is_connected(_on_song_finished):
				conductor.music_player.finished.connect(_on_song_finished)
		else:
			print("[ERROR MAIN] Music file NOT found at: ", stream_p)
		
	# 7. เชื่อม Conductor เข้ากับ TrackManager
	if track_manager and conductor:
		track_manager.conductor = conductor

	# 8. ส่ง Beatmap Path ไปให้ TrackManager โหลดโน้ต
	var b_path = song_data.get("beatmap_path", "")
	print("[DEBUG MAIN] Sending Beatmap Path: ", b_path)
	if track_manager and track_manager.has_method("load_beatmap"):
		track_manager.load_beatmap(b_path)

	# 9. สั่งเล่นเพลงผ่าน Conductor
	if conductor:
		conductor.play_song()
	
	# 10. เชื่อมต่อ Signals ทั้งหมดจาก GameManager มายัง UI ของ Main
	if not GameManager.hit_evaluated.is_connected(_on_hit_evaluated):
		GameManager.hit_evaluated.connect(_on_hit_evaluated)
	if not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
	if not GameManager.health_updated.is_connected(_on_health_updated):
		GameManager.health_updated.connect(_on_health_updated)
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	
	# 11. อัปเดต UI ตั้งต้น (หลอดเลือด และ คะแนน) ทันทีที่เข้าฉาก
	_on_health_updated(GameManager.current_health, GameManager.max_health)
	_on_score_updated(GameManager.score, GameManager.multiplier, GameManager.total_bonus_score)

func _setup_background(song_data: Dictionary):
	print("\n--- [DEBUG BACKGROUND SYSTEM] ---")
	print("Song Selected: ", song_data.get("title", "Unknown"))
	
	if image_bg: image_bg.hide()
	if video_bg: 
		video_bg.stop()
		video_bg.hide()
	
	var bg_type = str(song_data.get("bg_type", "none")).to_lower()
	var bg_path = song_data.get("bg_path", "")
	print("BG Type: ", bg_type, " | Path: ", bg_path)
	
	if bg_type == "image":
		if ResourceLoader.exists(bg_path):
			image_bg.texture = load(bg_path)
			image_bg.show()
			print("Status: Image loaded successfully.")
		else:
			print("ERROR: Image file NOT found at: ", bg_path)
			
	elif bg_type == "video":
		if not video_bg:
			print("ERROR: Node 'VideoBackground' is NULL!")
			return
			
		if ResourceLoader.exists(bg_path):
			var stream = load(bg_path)
			if stream is VideoStream:
				video_bg.stream = stream
				video_bg.show()
				video_bg.play()
				print("Is Playing Video? -> ", video_bg.is_playing())
				print("Status: Video started successfully.")
			else:
				print("ERROR: Loaded file is NOT a valid VideoStream resource!")
		else:
			print("ERROR: Video file NOT found at: ", bg_path)
			
	print("-----------------------------------\n")

func _on_video_finished():
	print("[DEBUG VIDEO] Video finished playing.")

func _notification(what):
	if what == NOTIFICATION_PAUSED:
		if video_bg and video_bg.visible:
			video_bg.paused = true
	elif what == NOTIFICATION_UNPAUSED:
		if video_bg and video_bg.visible:
			video_bg.paused = false

func _on_song_finished():
	print("[DEBUG MAIN] Song Finished! Instantiating Victory UI...")
	
	# 1. บันทึกและดึงข้อมูลคะแนน
	var is_new_record = GameManager.check_and_save_high_score()
	var current_hs = GameManager.get_high_score_for_song(GameManager.selected_song_key)
	
	# 2. สร้าง Node VictoryUI ขึ้นมาจาก Scene
	if victory_ui_scene:
		victory_ui_instance = victory_ui_scene.instantiate()
		add_child(victory_ui_instance)
		
		# 3. เรียกฟังก์ชัน show_victory() ของ VictoryUI เพื่อสั่ง show() และใส่ค่าคะแนน
		if victory_ui_instance.has_method("show_victory"):
			victory_ui_instance.show_victory(GameManager.score, current_hs, is_new_record)
		else:
			victory_ui_instance.show()
	else:
		print("[ERROR MAIN] victory_ui_scene is NULL!")

func _on_game_over():
	is_game_over = true
	if conductor and conductor.music_player:
		conductor.music_player.stop()
		
	if video_bg:
		video_bg.stop()
		
	for child in track_manager.get_children():
		if child is Area2D:
			child.queue_free()
			
	_show_game_over_screen()

func _show_game_over_screen():
	if game_over_scene:
		game_over_ui_instance = game_over_scene.instantiate()
		add_child(game_over_ui_instance)
		if game_over_ui_instance.has_method("show_game_over"):
			game_over_ui_instance.show_game_over(GameManager.score)

func _on_hit_evaluated(rating: String):
	if is_game_over or is_song_ended: 
		return
		
	if rating_label:
		rating_label.text = rating
		match rating:
			"PERFECT": 
				rating_label.modulate = Color.YELLOW
				trigger_shake(8.0)
			"GOOD": 
				rating_label.modulate = Color.GREEN
				trigger_shake(4.0)
			"MISS": 
				rating_label.modulate = Color.RED

func trigger_shake(amount: float):
	shake_intensity = amount

func _on_score_updated(score: int, multiplier: int, bonus_score: int):
	if score_label:
		score_label.text = "SCORE: " + str(score)
		
	if target_score_label:
		if score >= GameManager.breaking_point:
			target_score_label.text = "TARGET: PASSED!"
			target_score_label.modulate = Color.GREEN
		else:
			target_score_label.text = "TARGET: " + str(GameManager.breaking_point)
			target_score_label.modulate = Color.WHITE

	if multiplier > 1:
		if multiplier_label:
			multiplier_label.visible = true
			multiplier_label.text = "MULT: x" + str(multiplier)
		if bonus_label:
			bonus_label.visible = true
			bonus_label.text = "BONUS: +" + str(bonus_score)
	else:
		if multiplier_label: multiplier_label.visible = false
		if bonus_label: bonus_label.visible = false

func _on_health_updated(current_hp: float, max_hp: float):
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
