extends Area2D

@export var speed : float = 600.0
@export var target_action : String = "key_left"
@export var note_type : String = "normal"
@export var hold_duration : float = 0.0

@onready var lane_label = $Label 

var is_active : bool = false
var is_hit : bool = false
var is_hold_note : bool = false
var is_holding : bool = false
var hold_timer : float = 0.0
var hit_line_ref : Area2D = null
var hold_second_tracker : float = 0.0

func _ready():
	setup_label()

func setup_label():
	if lane_label == null: 
		return
		
	match target_action:
		"key_left": lane_label.text = "A"
		"key_up": lane_label.text = "W"
		"key_down": lane_label.text = "S"
		"key_right": lane_label.text = "D"
		_: lane_label.text = "?"

func setup_hold_note(duration: float):
	hold_duration = duration
	if hold_duration >= 0.2:
		is_hold_note = true
		note_type = "hold"
		
		var calculated_height = hold_duration * speed
		
		var col_node = get_node_or_null("CollisionShape2D")
		if col_node and col_node.shape is RectangleShape2D:
			var col_shape = col_node.shape.duplicate() as RectangleShape2D
			col_shape.size.y = calculated_height
			col_node.shape = col_shape
			col_node.position.y = -calculated_height / 2.0
			
		if has_node("ColorRect"):
			var rect = $ColorRect
			rect.size.y = calculated_height
			rect.position.y = -calculated_height

func _process(delta):
	position.y += speed * delta
	
	if is_holding:
		hold_timer += delta
		hold_second_tracker += delta
		modulate.a = 0.5
		
		if hold_second_tracker >= 1.0:
			hold_second_tracker -= 1.0
			if GameManager.has_method("add_hold_tick_combo"):
				GameManager.add_hold_tick_combo()
		
		if hold_timer >= hold_duration:
			is_holding = false
			GameManager.register_hit("PERFECT", note_type)
			queue_free()

func _input(event):
	if event.is_action_pressed(target_action) and is_active and not is_hit:
		if is_hold_note:
			start_hold()
		else:
			evaluate_hit_box()
			
	if event.is_action_released(target_action) and is_holding:
		fail_hold()

func start_hold():
	is_holding = true
	is_hit = true
	GameManager.register_hit("PERFECT", note_type)

func fail_hold():
	is_holding = false
	GameManager.register_hit("MISS")
	queue_free()

# 1. เมื่อโน้ตเข้ามาทับ HitLine ให้พร้อมกด
func _on_area_entered(area):
	if area.name == "HitLine":
		is_active = true
		hit_line_ref = area

# 2. เมื่อโน้ตวิ่งหลุดออกจาก HitLine ไปแล้ว (และผู้เล่นไม่ได้กด)
func _on_area_exited(area):
	if area.name == "HitLine":
		is_active = false
		# เช็คว่าถ้าโน้ตวิ่งผ่านไปโดยที่ส่วนกลางของโน้ตอยู่ต่ำกว่าสาย HitLine จริงๆ ถึงจะคิด MISS
		if not is_hit and not is_holding:
			if hit_line_ref and global_position.y > hit_line_ref.global_position.y:
				is_hit = true
				if note_type != "fake":
					GameManager.register_hit("MISS")
				queue_free()

func evaluate_hit_box():
	is_hit = true
	
	if note_type == "fake":
		if GameManager.has_method("register_fake_note_hit"):
			GameManager.register_fake_note_hit()
		queue_free()
		return

	if hit_line_ref != null:
		var overlap_percentage = get_vertical_overlap_percentage(hit_line_ref)
		
		if overlap_percentage >= 80.0:
			GameManager.register_hit("PERFECT", note_type)
		elif overlap_percentage >= 30.0:
			GameManager.register_hit("GOOD", note_type)
		else:
			GameManager.register_hit("MISS")
	else:
		GameManager.register_hit("MISS")
			
	queue_free()

func get_vertical_overlap_percentage(target_area: Area2D) -> float:
	var note_col = get_node_or_null("CollisionShape2D")
	var target_col = target_area.get_node_or_null("CollisionShape2D")
	
	if not note_col or not target_col:
		return 0.0

	var note_shape = note_col.shape as RectangleShape2D
	var target_shape = target_col.shape as RectangleShape2D
	
	if not note_shape or not target_shape:
		return 0.0

	var note_y = note_col.global_position.y
	var target_y = target_col.global_position.y
	
	var note_height = note_shape.size.y * note_col.global_scale.y
	var target_height = target_shape.size.y * target_col.global_scale.y

	var note_top = note_y - (note_height / 2.0)
	var note_bottom = note_y + (note_height / 2.0)

	var target_top = target_y - (target_height / 2.0)
	var target_bottom = target_y + (target_height / 2.0)

	var overlap_top = max(note_top, target_top)
	var overlap_bottom = min(note_bottom, target_bottom)
	var overlap_height = max(0.0, overlap_bottom - overlap_top)

	var percentage = (overlap_height / note_height) * 100.0
	return min(percentage, 100.0)
