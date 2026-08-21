extends Node

@onready var music_player = $MusicPlayer

var recorded_chart = []
var key_press_times = {}

var lane_keys = {
	"key_left": 0,
	"key_up": 1,
	"key_down": 2,
	"key_right": 3
}

func _ready():
	if music_player and music_player.stream:
		music_player.play()

func _input(event):
	# 1. ระบบกด Enter เพื่อ Save Beatmap
	if event.is_action_pressed("ui_accept"): # ui_accept คือปุ่ม Enter หรือ Spacebar
		save_beatmap("res://beatmap.json")
		return

	if not music_player.playing:
		return
		
	var current_time = music_player.get_playback_position()
	
	for action in lane_keys.keys():
		var lane_index = lane_keys[action]
		
		# เมื่อเริ่มกดปุ่ม
		if event.is_action_pressed(action) and not event.is_echo():
			key_press_times[action] = current_time
			
		# เมื่อปล่อยปุ่ม
		elif event.is_action_released(action) and key_press_times.has(action):
			var start_time = key_press_times[action]
			var duration = current_time - start_time
			key_press_times.erase(action)
			
			if duration < 0.2:
				recorded_chart.append([start_time, lane_index, "normal", 0.0])
				print("Recorded Normal Note | Time: ", start_time, " | Lane: ", lane_index)
			else:
				recorded_chart.append([start_time, lane_index, "hold", duration])
				print("Recorded Hold Note | Time: ", start_time, " | Lane: ", lane_index, " | Duration: ", duration)

func save_beatmap(file_path: String = "res://beatmap.json"):
	if recorded_chart.size() == 0:
		print("Warning: No notes recorded to save!")
		return

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(recorded_chart, "\t")
		file.store_string(json_string)
		file.close()
		print("--- SUCCESS: Saved ", recorded_chart.size(), " notes to ", file_path, " ---")
	else:
		print("Error: Could not open file for writing at ", file_path)
