extends Node

const SOUNDS := {
	"enemy_kill": preload("res://Assets/Audio/SFX/enemy_kill.mp3"),
	"enemy_hit": preload("res://Assets/Audio/SFX/enemy_hit.mp3"),
	"trampoline_place": preload("res://Assets/Audio/SFX/trampoline_place.wav"),
	"trampoline_launch": preload("res://Assets/Audio/SFX/trampoline_launch.wav"),
	"stomp_impact": preload("res://Assets/Audio/SFX/stomp_impact.wav"),
	"jump": preload("res://Assets/Audio/SFX/jump.wav"),
	"dash": preload("res://Assets/Audio/SFX/dash.wav"),
	"player_damage": preload("res://Assets/Audio/SFX/player_damage.wav"),
	"player_death": preload("res://Assets/Audio/SFX/player_death.wav"),
	"ui_click": preload("res://Assets/Audio/SFX/ui_click.wav"),
	"wave_clear": preload("res://Assets/Audio/SFX/wave_clear.wav"),
	"success": preload("res://Assets/Audio/SFX/success.wav"),
}

var _players: Array[AudioStreamPlayer] = []
var _next_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 10:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func play(name: String, volume_db: float = -8.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(name):
		return
	var player := _players[_next_index]
	_next_index = (_next_index + 1) % _players.size()
	player.stream = SOUNDS[name]
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch * randf_range(0.96, 1.04), 0.5, 2.0)
	player.play()
