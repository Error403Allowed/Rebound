extends Area3D

## Basic trampoline launch logic for Rebound.
## Attach this script to an Area3D that detects the player.

@export var launch_velocity: float = 18.0
@export var preserve_horizontal_momentum: float = 1.0
@export var max_horizontal_velocity: float = 20.0
@export var bounce_cooldown: float = 0.15

var _can_bounce: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not _can_bounce:
		return

	var character_body := body as CharacterBody3D
	if character_body == null:
		return

	_launch(character_body)
	_start_bounce_cooldown()


func _launch(player: CharacterBody3D) -> void:
	var velocity := player.velocity

	# Preserve controlled horizontal momentum.
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z) * preserve_horizontal_momentum

	if horizontal_velocity.length() > max_horizontal_velocity:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_velocity

	player.velocity = Vector3(horizontal_velocity.x, launch_velocity, horizontal_velocity.z)


func _start_bounce_cooldown() -> void:
	_can_bounce = false

	var timer := get_tree().create_timer(bounce_cooldown)
	await timer.timeout

	_can_bounce = true
