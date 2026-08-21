extends Node2D

@export var conductor : Node
@export var note_scene : PackedScene

@onready var hit_line = $HitLine

@onready var lane_positions = [
	$Lanes/Lane1,
	$Lanes/Lane2,
	$Lanes/Lane3,
	$Lanes/Lane4
]

var lane_actions = ["key_left", "key_up", "key_down", "key_right"]

var base_chart : Array = []
var active_chart : Array = []
var active_notes : Array = []

var note_speed : float = 600.0
var hit_line_y : float = 900.0
var spawn_y : float = -100.0

func _ready():
	if hit_line:
		hit_line_y = hit_line.global_position.y

func load_beatmap(path: String):
	print("\n--- [DEBUG TRACK MANAGER LOAD] ---")
	print("Loading beatmap path: ", path)
	
	if path == "" or not FileAccess.file_exists(path):
		print("[ERROR TRACK] Beatmap file NOT found or path is empty! Path: ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result == OK:
		var raw_data = json.data
		var notes_list: Array = []
		
		# เช็คว่าโครงสร้าง JSON เป็น Array หรือ Dictionary
		if raw_data is Array:
			notes_list = raw_data
		elif raw_data is Dictionary:
			notes_list = raw_data.get("notes", [])
			
		base_chart = notes_list.duplicate(true)
		print("[SUCCESS TRACK] Beatmap loaded! Total notes: ", base_chart.size())
		
		# รีเซ็ตและจัดคิวเตรียมพร้อมสำหรับเล่น
		reset_chart_queue()
	else:
		print("[ERROR TRACK] Failed to parse JSON Beatmap! Line: ", json.get_error_line())
	print("-----------------------------------\n")

func reset_chart_queue():
	# ล้างโน้ตเก่าที่อาจค้างอยู่ในฉากออกก่อน
	clear_all_spawned_notes()
	
	active_chart = base_chart.duplicate(true)
	# เรียงลำดับเวลาโน้ตจากน้อยไปมาก
	active_chart.sort_custom(func(a, b): return a[0] < b[0])

func _process(delta):
	if not conductor:
		#print("[TRACK DEBUG] Conductor is NULL!")
		return
	if not conductor.music_player:
		#print("[TRACK DEBUG] Music Player is NULL!")
		return
	if not conductor.music_player.playing:
		#print("[TRACK DEBUG] Music Player is NOT playing!")
		return
		
	var current_song_time = conductor.song_position
	# print("Current Song Time: ", current_song_time) # ลองปลดดูว่าเวลาเดินไหม
	check_and_spawn_notes(current_song_time)

func check_and_spawn_notes(current_song_time: float):
	var travel_time = (hit_line_y - spawn_y) / note_speed
	
	# ปรินท์ดูว่าตอนนี้รอเวลาอะไรอยู่ (เปิดดูแป๊บเดียวแล้วค่อยคอมเมนต์ปิด)
	if active_chart.size() > 0:
		var next_note_time = active_chart[0][0]
		var spawn_trigger_time = next_note_time - travel_time
		# print("Song Time: ", current_song_time, " | Target Spawn Time: ", spawn_trigger_time)

	while active_chart.size() > 0 and (active_chart[0][0] - travel_time) <= current_song_time:
		print("[TRACK] Spawning note at lane: ", active_chart[0][1])
		var note_data = active_chart.pop_front()
		
		var lane_index = int(note_data[1])
		var type = str(note_data[2])
		var duration = 0.0
		
		if note_data.size() >= 4:
			duration = float(note_data[3])
			
		spawn_note(lane_index, type, duration)

func spawn_note(lane_index: int, type: String, duration: float = 0.0):
	if note_scene == null:
		print("[ERROR TRACK] note_scene is NULL! Please assign Note Scene in Inspector.")
		return
		
	if lane_index < 0 or lane_index >= lane_positions.size():
		print("[ERROR TRACK] Lane index out of bounds: ", lane_index)
		return

	var new_note = note_scene.instantiate()
	
	# ตั้งค่าตำแหน่งเริ่มต้น
	var lane_x = lane_positions[lane_index].position.x
	new_note.position = Vector2(lane_x, spawn_y)
	
	# กำหนดคุณสมบัติให้ตัวโน้ต
	if "speed" in new_note:
		new_note.speed = note_speed
	if "note_type" in new_note:
		new_note.note_type = type
	if "target_action" in new_note:
		new_note.target_action = lane_actions[lane_index]
	
	# ตั้งค่าความยาว Hold Note (หากตัวโน้ตมีฟังก์ชันนี้)
	if new_note.has_method("setup_hold_note"):
		new_note.setup_hold_note(duration)
	
	add_child(new_note)
	active_notes.append(new_note)

func clear_all_spawned_notes():
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
