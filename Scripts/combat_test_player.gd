extends "res://Scenes/player.gd"

signal health_changed(current: int)
signal died
signal stomped

@export var max_health: int = 100
@export var stomp_damage: int = 1
@export var rebound_speed: float = 10.0
var health: int = 100
var dead: bool = false
var immunity: float = 0.0
var last_stomp_frame: int = -100

func _ready() -> void:
	super._ready()
	health = max_health
	add_to_group("combat_player")
	collision_layer = 2
	collision_mask = 5
	$MeshInstance3D.hide()
	process_physics_priority = 10

func _physics_process(delta: float) -> void:
	if dead:
		return
	immunity = maxf(0.0, immunity - delta)
	var descent: float = velocity.y
	super._physics_process(delta)
	for index in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(index)
		var enemy: Node = hit.get_collider() as Node
		if enemy != null and enemy.is_in_group("combat_enemies"):
			if descent < -2.0 and hit.get_normal().y > 0.65:
				if enemy.take_damage(stomp_damage):
					velocity.y = rebound_speed
					last_stomp_frame = Engine.get_physics_frames()
					stomped.emit()
					break
	if global_position.y < -20.0:
		take_damage(max_health)

func take_damage(amount: int) -> void:
	if dead or immunity > 0.0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	immunity = 0.8
	health_changed.emit(health)
	if health == 0:
		dead = true
		velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		died.emit()

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	var placement: Node = get_node_or_null("TrampolinePlacement")
	if placement != null and placement.handle_event(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
