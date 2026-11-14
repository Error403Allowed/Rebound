extends CharacterBody3D

signal died
@export var speed: float = 2.5
@export var health: int = 1
var dead: bool = false
var player: CharacterBody3D
var gravity: float = 9.8

func _ready() -> void:
	add_to_group("combat_enemies")
	collision_layer = 4
	collision_mask = 1
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	player = get_tree().get_first_node_in_group("combat_player") as CharacterBody3D

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or player.dead:
		return
	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.9:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	call_deferred("_resolve_contact")

func _resolve_contact() -> void:
	if dead or not is_instance_valid(player) or player.dead:
		return
	if Engine.get_physics_frames() - player.last_stomp_frame <= 1:
		return
	var offset: Vector3 = player.global_position - global_position
	var horizontal: float = Vector2(offset.x, offset.z).length()
	if horizontal < 1.35 and absf(offset.y) < 1.8:
		player.take_damage(20, self)

func take_damage(amount: int) -> bool:
	if dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		dead = true
		hide()
		set_physics_process(false)
		$CollisionShape3D.set_deferred("disabled", true)
		died.emit()
		queue_free()
	return true
