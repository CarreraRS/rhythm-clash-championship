extends CanvasLayer

var score_label : Label
var high_score_label : Label
var restart_button : Button
var next_button : Button

func _ready():
	hide()
	score_label = find_child("ScoreLabel", true, false) as Label
	high_score_label = find_child("HighScoreLabel", true, false) as Label
	restart_button = find_child("RestartButton", true, false) as Button
	next_button = find_child("NextButton", true, false) as Button
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)

func show_victory(final_score: int, high_score: int, is_new_high_score: bool):
	show()
	if score_label:
		score_label.text = "FINAL SCORE: " + str(final_score)
		
	if high_score_label:
		if is_new_high_score:
			high_score_label.text = "NEW HIGH SCORE: " + str(high_score) + " 🎉"
			high_score_label.modulate = Color.YELLOW
		else:
			high_score_label.text = "HIGH SCORE: " + str(high_score)
			high_score_label.modulate = Color.WHITE

func _on_restart_button_pressed():
	GameManager.reset_game_state()
	get_tree().reload_current_scene()

func _on_next_button_pressed():
	GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Main/MainMenu.tscn")
