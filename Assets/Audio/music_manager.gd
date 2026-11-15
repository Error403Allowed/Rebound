extends Node

const MENU_THEME := preload("res://Assets/Audio/Music/menu_theme.mp3")
const COMBAT_THEME := preload("res://Assets/Audio/Music/combat_theme.mp3")
const DANGER_THEME := preload("res://Assets/Audio/Music/danger_theme.mp3")

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current: AudioStream = null
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -60.0
		add_child(player)
		_players.append(player)

func play_menu() -> void:
	_crossfade_to(MENU_THEME)

func play_combat() -> void:
	_crossfade_to(COMBAT_THEME)

func play_danger() -> void:
	_crossfade_to(DANGER_THEME)

func stop_music() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	for player in _players:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, 0.8)
		tween.tween_callback(player.stop)
	_current = null

func _crossfade_to(stream: AudioStream) -> void:
	if _current == stream:
		return
	_current = stream
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var incoming := _players[1 - _active]
	var outgoing := _players[_active]
	_active = 1 - _active
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(incoming, "volume_db", -6.0, 1.2)
	_fade_tween.tween_property(outgoing, "volume_db", -60.0, 1.2)
	_fade_tween.chain().tween_callback(outgoing.stop)
