extends Node

const ENEMY_DEATH := preload("res://Assets/Audio/SFX/enemy_kill.mp3")
const PLAYER_HIT_PATH := "res://Assets/Audio/SFX/player_hit.mp3"

var _player: AudioStreamPlayer
var _hit_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -6.0
	add_child(_player)
	_hit_player = AudioStreamPlayer.new()
	_hit_player.bus = "Master"
	_hit_player.volume_db = -7.0
	add_child(_hit_player)

func play_player_hit() -> void:
	_hit_player.stream = load(PLAYER_HIT_PATH)
	_hit_player.pitch_scale = randf_range(0.92, 1.08)
	_hit_player.play()

func play_enemy_death() -> void:
	_player.stream = ENEMY_DEATH
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()
