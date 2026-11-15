extends Node

@export var enemy_scene: PackedScene
@export var world_size := 65.0

@export_group("Waves")
@export var first_wave_delay := 5.0
@export var time_between_waves := 6.0
@export var base_count := 5
@export var count_per_wave := 3
@export var max_alive := 25
@export var heal_between_waves := 0
@export_range(0.1, 1.0, 0.05) var clear_fraction := 0.5   # share of a wave you must kill to move on

@export_group("Spawning")
@export var spawn_edge_inset := 2.0
@export var min_spawn_distance := 8.0
@export var score_per_kill := 10
@export var coins_per_kill := 1
@export var score_per_wave := 100
@export var coins_per_wave := 5

var wave := 0
var to_spawn := 0
var alive := 0
var kills := 0
var wave_total := 0         # enemies this wave was going to spawn
var wave_needed := 0        # kills required to clear it
var wave_kills := 0         # kills of this wave's own enemies
var score := 0
var currency := 0
var game_over := false
var in_break := true
var break_timer := 0.0
var spawn_timer := 0.0
var spawn_interval := 1.0
var speedy_chance := 0.0

var player: Node3D
var info: Label
var banner: Label
var banner_tween: Tween
var results: PanelContainer
var results_title: Label
var results_stats: Label
var restart_button: Button
var resume_button: Button
var pause_active := false
var run_id := 0
var banked := false
var bank_error: int = OK
var new_best := false
var waves_cleared := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run_id = Progression.begin_run()
	break_timer = first_wave_delay
	_build_hud()
	player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)


func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		return
	if in_break:
		break_timer -= delta
		if break_timer <= 0.0:
			_start_wave()
	else:
		# enough of the wave is dead: move on, even if some enemies are still alive
		_update_music()
		if wave_kills >= wave_needed:
			_end_wave()
		elif to_spawn > 0 and alive < max_alive:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy()
				to_spawn -= 1
				alive += 1
				spawn_timer = spawn_interval
	_update_hud()


func _update_music() -> void:
	if player == null:
		return
	var danger := alive >= 7 or wave >= 8 or float(player.health) / maxf(1.0, float(player.max_health)) < 0.35
	if danger:
		MusicManager.play_danger()
	else:
		MusicManager.play_combat()

func _start_wave() -> void:
	wave += 1
	in_break = false
	to_spawn = base_count + wave * count_per_wave
	wave_total = to_spawn
	wave_needed = maxi(1, ceili(wave_total * clear_fraction))
	wave_kills = 0
	spawn_interval = maxf(0.25, 1.2 - wave * 0.08)
	speedy_chance = clampf((wave - 1) * 0.1, 0.0, 0.5)
	spawn_timer = 0.0
	_show_banner("WAVE %d" % wave)


func _end_wave() -> void:
	waves_cleared += 1
	in_break = true
	break_timer = time_between_waves
	to_spawn = 0               # enemies not spawned yet are dropped; ones already alive stay
	score += score_per_wave
	_award_xp(coins_per_wave)
	_show_banner("WAVE %d CLEARED" % wave)
	if heal_between_waves > 0 and player != null:
		player.health = mini(player.health + heal_between_waves, player.max_health)


func _pick_type() -> int:
	if randf() < speedy_chance:
		return Enemy.Type.SPEEDY
	return Enemy.Type.BASIC


func _pick_role() -> int:
	var roll := randf()
	if wave >= 7 and roll < 0.2:
		return Enemy.Role.CHARGER
	if wave >= 5 and roll < 0.45:
		return Enemy.Role.FLANKER
	if wave >= 3 and roll < 0.7:
		return Enemy.Role.DODGER
	return Enemy.Role.CHASER


func _spawn_point() -> Vector3:
	var limit := world_size / 2.0 - spawn_edge_inset
	var point := Vector3.ZERO
	for attempt in 20:
		var value := randf_range(-limit, limit)
		match randi() % 4:
			0: point = Vector3(value, 0.1, -limit)
			1: point = Vector3(value, 0.1, limit)
			2: point = Vector3(-limit, 0.1, value)
			_: point = Vector3(limit, 0.1, value)
		if player == null:
			return point
		var flat := Vector2(point.x - player.global_position.x, point.z - player.global_position.z)
		if flat.length() >= min_spawn_distance:
			return point
	return point


