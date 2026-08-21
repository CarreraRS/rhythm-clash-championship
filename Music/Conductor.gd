extends Node

@export var bpm : float = 120.0

var sec_per_beat : float = 0.0
var song_position : float = 0.0
var song_position_in_beats : float = 0.0

@onready var music_player = $MusicPlayer

func _ready():
	sec_per_beat = 60.0 / bpm

func _process(_delta):
	if music_player and music_player.playing:
		song_position = music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()
		song_position_in_beats = song_position / sec_per_beat

func play_song():
	if music_player and music_player.stream:
		music_player.play()
	else:
		print("Error: MusicPlayer or Sound Stream is missing!")
