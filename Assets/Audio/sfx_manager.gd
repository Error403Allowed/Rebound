extends Node

const ENEMY_DEATH := preload("res://Assets/Audio/SFX/enemy_kill.mp3")

var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -6.0
	add_child(_player)

func play_enemy_death() -> void:
	_player.stream = ENEMY_DEATH
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()
