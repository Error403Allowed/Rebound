extends CharacterBody3D

@export_group("Movement")
@export var move_speed := 11.0
@export var ground_accel := 90.0
@export var air_accel := 20.0
@export var jump_speed := 8.0
@export var gravity := 22.0
@export var fall_multiplier := 1.4
@export var mouse_sensitivity := 0.0025

@export_group("Trampoline")
@export var launch_speed := 24.0
@export var slam_multiplier := 2.5
@export var max_fall_speed := 60.0
@export var place_range := 10.0
@export var place_cooldown := 5.0
@export var tramp_radius := 1.5
@export var world_size := 65.0           # must match the World script

@export_group("Combat")
@export var max_health := 100
@export var stomp_damage := 1            # damage to each enemy hit by the landing
@export var slam_radius := 3.0           # size of the landing damage area (metres)
@export var hit_invulnerability := 0.4   # seconds of protection after being hit

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const TRAMP_HEIGHT := 0.3

var place_mode := false
var cooldown_left := 0.0
var launched := false
var slammed := false                     # true once this launch has already landed its hit
var health := 100
var hit_timer := 0.0

var tramp_mesh: CylinderMesh
var preview: MeshInstance3D
var preview_mat: StandardMaterial3D
var hud: Label


func _ready() -> void:
	add_to_group("player")
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	tramp_mesh = CylinderMesh.new()
	tramp_mesh.top_radius = tramp_radius
	tramp_mesh.bottom_radius = tramp_radius
	tramp_mesh.height = TRAMP_HEIGHT
	tramp_mesh.radial_segments = 16
	tramp_mesh.rings = 1
	var tramp_mat := StandardMaterial3D.new()
	tramp_mat.albedo_color = Color(1.0, 0.45, 0.1)
	tramp_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tramp_mesh.material = tramp_mat

	preview_mat = StandardMaterial3D.new()
	preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview = MeshInstance3D.new()
	preview.mesh = tramp_mesh
	preview.material_override = preview_mat
	preview.top_level = true
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	add_child(preview)

	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = Vector2(20, 20)
	layer.add_child(hud)
	var cross := Label.new()
	cross.text = "+"
	cross.custom_minimum_size = Vector2(40, 40)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(cross)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			place_mode = not place_mode
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif place_mode:
			try_place()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	hit_timer = maxf(hit_timer - delta, 0.0)

	# gravity: stronger on the way down, strongest after a trampoline launch
	if not is_on_floor():
		var g := gravity
		if velocity.y < 0.0:
			g *= slam_multiplier if launched else fall_multiplier
		velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)

	# jump (hold space to keep jumping)
	if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_speed

	# WASD
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var accel := ground_accel if is_on_floor() else air_accel
	velocity.x = move_toward(velocity.x, dir.x * move_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, accel * delta)

	var fall_speed := velocity.y             # speed just before the collision
	move_and_slide()

	if launched:
		_check_slam(fall_speed)

	# landed: launch state is over
	if launched and is_on_floor() and velocity.y <= 0.0:
		launched = false

	_update_preview()
	_update_hud()


# ---------- combat ----------

func take_damage(amount: int) -> void:
	if hit_timer > 0.0 or health <= 0:
		return
	health -= amount
	hit_timer = hit_invulnerability
	if health <= 0:
		get_tree().call_deferred("reload_current_scene")   # placeholder: restart on death


# landing on the ground OR on top of an enemy triggers the area damage, once per launch
func _check_slam(fall_speed: float) -> void:
	if slammed or fall_speed > -3.0:
		return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().y > 0.2:   # hit something from above
			_slam_impact()
			return


func _slam_impact() -> void:
	slammed = true
	var origin := global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		var flat := Vector2(e.global_position.x - origin.x, e.global_position.z - origin.z).length()
		if flat <= slam_radius and absf(e.global_position.y - origin.y) < 2.5 and e.has_method("squish"):
			e.squish(stomp_damage)
	_spawn_shockwave(origin)


# quick expanding ring so you can see the damage area
func _spawn_shockwave(pos: Vector3) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.1
	cyl.radial_segments = 24
	cyl.rings = 1

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.6)

	var ring := MeshInstance3D.new()
	ring.mesh = cyl
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	ring.scale = Vector3(0.2, 1.0, 0.2)

	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(slam_radius, 1.0, slam_radius), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(ring.queue_free)


# ---------- trampoline ----------

func _aim() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * place_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_valid(hit: Dictionary) -> bool:
	if hit.is_empty() or hit.normal.y < 0.7:      # only flat ground, not walls
		return false
	var limit := world_size / 2.0 - tramp_radius  # keep it inside the walls
	return absf(hit.position.x) <= limit and absf(hit.position.z) <= limit


func _update_preview() -> void:
	preview.visible = false
	if not place_mode:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	preview.visible = true
	preview.global_position = hit.position + Vector3(0, TRAMP_HEIGHT / 2.0, 0)
	preview_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.5) if cooldown_left <= 0.0 else Color(1.0, 0.2, 0.2, 0.5)


func try_place() -> void:
	if cooldown_left > 0.0:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	_spawn_trampoline(hit.position)
	cooldown_left = place_cooldown
	place_mode = false


func _spawn_trampoline(pos: Vector3) -> void:
	var area := Area3D.new()

	var visual := MeshInstance3D.new()
	visual.mesh = tramp_mesh
	visual.position.y = TRAMP_HEIGHT / 2.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(visual)

	# trigger zone is taller than the visual so a fast fall can't skip it
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = tramp_radius
	shape.height = 0.8
	col.shape = shape
	col.position.y = 0.4
	area.add_child(col)

	area.body_entered.connect(_on_tramp_entered.bind(area))
	get_tree().current_scene.add_child(area)
	area.global_position = pos


func _on_tramp_entered(body: Node3D, area: Area3D) -> void:
	if body != self or area.is_queued_for_deletion():
		return
	velocity.y = launch_speed
	launched = true
	slammed = false                          # a new launch gets a new landing hit
	area.queue_free()                        # trampoline disappears after the jump


func _update_hud() -> void:
	var status := "Trampoline ready (E)" if cooldown_left <= 0.0 else "Trampoline in %.1fs" % cooldown_left
	if place_mode:
		status = "PLACE MODE: click to place   |   " + status
	hud.text = "HP: %d / %d\n%s" % [health, max_health, status]
