extends CharacterBody3D

signal health_changed(current: int)
signal died
signal stomped

@export_group("Movement")
@export var move_speed := 11.0
@export var sprint_speed := 16.5
@export var ground_accel := 70.0
@export var air_accel := 6.0
@export var air_drag := 2.5
@export var jump_speed := 8.0
@export var gravity: float = 26.0
@export var mouse_sensitivity := 0.0025

@export_group("Trampoline")
@export var place_range := 10.0
@export var tramp_radius := 1.5
@export var world_size := 65.0
@export var trampoline_launch_speeds: Array[float] = [12.0, 15.0, 20.0]
@export var trampoline_charges: Array[int] = [4, 3, 2]
@export var trampoline_cooldowns: Array[float] = [5.0, 8.0, 12.0]
@export var rebound_increment := 1.5
@export var maximum_rebound_bonus := 8.0

@export_group("Combat")
@export var max_health := 100
@export var stomp_damage := 1
@export var slam_radius := 1.5
@export var hit_invulnerability := 0.4
@export var rebound_speed := 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const TRAMP_HEIGHT := 0.3
const TIER_COLORS := [Color(0.2, 0.9, 0.4), Color(0.2, 0.5, 1.0), Color(0.7, 0.3, 1.0)]
const TIER_NAMES := ["GREEN", "BLUE", "PURPLE"]

var place_mode := false
var selected_tier := 0
var cooldown_left := 0.0
var launched := false
var slammed := false
var health := 100
var hit_timer := 0.0
var last_trampoline: Node = null
var consecutive_bounces := 0
var base_fov := 75.0

var tramp_mesh: CylinderMesh
var preview: MeshInstance3D
var preview_mat: StandardMaterial3D
var hud: Label
var crosshair: Label


func _ready() -> void:
	add_to_group("player")
	health = max_health
	base_fov = camera.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	tramp_mesh = CylinderMesh.new()
	tramp_mesh.top_radius = tramp_radius
	tramp_mesh.bottom_radius = tramp_radius
	tramp_mesh.height = TRAMP_HEIGHT
	tramp_mesh.radial_segments = 16
	tramp_mesh.rings = 1

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
	hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud)
	var cross := Label.new()
	crosshair = cross
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
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity * (-1.0 if bool(SettingsManager.get_value("invert_y")) else 1.0), -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				selected_tier = 0
			KEY_2:
				selected_tier = 1
			KEY_3:
				selected_tier = 2
			KEY_R:
				UIManager.request_restart()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			try_place()


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	hit_timer = maxf(hit_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -40.0)

		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		horizontal *= maxf(0.0, 1.0 - air_drag * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_speed

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and input.y < 0.0
	var current_speed := sprint_speed if sprinting else move_speed
	var accel := ground_accel if is_on_floor() else air_accel
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if is_on_floor():
		horizontal_velocity = horizontal_velocity.move_toward(Vector3(dir.x, 0.0, dir.z) * current_speed, accel * delta)
	elif dir != Vector3.ZERO:
		var available_speed := current_speed - horizontal_velocity.dot(Vector3(dir.x, 0.0, dir.z))
		if available_speed > 0.0:
			horizontal_velocity += Vector3(dir.x, 0.0, dir.z) * minf(air_accel * delta, available_speed)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	var fall_speed := velocity.y
	move_and_slide()

	_check_slam(fall_speed)

	if launched and is_on_floor() and velocity.y <= 0.0:
		launched = false

	_update_preview()
	_update_hud()
	_update_fov(delta, sprinting)


func register_trampoline_bounce(trampoline: Node) -> float:
	if trampoline == last_trampoline:
		consecutive_bounces += 1
	else:
		consecutive_bounces = 0
	last_trampoline = trampoline
	return minf(consecutive_bounces * rebound_increment, maximum_rebound_bonus)


func take_damage(amount: int, attacker: Node = null) -> void:
	if get_tree().paused:
		return
	if hit_timer > 0.0 or health <= 0 or amount <= 0:
		return
	if attacker != null and attacker.has_meta("stomped_frame"):
		if Engine.get_physics_frames() - int(attacker.get_meta("stomped_frame")) <= 1:
			return
	health = maxi(0, health - amount)
	hit_timer = hit_invulnerability
	health_changed.emit(health)
	_show_damage_flash()
	if health <= 0:
		velocity = Vector3.ZERO
		died.emit()


func _check_slam(fall_speed: float) -> void:
	if slammed or fall_speed > -3.0:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider: Node = collision.get_collider() as Node
		var enemy_contact: bool = collider != null and collider.is_in_group("enemy")
		if collision.get_normal().y > 0.65 and (launched or enemy_contact):
			_slam_impact()
			return


func _slam_impact() -> void:
	slammed = true
	var origin := global_position
	var hit_enemy := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var flat := Vector2(enemy.global_position.x - origin.x, enemy.global_position.z - origin.z).length()
		if flat <= slam_radius and absf(enemy.global_position.y - origin.y) < 2.5 and enemy.has_method("squish"):
			enemy.set_meta("stomped_frame", Engine.get_physics_frames())
			if not enemy.dead:
				enemy.squish(stomp_damage)
				hit_enemy = true
	if hit_enemy:
		velocity.y = rebound_speed
		launched = true
		slammed = false
	_spawn_shockwave(origin)
	stomped.emit()


func _spawn_shockwave(pos: Vector3) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.1
	cylinder.radial_segments = 24
	cylinder.rings = 1

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.8, 0.2, 0.6)

	var ring := MeshInstance3D.new()
	ring.mesh = cylinder
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	ring.scale = Vector3(0.2, 1.0, 0.2)

	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(slam_radius, 1.0, slam_radius), 0.2)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(ring.queue_free)


