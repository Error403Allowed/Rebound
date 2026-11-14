extends Node3D

const PLAYER_SCENE = preload("res://Scenes/player.tscn")
const PLAYER_SCRIPT = preload("res://Scripts/combat_test_player.gd")
const ENEMY_SCRIPT = preload("res://Scripts/combat_test_enemy.gd")
var player: CharacterBody3D
var status: Label
var feedback: Label

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.12, 0.17, 0.23)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	add_child(environment)
	_box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.22, 0.3, 0.32), true)
	for position in [Vector3(-20, 2, 0), Vector3(20, 2, 0)]:
		_box(self, position, Vector3(1, 4, 40), Color(0.3, 0.36, 0.4), true)
	for position in [Vector3(0, 2, -20), Vector3(0, 2, 20)]:
		_box(self, position, Vector3(40, 4, 1), Color(0.3, 0.36, 0.4), true)
	player = PLAYER_SCENE.instantiate()
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.1, 5)
	add_child(player)
	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.name = "Enemy"
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.6)
	shape.shape = box
	enemy.add_child(shape)
	_box(enemy, Vector3.ZERO, box.size, Color(0.9, 0.25, 0.2), false)
	enemy.position = Vector3(0, 0.85, -5)
	add_child(enemy)
	var pad := Area3D.new()
	pad.position = Vector3(0, 0.2, 1)
	pad.collision_layer = 0
	pad.collision_mask = 2
	var pad_shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(4, 0.4, 4)
	pad_shape.shape = volume
	pad.add_child(pad_shape)
	_box(pad, Vector3.ZERO, Vector3(4, 0.15, 4), Color(0.15, 0.9, 0.65), false)
	pad.body_entered.connect(_bounce)
	add_child(pad)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(24, 20)
	status.add_theme_font_size_override("font_size", 24)
	canvas.add_child(status)
	feedback = Label.new()
	feedback.position = Vector2(24, 64)
	feedback.text = "WASD move | Shift sprint | Space jump | R restart | Esc release mouse\nGreen pad launches you. Descend onto the red enemy to stomp."
	canvas.add_child(feedback)
	player.health_changed.connect(_health_changed)
	player.died.connect(_player_died)
	player.stomped.connect(_stomped)
	enemy.died.connect(_enemy_died)
	_health_changed(player.health)

func _box(parent: Node, position: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var holder: Node3D = parent as Node3D
	if solid:
		holder = StaticBody3D.new()
		holder.position = position
		parent.add_child(holder)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		holder.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	if not solid:
		visual.position = position
	holder.add_child(visual)

func _bounce(body: Node3D) -> void:
	if body == player and not player.dead and player.velocity.y <= 0.0:
		player.velocity.y = 18.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()

func _health_changed(value: int) -> void:
	status.text = "STAGE 1 COMBAT TEST | Health: %d / %d" % [value, player.max_health]

func _player_died() -> void:
	feedback.text = "DEFEATED — Press R to restart."

func _stomped() -> void:
	feedback.text = "STOMP! — Rebound applied. Press R to repeat the test."

func _enemy_died() -> void:
	feedback.text = "Enemy defeated — Press R to restart."
