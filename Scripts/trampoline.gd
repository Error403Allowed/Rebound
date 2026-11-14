extends Area3D

## Trampoline launch logic for Rebound.
## Attach this script to an Area3D that detects the player.

enum TrampolineType {
	STANDARD,
	STRONG,
	DIRECTIONAL,
}

@export var trampoline_type: TrampolineType = TrampolineType.STANDARD

@export_group("Standard Trampoline")
@export var standard_launch_velocity: float = 18.0

@export_group("Strong Trampoline")
@export var strong_launch_velocity: float = 27.0

@export_group("Directional Trampoline")
@export var directional_launch_speed: float = 24.0
@export var launch_direction: Vector3 = Vector3.UP
@export var preserve_horizontal_momentum: float = 0.5

@export_group("Shared Settings")
@export var max_horizontal_velocity: float = 24.0
@export var bounce_cooldown: float = 0.2

var _can_bounce: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not _can_bounce:
		return

	var player := body as CharacterBody3D
	if player == null:
		return

	match trampoline_type:
		TrampolineType.STANDARD:
			_launch_vertical(player, standard_launch_velocity)
		TrampolineType.STRONG:
			_launch_vertical(player, strong_launch_velocity)
		TrampolineType.DIRECTIONAL:
			_launch_directional(player)

	_start_bounce_cooldown()


func _launch_vertical(player: CharacterBody3D, launch_velocity: float) -> void:
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal_velocity = _limit_horizontal_velocity(horizontal_velocity)

	player.velocity = Vector3(horizontal_velocity.x, launch_velocity, horizontal_velocity.z)


func _launch_directional(player: CharacterBody3D) -> void:
	var direction := launch_direction.normalized()

	if direction == Vector3.ZERO:
		direction = Vector3.UP

	var horizontal_momentum := Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal_momentum *= preserve_horizontal_momentum
	horizontal_momentum = _limit_horizontal_velocity(horizontal_momentum)

	var launch_velocity := direction * directional_launch_speed
	player.velocity = launch_velocity + horizontal_momentum


func _limit_horizontal_velocity(velocity: Vector3) -> Vector3:
	if velocity.length() <= max_horizontal_velocity:
		return velocity

	return velocity.normalized() * max_horizontal_velocity


func _start_bounce_cooldown() -> void:
	_can_bounce = false

	var timer := get_tree().create_timer(bounce_cooldown)
	await timer.timeout

	_can_bounce = true