func _aim() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * place_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_valid(hit: Dictionary) -> bool:
	if hit.is_empty() or hit.normal.y < 0.7:
		return false
	var limit := world_size / 2.0 - tramp_radius
	return absf(hit.position.x) <= limit and absf(hit.position.z) <= limit


func _update_preview() -> void:
	preview.visible = false
	if not bool(SettingsManager.get_value("placement_preview")):
		return
	if health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	preview.visible = true
	preview.global_position = hit.position + Vector3(0, TRAMP_HEIGHT / 2.0, 0)
	preview_mat.albedo_color = Color(TIER_COLORS[selected_tier], 0.55) if cooldown_left <= 0.0 else Color(1.0, 0.2, 0.2, 0.5)


func try_place() -> void:
	if cooldown_left > 0.0:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	_spawn_trampoline(hit.position)
	cooldown_left = trampoline_cooldowns[selected_tier]


func _spawn_trampoline(pos: Vector3) -> void:
	var area := Area3D.new()
	area.set_meta("tier", selected_tier)
	area.set_meta("charges", trampoline_charges[selected_tier])

	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = tramp_radius
	mesh.bottom_radius = tramp_radius
	mesh.height = TRAMP_HEIGHT
	mesh.radial_segments = 16
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = TIER_COLORS[selected_tier]
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = TRAMP_HEIGHT / 2.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(visual)

	var charge_label := Label3D.new()
	charge_label.position.y = 0.7
	charge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	charge_label.font_size = 48
	charge_label.pixel_size = 0.008
	charge_label.text = str(trampoline_charges[selected_tier])
	area.add_child(charge_label)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = tramp_radius
	shape.height = 0.8
	collision.shape = shape
	collision.position.y = 0.4
	area.add_child(collision)

	area.body_entered.connect(_on_tramp_entered.bind(area))
	get_tree().current_scene.add_child(area)
	area.global_position = pos


func _on_tramp_entered(body: Node3D, area: Area3D) -> void:
	if body != self or area.is_queued_for_deletion():
		return
	var tier := int(area.get_meta("tier"))
	var charges := int(area.get_meta("charges"))
	var bonus := register_trampoline_bounce(area)
	var launch := trampoline_launch_speeds[tier] + bonus
	velocity.y = launch
	launched = true
	slammed = false
	charges = maxi(0, charges - 1)
	area.set_meta("charges", charges)
	var label := area.get_child(1) as Label3D
	if label != null:
		label.text = str(charges)
	if charges <= 0:
		area.queue_free()


func _update_hud() -> void:
	var status := "%s trampoline ready (left click)" % TIER_NAMES[selected_tier] if cooldown_left <= 0.0 else "%s trampoline in %.1fs" % [TIER_NAMES[selected_tier], cooldown_left]
	if place_mode:
		status = "PLACE MODE: click to place   |   " + status
	hud.text = "HP: %d / %d
Tier: %s
%s
WASD move | Shift sprint | Space jump | 1/2/3 tier | Left click place | Esc pause | R restart" % [health, max_health, TIER_NAMES[selected_tier], status]


func _update_fov(delta: float, sprinting: bool) -> void:
	var jump_fov := 0.0
	if not is_on_floor():
		jump_fov = clampf((absf(velocity.y) - 4.0) * 0.7, 0.0, 16.0)
	var effect_strength: float = float(SettingsManager.get_value("fov_strength")) if bool(SettingsManager.get_value("dynamic_fov")) and not bool(SettingsManager.get_value("reduced_motion")) else 0.0
	var target_fov := base_fov + ((15.0 if sprinting else 0.0) + jump_fov) * effect_strength
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-10.0 * delta))


func _show_damage_flash() -> void:
	if not bool(SettingsManager.get_value("damage_flash")) or bool(SettingsManager.get_value("reduced_flashing")):
		return
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.2, 0.2, 0.35)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.add_child(flash)
	add_child(canvas)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(canvas.queue_free)
