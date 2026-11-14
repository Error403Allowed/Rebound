class_name Enemy
extends CharacterBody3D

signal died(enemy_type: int)

enum Type { BASIC, SPEEDY }

# one row per enemy type, so adding a third type is just another entry
const STATS := {
	Type.BASIC:  {"health": 1, "speed": 3.5, "damage": 10, "size": 1.0, "color": Color(0.25, 0.8, 0.25)},
	Type.SPEEDY: {"health": 1, "speed": 6.5, "damage": 15, "size": 0.8, "color": Color(0.95, 0.75, 0.1)},
}

@export var type: Type = Type.BASIC
@export var gravity := 22.0
@export var attack_range := 1.2        # horizontal distance at which it hits you
@export var attack_cooldown := 1.0     # seconds between hits

var health := 1
var speed := 3.5
var damage := 10
var dead := false
var attack_timer := 0.0
var player
var mesh: MeshInstance3D
var collision: CollisionShape3D


func _ready() -> void:
	var stats: Dictionary = STATS[type]
	health = stats["health"]
	speed = stats["speed"]
	damage = stats["damage"]
	var size: float = stats["size"]

	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")

	# squashed sphere body
	var sphere := SphereMesh.new()
	sphere.radius = 0.5 * size
	sphere.height = 0.8 * size
	sphere.radial_segments = 12
	sphere.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats["color"]
	mat.roughness = 0.4
	sphere.material = mat
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


func _physics_process(delta: float) -> void:
	if dead or player == null:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# walk straight at the player
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var flat := to_player.length()
	var dir := to_player / flat if flat > 0.01 else Vector3.ZERO
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	# little jelly wobble
	mesh.scale.y = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.01 + get_instance_id())

	# contact damage (the player is safe while launched, since slamming is their attack)
	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer <= 0.0 and flat <= attack_range \
			and absf(player.global_position.y - global_position.y) < 1.6 \
			and not player.launched:
		player.take_damage(damage)
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
