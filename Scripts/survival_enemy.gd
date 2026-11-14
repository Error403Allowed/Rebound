extends "res://Scripts/combat_test_enemy.gd"

enum Role { CHASER, DODGER, FLANKER, CHARGER }
@export var role: Role = Role.CHASER
var clock: float = 0.0
var ability_cooldown: float = 0.0
var action_time: float = 0.0
var action: String = ""
var committed := Vector3.ZERO
var orbit_sign: float = 1.0
var telegraph: bool = false
var tracking_descent: bool = false
var reacted: bool = false
var reaction_time: float = 0.0
var health_label: Label3D
var maximum_health: int
var material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	maximum_health = health
	orbit_sign = -1.0 if randf() < 0.5 else 1.0
	ability_cooldown = randf_range(1.0, 3.0)
	material = StandardMaterial3D.new()
	$Visuals/Body.material_override = material
	health_label = Label3D.new()
	health_label.position.y = 1.25
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 40
	health_label.pixel_size = 0.006
	add_child(health_label)
	_update_visuals()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or player.get("dead") == true:
		return
	clock += delta
	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	var offset: Vector3 = player.global_position - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	var distance: float = flat.length()
	var toward: Vector3 = flat.normalized() if distance > 0.1 else Vector3.FORWARD
	var side := Vector3(-toward.z, 0.0, toward.x) * orbit_sign
	var airborne: bool = offset.y > 1.6
	var direction: Vector3 = toward
	if airborne:
		direction = (toward * clampf((distance - 3.0) / 3.0, -0.7, 1.0) + side * 0.85).normalized()
	elif role == Role.FLANKER and distance > 2.0:
		direction = (toward + side * 0.85).normalized()
	elif distance < 1.0:
		direction = side
	var falling: bool = airborne and player.velocity.y < -2.0
	if not falling:
		tracking_descent = false
		reacted = false
		reaction_time = 0.0
	if role == Role.DODGER and falling and not reacted and action.is_empty():
		var time_to_contact: float = clampf((offset.y - 1.8) / maxf(-player.velocity.y, 0.1), 0.0, 1.0)
		var predicted: Vector3 = player.global_position + player.velocity * time_to_contact
		var threat: float = Vector2(predicted.x - global_position.x, predicted.z - global_position.z).length()
		if threat < 2.8 and ability_cooldown <= 0.0:
			tracking_descent = true
		if tracking_descent:
			reaction_time += delta
			telegraph = true
			if reaction_time >= 0.4:
				reacted = true
				action = "dodge"
				action_time = 0.3
				committed = side
				ability_cooldown = 3.5
	if role == Role.CHARGER and action.is_empty() and ability_cooldown <= 0.0 and not airborne and distance > 3.0 and distance < 10.0:
		action = "windup"
		action_time = 0.65
		committed = toward
		telegraph = true
	var movement_speed: float = speed
	if not action.is_empty():
		action_time -= delta
		match action:
			"windup":
				direction = side
				movement_speed = speed * 0.35
			"charge":
				direction = committed
				movement_speed = speed * 2.7
			"dodge":
				direction = committed
				movement_speed = speed * 2.0
			"recover":
				direction = side
				movement_speed = speed * 0.45
		if action_time <= 0.0:
			if action == "windup":
				action = "charge"
				action_time = 0.6
			elif action == "charge" or action == "dodge":
				action = "recover"
				action_time = 0.7
				telegraph = false
			else:
				action = ""
				ability_cooldown = maxf(ability_cooldown, 3.0)
	else:
		var separation := Vector3.ZERO
		for other in get_tree().get_nodes_in_group("combat_enemies"):
			if other == self or not is_instance_valid(other):
				continue
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			var length: float = away.length()
			if length > 0.01 and length < 2.0:
				separation += away.normalized() * (2.0 - length)
		direction = (direction + separation * 0.7).normalized()
	var proposed: Vector3 = global_position + direction * movement_speed * delta
	if absf(proposed.x) > 18.0:
		direction.x = -signf(global_position.x)
	if absf(proposed.z) > 18.0:
		direction.z = -signf(global_position.z)
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	call_deferred("_resolve_contact")
	if not falling and action != "windup":
		telegraph = false
	_update_visuals()

func _update_visuals() -> void:
	var colors = [Color(0.9, 0.25, 0.2), Color(0.95, 0.6, 0.15), Color(0.9, 0.3, 0.65), Color(0.65, 0.3, 0.95)]
	material.albedo_color = Color(1, 0.95, 0.4) if telegraph else colors[role]
	health_label.text = "%s  %d/%d" % [["Chaser", "Dodger", "Flanker", "Charger"][role], health, maximum_health]

func take_damage(amount: int) -> bool:
	var applied: bool = super.take_damage(amount)
	if applied and not dead:
		_update_visuals()
	return applied
