extends Node

const MENU_THEME := preload("res://Assets/Audio/Music/menu_theme.mp3")
const GAMEPLAY_THEME := preload("res://Assets/Audio/Music/combat_theme.mp3")

const MENU_VOLUME_DB := -8.0
const GAMEPLAY_VOLUME_DB := -7.0
const SILENCE_DB := -60.0
const MIN_PITCH := 0.94
const MAX_PITCH := 1.16
const CROSSFADE_SECONDS := 1.6

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _active_gameplay := false
var _intensity := 0.0
var _target_intensity := 0.0
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_player = _make_player(MENU_THEME)
	_game_player = _make_player(GAMEPLAY_THEME)

func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = SILENCE_DB
	if stream is AudioStreamMP3:
		stream.loop = true
	player.finished.connect(func(): player.play())
	add_child(player)
	return player

func play_menu() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_active_gameplay = false
	_target_intensity = 0.0
	_intensity = 0.0
	_game_player.pitch_scale = 1.0
	if not _menu_player.playing:
		_menu_player.play()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(_menu_player, "volume_db", MENU_VOLUME_DB, CROSSFADE_SECONDS)
	_fade_tween.tween_property(_game_player, "volume_db", SILENCE_DB, CROSSFADE_SECONDS)
	_fade_tween.chain().tween_callback(_game_player.stop)

func play_combat() -> void:
	play_gameplay()

func play_gameplay() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_active_gameplay = true
	_target_intensity = 0.25
	if not _game_player.playing:
		_game_player.pitch_scale = _pitch_for_intensity(_target_intensity)
		_game_player.play()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(_game_player, "volume_db", GAMEPLAY_VOLUME_DB, CROSSFADE_SECONDS)
	_fade_tween.tween_property(_menu_player, "volume_db", SILENCE_DB, CROSSFADE_SECONDS)
	_fade_tween.chain().tween_callback(_menu_player.stop)

func play_death() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_active_gameplay = false
	_target_intensity = 0.0
	_intensity = 0.0
	if not _game_player.playing:
		return
	_fade_tween = create_tween()
	_fade_tween.set_parallel()
	_fade_tween.tween_property(_game_player, "pitch_scale", 0.78, 1.1)
	_fade_tween.tween_property(_game_player, "volume_db", SILENCE_DB, 1.4)
	_fade_tween.chain().tween_callback(func():
		_game_player.stop()
		_game_player.pitch_scale = 1.0
		play_menu())

func pause_to_menu() -> void:
	play_menu()

func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	if not _active_gameplay:
		return
	_intensity = lerpf(_intensity, _target_intensity, 1.0 - exp(-1.8 * delta))
	_game_player.pitch_scale = _pitch_for_intensity(_intensity)

func _pitch_for_intensity(value: float) -> float:
	return lerpf(MIN_PITCH, MAX_PITCH, clampf(value, 0.0, 1.0))
