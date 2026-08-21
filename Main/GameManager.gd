extends Node

# --- SIGNALS ---
signal score_updated(score, multiplier, bonus_score)
signal combo_updated(combo)
signal hit_evaluated(rating)
signal health_updated(current_health, max_health)
signal game_over

# --- GAME METRICS ---
var score : int = 0
var combo : int = 0
var multiplier : int = 1
var total_bonus_score : int = 0

# --- HEALTH SYSTEM ---
var max_health : float = 100.0
var current_health : float = 100.0

# --- HIGH SCORE & GAME STATE ---
var breaking_point : int = 3000
var is_new_high_score : bool = false
const SAVE_PATH = "user://highscore.cfg"
var high_scores : Dictionary = {}

# --- SONG LIBRARY ---
var song_library = {
	"song1": {
		"title": "Tu Cuu Mon Hoi Uc BT REMIX",
		"stream_path": "res://Audio/Song/Tu Cuu Mon Hoi Uc.mp3",
		"beatmap_path": "res://Audio/beatmap/tucuumonhoiuc.json",
		"bg_type": "video",
		"bg_path": "res://Background/Tu Cuu Mon Hoi Uc BT REMIX.ogv",
		"bpm": 140,
		"breaking_point": 3000,
		"preview_start": 30.0
	},
	"song2": {
		"title": "freaked out (RJ Pasin remix)",
		"stream_path": "res://Audio/Song/freaked out (RJ Pasin remix).mp3",
		"beatmap_path": "res://Audio/beatmap/freaked out.json",
		"bg_type": "video",
		"bg_path": "res://Background/reaked-out-_RJ-Pasin-remix_-ptasinski_-RJ-Pasin.ogv",
		"bpm": 85,
		"breaking_point": 5000,
		"preview_start": 5.0
	},
	"song3": {
		"title": "JENNIE - Seoul City",
		"stream_path": "res://Audio/Song/JENNIE - Seoul City (Official Video).mp3",
		"beatmap_path": "res://Audio/beatmap/seoulcity.json",
		"bg_type": "video",
		"bg_path": "res://Background/JENNIE-Seoul-City-_Official-Video_.ogv",
		"bpm": 77,
		"breaking_point": 5000,
		"preview_start": 25.0
	},
	"song4": {
		"title": "XAIDARK ARIA - Hiroyuki SAWANO",
		"stream_path": "res://Audio/Song/Hiroyuki SAWANO feat. XAIDARK ARIALyric Video from俺だけレベルアップな件.mp3",
		"beatmap_path": "res://Audio/beatmap/aria.json",
		"bg_type": "video",
		"bg_path": "res://Background/Hiroyuki SAWANO feat. XAI『DARK ARIA』Lyric Video from『Solo Leveling 』.ogv",
		"bpm": 80,
		"breaking_point": 5000,
		"preview_start": 43.0
	}
}

var selected_song_key : String = "song1"

func _ready():
	load_high_scores()

# --- RESET GAME STATE ---
func reset_game_state():
	score = 0
	combo = 0
	multiplier = 1
	total_bonus_score = 0
	current_health = max_health
	is_new_high_score = false
	
	score_updated.emit(score, multiplier, total_bonus_score)
	health_updated.emit(current_health, max_health)
	combo_updated.emit(combo)

# --- REGISTER HIT & SCORE LOGIC ---
func register_hit(rating: String, _note_type: String = "normal"):
	var upper_rating = rating.to_upper()
	
	match upper_rating:
		"PERFECT":
			var base_score = 1000 * multiplier
			var bonus = 200
			total_bonus_score += bonus
			score += base_score + bonus
			combo += 1
			# รีเจนเลือดเพิ่มเล็กน้อยเมื่อกดได้ Perfect
			current_health = min(current_health + 1.0, max_health)
			
		"GREAT":
			var base_score = 700 * multiplier
			var bonus = 100
			total_bonus_score += bonus
			score += base_score + bonus
			combo += 1
			
		"GOOD":
			score += 400 * multiplier
			combo += 1
			
		"OK":
			score += 200 * multiplier
			combo += 1
			
		"MISS":
			combo = 0
			multiplier = 1
			
			# หักเลือดเมื่อ MISS (10 หน่วย)
			current_health = max(0.0, current_health - 10.0)
			
			print("[GM DEBUG] Current Health after MISS: ", current_health)
			
			hit_evaluated.emit(upper_rating)
			combo_updated.emit(combo)
			score_updated.emit(score, multiplier, total_bonus_score)
			health_updated.emit(current_health, max_health)
			
			if current_health <= 0:
				game_over.emit()
			return

	calculate_multiplier()

	hit_evaluated.emit(upper_rating)
	combo_updated.emit(combo)
	score_updated.emit(score, multiplier, total_bonus_score)
	health_updated.emit(current_health, max_health)

func calculate_multiplier():
	if combo >= 40:
		multiplier = 4
	elif combo >= 20:
		multiplier = 3
	elif combo >= 10:
		multiplier = 2
	else:
		multiplier = 1

# --- SONG DATA & HIGH SCORE ---
func select_song(key: String):
	if song_library.has(key):
		selected_song_key = key

func get_current_song_data() -> Dictionary:
	return song_library.get(selected_song_key, {})

func get_high_score_for_song(song_key: String) -> int:
	return high_scores.get(song_key, 0)

func check_and_save_high_score() -> bool:
	var current_hs = get_high_score_for_song(selected_song_key)
	if score > current_hs:
		high_scores[selected_song_key] = score
		is_new_high_score = true
		save_high_scores()
		return true
	return false

func save_high_scores():
	var config = ConfigFile.new()
	for key in high_scores.keys():
		config.set_value("HighScores", key, high_scores[key])
	config.save(SAVE_PATH)

func load_high_scores():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		if config.has_section("HighScores"):
			for key in config.get_section_keys("HighScores"):
				high_scores[key] = config.get_value("HighScores", key, 0)
