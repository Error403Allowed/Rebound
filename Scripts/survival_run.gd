extends "res://Scripts/combat_test.gd"

const SURVIVAL_ENEMY = preload("res://Scripts/survival_enemy.gd")
@export var preparation_seconds: float = 5.0
@export var simultaneous_cap: int = 16
var wave: int = 0
var pending: int = 0
var living: int = 0
var score: int = 0
var currency: int = 0
var kills: int = 0
var phase: String = "PREPARATION"
var preparation_left: float = 5.0
var spawn_left: float = 0.0
var menu: PanelContainer
var menu_title: Label
var resume_button: Button
var restart_button: Button
var quit_button: Button
var menu_stats: Label

func _ready() -> void:
	super._ready()
	for enemy in get_tree().get_nodes_in_group("combat_enemies"):
		enemy.remove_from_group("combat_enemies")
		enemy.queue_free()
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	preparation_left = preparation_seconds
	_build_menu()
	_refresh_hud()

func _build_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	menu = PanelContainer.new()
	menu.custom_minimum_size = Vector2(430, 300)
	center.add_child(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	menu.add_child(box)
	menu_title = Label.new()
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 30)
	box.add_child(menu_title)
	menu_stats = Label.new()
	menu_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_stats)
	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_resume)
	box.add_child(resume_button)
	restart_button = Button.new()
	restart_button.text = "Restart run"
	restart_button.pressed.connect(_restart)
	box.add_child(restart_button)
	quit_button = Button.new()
	quit_button.text = "Quit to desktop"
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)
	menu.hide()

func _process(delta: float) -> void:
	if get_tree().paused or phase == "GAME OVER":
		return
	if phase == "PREPARATION":
		preparation_left -= delta
		if preparation_left <= 0.0:
			wave += 1
			pending = 2 + wave * 2
			phase = "COMBAT"
			spawn_left = 0.0
	elif phase == "COMBAT":
		spawn_left -= delta
		if pending > 0 and living < simultaneous_cap and spawn_left <= 0.0:
			if _spawn_enemy():
				pending -= 1
				living += 1
			spawn_left = maxf(0.35, 1.2 - wave * 0.04)
		if pending == 0 and living == 0:
			score += wave * 100
			currency += 5
			phase = "PREPARATION"
			preparation_left = preparation_seconds
	_refresh_hud()

func _spawn_enemy() -> bool:
	var candidates = [Vector3(-16, 0.85, -16), Vector3(0, 0.85, -16), Vector3(16, 0.85, -16), Vector3(-16, 0.85, 0), Vector3(16, 0.85, 0), Vector3(-16, 0.85, 16), Vector3(0, 0.85, 16), Vector3(16, 0.85, 16)]
	candidates.shuffle()
	var spawn_position := Vector3.ZERO
	var found: bool = false
	for candidate in candidates:
		var flat := Vector2(candidate.x - player.global_position.x, candidate.z - player.global_position.z)
		if flat.length() < 8.0:
			continue
		var blocked: bool = false
		for other in get_tree().get_nodes_in_group("combat_enemies"):
			if other.global_position.distance_to(candidate) < 2.2:
				blocked = true
				break
		if not blocked:
			spawn_position = candidate
			found = true
			break
	if not found:
		return false
	var enemy := CharacterBody3D.new()
	enemy.set_script(SURVIVAL_ENEMY)
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.position = spawn_position
	var role: int = 0
	var roll: float = randf()
	if wave >= 7 and roll < 0.2:
		role = 3
	elif wave >= 5 and roll < 0.45:
		role = 2
	elif wave >= 3 and roll < 0.7:
		role = 1
	enemy.set("role", role)
	enemy.set("speed", minf(4.0, 2.2 + wave * 0.08))
	enemy.set("health", 1 + mini(3, int(wave / 6.0)))
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(1.6, 1.6, 1.6)
	shape.shape = bounds
	enemy.add_child(shape)
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	enemy.add_child(visuals)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh := BoxMesh.new()
	mesh.size = bounds.size
	body.mesh = mesh
	visuals.add_child(body)
	enemy.died.connect(_survival_enemy_died)
	add_child(enemy)
	return true

func _survival_enemy_died() -> void:
	if phase != "COMBAT":
		return
	living = maxi(0, living - 1)
	kills += 1
	score += 10
	currency += 1

func _refresh_hud() -> void:
	status.text = "STAGE 3 SURVIVAL | Health %d/%d | Wave %d | Score %d | Run coins %d" % [player.get("health"), player.get("max_health"), wave, score, currency]
	if phase == "PREPARATION":
		feedback.text = "Wave %d in %.1fs — move and prepare your trampoline. Esc pauses." % [wave + 1, maxf(0.0, preparation_left)]
	elif phase == "COMBAT":
		feedback.text = "Alive: %d | Yet to spawn: %d | Kills: %d | Esc pause | R restart" % [living, pending, kills]

func _health_changed(_value: int) -> void:
	pass

func _stomped() -> void:
	pass

func _player_died() -> void:
	phase = "GAME OVER"
	_show_menu(true)

func _show_menu(game_over: bool) -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_title.text = "GAME OVER" if game_over else "PAUSED"
	menu_stats.text = "Score: %d | Wave reached: %d\nKills: %d | Run coins: %d (not saved)" % [score, wave, kills, currency]
	resume_button.visible = not game_over
	menu.show()
	if game_over:
		restart_button.grab_focus()
	else:
		resume_button.grab_focus()

func _resume() -> void:
	if phase == "GAME OVER":
		return
	menu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if phase != "GAME OVER":
				if get_tree().paused:
					_resume()
				else:
					_show_menu(false)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_restart()

func _unhandled_input(_event: InputEvent) -> void:
	pass
