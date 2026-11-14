extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 4.5
@export var fall_gravity: float = 26.0
@export var max_fall_speed: float = 40.0
@export var mouse_sensitivity: float = 0.002
@export var ground_acceleration: float = 50.0
@export var air_acceleration: float = 15.0

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _jump_was_held: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
var _base_fov: float = 0.0

func _ready() -> void:
	_base_fov = camera.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0)
		)

func _physics_process(delta: float) -> void:
	var controls_active: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var grounded: bool = is_on_floor() and velocity.y <= 0.0
	if not grounded:
		var applied_gravity: float = fall_gravity if velocity.y < 0.0 else gravity
		velocity.y -= applied_gravity * delta
		velocity.y = maxf(velocity.y, -max_fall_speed)

	var jump_held: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if controls_active and jump_held and not _jump_was_held and grounded:
		velocity.y = jump_velocity
	_jump_was_held = jump_held

	var input_dir := Vector2.ZERO
	if controls_active:
		if Input.is_physical_key_pressed(KEY_W):
			input_dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			input_dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			input_dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var direction: Vector3 = global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	direction = direction.normalized()
	var current_speed: float = speed
	var sprinting: bool = controls_active and Input.is_physical_key_pressed(KEY_SHIFT) and input_dir.y < 0.0
	if sprinting:
		current_speed = sprint_speed
	var target_fov: float = _base_fov + (15.0 if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-10.0 * delta))

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if grounded:
		horizontal = horizontal.move_toward(direction * current_speed, ground_acceleration * delta)
	elif direction != Vector3.ZERO:
		# Steering adds velocity only up to the desired speed along this direction.
		# Existing trampoline momentum is not clamped to walking speed.
		var available_speed: float = current_speed - horizontal.dot(direction)
		if available_speed > 0.0:
			horizontal += direction * minf(air_acceleration * delta, available_speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
