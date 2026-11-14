class_name Enemy
extends CharacterBody3D

signal died(enemy_type: int)

enum Type { BASIC, SPEEDY }
enum Role { CHASER, DODGER, FLANKER, CHARGER }

const STATS := {
	Type.BASIC: {"health": 1, "speed": 3.5, "damage": 10, "size": 1.0, "color": Color(0.25, 0.8, 0.25)},
	Type.SPEEDY: {"health": 1, "speed": 6.5, "damage": 15, "size": 0.8, "color": Color(0.95, 0.75, 0.1)},
}
const ROLE_NAMES := ["CHASER", "DODGER", "FLANKER", "CHARGER"]
const ROLE_COLORS := [Color(0.9, 0.25, 0.2), Color(0.95, 0.6, 0.15), Color(0.9, 0.3, 0.65), Color(0.65, 0.3, 0.95)]

@export var type: Type = Type.BASIC
@export var role: Role = Role.CHASER
@export var gravity := 22.0
@export var attack_range := 1.35
@export var attack_cooldown := 1.0

var health := 1
var speed := 3.5
var damage := 10
var dead := false
var attack_timer := 0.0
var ability_cooldown := 0.0
var action := ""
var action_time := 0.0
var committed := Vector3.ZERO
var orbit_sign := 1.0
var telegraph := false
var tracking_descent := false
var reacted := false
var reaction_time := 0.0
var player
var mesh: MeshInstance3D
var collision: CollisionShape3D
var material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var stats: Dictionary = STATS[type]
	health = stats["health"]
	speed = stats["speed"]
	damage = stats["damage"]
	var size: float = stats["size"]
	orbit_sign = -1.0 if randf() < 0.5 else 1.0
	ability_cooldown = randf_range(1.0, 3.0)
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")

	var sphere := SphereMesh.new()
	sphere.radius = 0.5 * size
	sphere.height = 0.8 * size
	sphere.radial_segments = 12
	sphere.rings = 6
	material = StandardMaterial3D.new()
	material.albedo_color = ROLE_COLORS[role]
	material.roughness = 0.4
	sphere.material = material
	mesh = MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.position.y = 0.4 * size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45 * size
	collision.shape = shape
	collision.position.y = 0.45 * size
	add_child(collision)

	var label := Label3D.new()
	label.position.y = 1.1 * size + 0.35
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.006
	label.text = ROLE_NAMES[role]
	label.visible = bool(SettingsManager.get_value("enemy_labels"))
	add_child(label)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if dead or not is_instance_valid(player) or player.health <= 0:
		return
	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	attack_timer = maxf(0.0, attack_timer - delta)

	var offset: Vector3 = player.global_position - global_position
	var flat_distance := Vector2(offset.x, offset.z).length()
	var toward := Vector3(offset.x, 0.0, offset.z).normalized() if flat_distance > 0.1 else Vector3.FORWARD
	var side := Vector3(-toward.z, 0.0, toward.x) * orbit_sign
	var player_motion: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var lead_time: float = clampf(flat_distance / maxf(speed, 0.1) * 0.15, 0.0, 0.45)
	var lead: Vector3 = player_motion * lead_time
	if lead.length() > 3.0:
		lead = lead.normalized() * 3.0
	var pursuit: Vector3 = (Vector3(offset.x, 0.0, offset.z) + lead).normalized()
	var direction := pursuit
	var movement_speed := speed
	var airborne := offset.y > 1.6
	var falling: bool = airborne and player.velocity.y < -2.0

	if not falling:
		tracking_descent = false
		reacted = false
		reaction_time = 0.0
		if action.is_empty():
			telegraph = false

	if role == Role.DODGER and falling and not reacted and action.is_empty():
		var time_to_contact := clampf((offset.y - 1.8) / maxf(-player.velocity.y, 0.1), 0.0, 1.0)
		var predicted: Vector3 = player.global_position + player.velocity * time_to_contact
		var threat := Vector2(predicted.x - global_position.x, predicted.z - global_position.z).length()
		if threat < 3.2 and ability_cooldown <= 0.0:
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

	if role == Role.CHARGER and action.is_empty() and ability_cooldown <= 0.0 and not airborne and flat_distance > 3.0 and flat_distance < 12.0:
		action = "windup"
		action_time = 0.65
		committed = toward
		telegraph = true

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
		if airborne:
			var landing_time: float = clampf((float(player.velocity.y) + sqrt(float(player.velocity.y) * float(player.velocity.y) + 2.0 * 26.0 * maxf(offset.y - 1.0, 0.0))) / 26.0, 0.0, 0.65)
			var landing_lead: Vector3 = player_motion * landing_time
			if landing_lead.length() > 4.0:
				landing_lead = landing_lead.normalized() * 4.0
			var landing_offset: Vector3 = Vector3(offset.x, 0.0, offset.z) + landing_lead
			var landing_toward: Vector3 = landing_offset.normalized()
			var landing_side: Vector3 = Vector3(-landing_toward.z, 0.0, landing_toward.x) * orbit_sign
			direction = (landing_toward * clampf((landing_offset.length() - 2.5) / 2.5, -0.7, 1.0) + landing_side * 0.8).normalized()
		elif role == Role.FLANKER and flat_distance > 2.0:
			var flank_weight: float = clampf((flat_distance - 2.0) / 5.0, 0.0, 0.85)
			direction = (pursuit + side * flank_weight).normalized()
		elif flat_distance < 0.65:
			direction = side
		var separation := Vector3.ZERO
		for other in get_tree().get_nodes_in_group("enemy"):
			if other == self or not is_instance_valid(other):
				continue
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			var distance := away.length()
			if distance > 0.01 and distance < 2.0:
				separation += away.normalized() * (2.0 - distance)
		var separation_weight: float = 0.2 if flat_distance < 2.5 and not airborne else 0.7
		direction = (direction + separation * separation_weight).normalized()

	var proposed := global_position + direction * movement_speed * delta
	if absf(proposed.x) > 31.0:
		direction.x = -signf(global_position.x)
	if absf(proposed.z) > 31.0:
		direction.z = -signf(global_position.z)
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

	mesh.scale.y = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.01 + get_instance_id())
	material.albedo_color = Color(1.0, 0.95, 0.4) if telegraph else ROLE_COLORS[role]

	if attack_timer <= 0.0 and flat_distance <= attack_range and absf(player.global_position.y - global_position.y) < 1.8 and not player.launched:
		player.take_damage(damage, self)
		attack_timer = attack_cooldown


func squish(amount: int = 1) -> void:
	if dead:
		return
	health -= amount
	if health > 0:
		return
	dead = true
	remove_from_group("enemy")
	collision.set_deferred("disabled", true)
	died.emit(type)
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.8, 0.1, 1.8), 0.1)
	tween.tween_callback(queue_free)