func _spawn_enemy() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	var enemy := Enemy.new()
	enemy.type = _pick_type() as Enemy.Type
	enemy.role = _pick_role() as Enemy.Role
	enemy.health = 1 + mini(3, int(wave / 6.0))
	enemy.set_meta("wave", wave)                      # remembers which wave it belongs to
	enemy.died.connect(_on_enemy_died.bind(enemy))
	add_child(enemy)
	enemy.global_position = _spawn_point()


func _on_enemy_died(_enemy_type: int, enemy: Node) -> void:
	alive = maxi(0, alive - 1)
	kills += 1
	score += score_per_kill
	_award_xp(coins_per_kill)
	# only kills of the current wave's own enemies count toward clearing it,
	# so stragglers from an earlier wave don't speed up the next one
	if not in_break and int(enemy.get_meta("wave", 0)) == wave:
		wave_kills += 1


func _on_player_died() -> void:
	game_over = true
	bank_run()
	pause_active = false
	get_tree().paused = true
	resume_button.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results_title.text = "GAME OVER"
	results_stats.text = "Score: %d\nWave reached: %d\nEnemies defeated: %d\nRun XP: %d\n\nXP is credited as it is earned." % [score, wave, kills, currency]
	results.show()
	restart_button.grab_focus()
	results.hide()
	UIManager.show_results()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# wave info: full-width strip across the top, text centred, so it stays top middle at any resolution
	info = Label.new()
	info.custom_minimum_size = Vector2(0, 34)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_top = 12
	info.offset_bottom = 46
	layer.add_child(info)

	# "WAVE 3" banner: also top middle, just under the info strip
	banner = Label.new()
	banner.custom_minimum_size = Vector2(0, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 55
	banner.offset_bottom = 135
	banner.modulate.a = 0.0
	layer.add_child(banner)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	results = PanelContainer.new()
	results.custom_minimum_size = Vector2(460, 330)
	results.hide()
	center.add_child(results)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	results.add_child(box)

	results_title = Label.new()
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.add_theme_font_size_override("font_size", 34)
	box.add_child(results_title)

	results_stats = Label.new()
	results_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_stats)

	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_resume)
	box.add_child(resume_button)

	restart_button = Button.new()
	restart_button.text = "Play Again"
	restart_button.pressed.connect(_restart)
	box.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.text = "Quit to desktop"
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

	add_child(layer)


func _update_hud() -> void:
	if in_break:
		info.text = "Wave %d starts in %d   |   Kills: %d   |   Score: %d   |   XP: %d" % [wave + 1, ceili(break_timer), kills, score, currency]
	else:
		var to_clear := maxi(0, wave_needed - wave_kills)
		info.text = "Wave %d   |   Defeat %d more to advance   |   Kills: %d   |   Score: %d   |   XP: %d" % [wave, to_clear, kills, score, currency]


func _show_banner(text: String) -> void:
	if banner_tween:
		banner_tween.kill()
	banner.text = text
	banner.modulate.a = 1.0
	banner_tween = create_tween()
	banner_tween.tween_interval(1.2)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)


func _input(event: InputEvent) -> void:
	if UIManager.screen != "" or UIManager.modal.visible or game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_pause()
			KEY_F:
				get_viewport().set_input_as_handled()
				_pause()
				UIManager.show_shop("game")
			KEY_R:
				get_viewport().set_input_as_handled()
				UIManager.request_restart()


func _pause() -> void:
	pause_active = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results_title.text = "PAUSED"
	results_stats.text = "Score: %d | Wave: %d | Kills: %d | Run XP: %d" % [score, wave, kills, currency]
	resume_button.show()
	results.show()
	resume_button.grab_focus()
	results.hide()
	UIManager.show_pause()


func _resume() -> void:
	if game_over:
		return
	pause_active = false
	results.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UIManager.show_game()


func bank_run() -> int:
	if banked:
		return OK
	var previous_best: int = Progression.best_score
	bank_error = Progression.finish_run(run_id, currency, score, wave)
	if bank_error == OK:
		banked = true
		new_best = score > previous_best
	return bank_error


func _award_xp(amount: int) -> void:
	if amount <= 0 or banked:
		return
	currency += amount
	bank_error = Progression.credit_run_total(run_id, currency)
