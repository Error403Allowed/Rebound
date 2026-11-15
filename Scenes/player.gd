extends CharacterBody3D

signal health_changed(current: int)
signal died
signal stomped

@export_group("Movement")
@export var move_speed := 11.0
@export var ground_accel := 70.0
@export var air_accel := 24.0
@export var air_move_speed := 18.0
@export var air_drag := 0.35
@export var jump_speed := 8.0
@export var gravity: float = 26.0
@export var mouse_sensitivity := 0.0025

@export_group("Dash")
@export var dash_recharge_time := 3.0
@export var dash_minimum_charge := 0.2
@export var dash_min_speed := 18.0
@export var dash_max_speed := 32.0
@export var dash_min_duration := 0.10
@export var dash_max_duration := 0.22

@export_group("Trampoline")
@export var place_range := 10.0
@export var tramp_radius := 1.5
@export var world_size := 65.0
@export var trampoline_launch_speed := 22.5   # halfway between the old blue (20) and purple (25)
@export var trampoline_charge_count := 3      # bounces before the trampoline disappears
@export var trampoline_cooldown := 7.0
@export var rebound_increment := 0.0
@export var maximum_rebound_bonus := 8.0

@export_group("Combat")
@export var max_health := 100
@export var stomp_damage := 1
@export var slam_radius := 2.0
@export var hit_invulnerability := 0.4
@export var rebound_speed := 10.0
@export var max_enemy_bounces := 3            # rebounds off enemies allowed per airtime

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const TRAMP_HEIGHT := 0.3
const SCREEN_EFFECTS = preload("res://Scenes/player_screen_effects.gd")
const TRAMP_COLOR := Color(0.1, 0.4, 1.0)         # blue rim
const TRAMP_MAT_COLOR := Color(0.03, 0.03, 0.04)  # black mat
const RIM_THICKNESS := 0.3                        # width of the blue rim

# --- compatibility stand-ins so ui_manager.gd and other scripts keep working ---
# there is only one trampoline type now, so every entry is the same
const TIER_COLORS := [TRAMP_COLOR, TRAMP_COLOR, TRAMP_COLOR]
const TIER_NAMES := ["TRAMPOLINE", "TRAMPOLINE", "TRAMPOLINE"]
var selected_tier := 0
var trampoline_cooldowns: Array[float] = []
var trampoline_launch_speeds: Array[float] = []
var trampoline_charges: Array[int] = []

var place_mode := false
var cooldown_left := 0.0
var launched := false
var slammed := false
var enemy_bounces := 0                # rebounds used since last touching the ground / a trampoline
var health := 100
var hit_timer := 0.0
var last_trampoline: Node = null
var consecutive_bounces := 0
var base_fov := 90.0
var dash_charge := 1.0
var dash_left := 0.0
var dash_speed := 0.0
var dash_fov_kick := 0.0
var dash_direction := Vector3.ZERO
var last_impact_frame := -1
var last_fall_speed := 0.0

var tramp_mesh: CylinderMesh      # flat disc used for the placement ghost
var mat_mesh: CylinderMesh        # black centre
var rim_mesh: TorusMesh           # blue padded rim
var preview: MeshInstance3D
var preview_mat: StandardMaterial3D
var hud: Label
var crosshair: Label
var screen_effects: CanvasLayer
var hit_shake_time := 0.0
var hit_shake_strength := 0.0


func _ready() -> void:
	add_to_group("player")
	max_health = Progression.upgraded_health(max_health)
	stomp_damage = Progression.upgraded_stomp(stomp_damage)
	# Progression upgrades work on an array, so wrap the single cooldown in one
	var cooldowns: Array[float] = [trampoline_cooldown]
	cooldowns = Progression.upgraded_cooldowns(cooldowns)
	trampoline_cooldown = cooldowns[0]
	rebound_increment = Progression.upgraded_rebound_increment()
	health = max_health
	base_fov = camera.fov
	_on_health_changed(health)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# fill the stand-in lists (three identical entries, matching the old three tiers)
	trampoline_cooldowns = [trampoline_cooldown, trampoline_cooldown, trampoline_cooldown]
	trampoline_launch_speeds = [trampoline_launch_speed, trampoline_launch_speed, trampoline_launch_speed]
	trampoline_charges = [trampoline_charge_count, trampoline_charge_count, trampoline_charge_count]

	_build_trampoline_meshes()

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
	screen_effects = SCREEN_EFFECTS.new()
	add_child(screen_effects)
	health_changed.connect(_on_health_changed)
	died.connect(_on_died)


func _on_health_changed(current: int) -> void:
	if is_instance_valid(screen_effects):
		screen_effects.update_health(float(current) / maxf(1.0, float(max_health)))


func _on_died() -> void:
	if is_instance_valid(screen_effects):
		var tween := create_tween()
		tween.tween_method(screen_effects.update_dead, 0.0, 1.0, 0.55)


# built once and shared by every trampoline, so extra trampolines cost almost nothing
func _build_trampoline_meshes() -> void:
	# flat disc for the placement ghost
	tramp_mesh = CylinderMesh.new()
	tramp_mesh.top_radius = tramp_radius
	tramp_mesh.bottom_radius = tramp_radius
	tramp_mesh.height = TRAMP_HEIGHT
	tramp_mesh.radial_segments = 16
	tramp_mesh.rings = 1

	# black mat in the middle, sitting lower than the rim
	mat_mesh = CylinderMesh.new()
	mat_mesh.top_radius = tramp_radius - RIM_THICKNESS * 0.5
	mat_mesh.bottom_radius = tramp_radius - RIM_THICKNESS * 0.5
	mat_mesh.height = 0.1
	mat_mesh.radial_segments = 20
	mat_mesh.rings = 1
	var black := StandardMaterial3D.new()
	black.albedo_color = TRAMP_MAT_COLOR
	black.roughness = 0.9
	black.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat_mesh.material = black

	# blue padded rim standing up around the edge
	rim_mesh = TorusMesh.new()
	rim_mesh.outer_radius = tramp_radius
	rim_mesh.inner_radius = tramp_radius - RIM_THICKNESS
	rim_mesh.rings = 20
	rim_mesh.ring_segments = 8
	var blue := StandardMaterial3D.new()
	blue.albedo_color = TRAMP_COLOR
	blue.roughness = 0.5
	blue.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	rim_mesh.material = blue


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity * (-1.0 if bool(SettingsManager.get_value("invert_y")) else 1.0), -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				# E toggles place mode
				if UIManager.screen == "" and not UIManager.modal.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					place_mode = not place_mode
			KEY_Q:
				try_dash()
			KEY_R:
				UIManager.request_restart()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif place_mode:
			try_place()


func _physics_process(delta: float) -> void:
	if health <= 0 or get_tree().paused:
		return
	dash_charge = minf(1.0, dash_charge + delta / maxf(0.01, dash_recharge_time))
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

	var current_speed := move_speed
	if not is_on_floor():
		current_speed = air_move_speed
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

	if dash_left > 0.0:
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_left = maxf(0.0, dash_left - delta)
	var fall_speed := velocity.y
	last_fall_speed = fall_speed
	move_and_slide()
	if dash_left <= 0.0:
		var flat_speed := Vector2(velocity.x, velocity.z).length()
		var speed_limit := move_speed if is_on_floor() else maxf(air_move_speed, dash_max_speed)
		if flat_speed > speed_limit:
			velocity.x *= speed_limit / flat_speed
			velocity.z *= speed_limit / flat_speed

	_check_slam(fall_speed)

	# landed: the launch is over and the enemy-bounce allowance refills
	if launched and is_on_floor() and velocity.y <= 0.0:
		launched = false
		enemy_bounces = 0

	_update_preview()
	_update_hud()
	_update_hit_shake(delta)
	_update_fov(delta)


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
	SFXManager.play_player_hit()
	_start_hit_shake()
	_show_damage_flash()
	if health <= 0:
		place_mode = false
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
	if last_impact_frame == Engine.get_physics_frames():
		return
	last_impact_frame = Engine.get_physics_frames()
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
	# rebound off the enemies, but only while you still have bounces left
	if hit_enemy and enemy_bounces < max_enemy_bounces:
		enemy_bounces += 1
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
	if not place_mode:                       # ghost only shows in place mode
		return
	if not bool(SettingsManager.get_value("placement_preview")):
		return
	if health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	preview.visible = true
	preview.global_position = hit.position + Vector3(0, TRAMP_HEIGHT / 2.0, 0)
	preview_mat.albedo_color = Color(TRAMP_COLOR, 0.55) if cooldown_left <= 0.0 else Color(1.0, 0.2, 0.2, 0.5)


func try_place() -> void:
	if cooldown_left > 0.0:
		return
	var hit := _aim()
	if not _is_valid(hit):
		return
	_spawn_trampoline(hit.position)
	cooldown_left = trampoline_cooldown
	place_mode = false                       # back to normal after placing


func _spawn_trampoline(pos: Vector3) -> void:
	var area := Area3D.new()
	area.set_meta("tier", 0)
	area.set_meta("charges", trampoline_charge_count)

	# Opaque dark mat raised above the grass layer.
	var mat_inst := MeshInstance3D.new()
	mat_inst.mesh = mat_mesh
	mat_inst.position.y = 0.18
	mat_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_material := StandardMaterial3D.new()
	mat_material.albedo_color = Color(0.06, 0.07, 0.09)
	mat_material.roughness = 0.85
	mat_material.metallic = 0.0
	mat_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_inst.material_override = mat_material
	area.add_child(mat_inst)

	# Solid base skirt prevents grass blades from intersecting the mat.
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = tramp_radius
	base_mesh.bottom_radius = tramp_radius
	base_mesh.height = 0.18
	base_mesh.radial_segments = 24
	base_mesh.rings = 1
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position.y = 0.09
	base_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.04, 0.05, 0.06)
	base_material.roughness = 0.9
	base_material.metallic = 0.0
	base_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	base_inst.material_override = base_material
	area.add_child(base_inst)

	# High-contrast padded rim makes the trampoline read as an object, not grass.
	var rim_inst := MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.position.y = RIM_THICKNESS * 0.5
	rim_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color(0.05, 0.65, 1.0)
	rim_material.roughness = 0.35
	rim_material.metallic = 0.0
	rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim_inst.material_override = rim_material
	area.add_child(rim_inst)

	# Thin dark contact shadow anchors the trampoline to the ground.
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = tramp_radius * 1.08
	shadow_mesh.bottom_radius = tramp_radius * 1.08
	shadow_mesh.height = 0.01
	var shadow_inst := MeshInstance3D.new()
	shadow_inst.mesh = shadow_mesh
	shadow_inst.position.y = 0.006
	shadow_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_inst.material_override = shadow_material
	area.add_child(shadow_inst)

	var charge_label := Label3D.new()
	charge_label.name = "ChargeLabel"
	charge_label.position.y = 0.7
	charge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	charge_label.font_size = 48
	charge_label.pixel_size = 0.008
	charge_label.text = str(trampoline_charge_count)
	area.add_child(charge_label)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = tramp_radius
	shape.height = 0.8
	collision.shape = shape
	collision.position.y = 0.4
	area.add_child(collision)

	area.body_entered.connect(_on_tramp_entered.bind(area))
	area.set_meta("cleared_grass", _clear_grass_around(pos))
	get_tree().current_scene.add_child(area)
	area.global_position = pos


func _clear_grass_around(pos: Vector3) -> Array:
	var clear_radius := tramp_radius + 0.65
	var removed: Array = []
	for node in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
		if not node is MultiMeshInstance3D:
			continue
		var grass := node as MultiMeshInstance3D
		var mesh := grass.multimesh.mesh
		if mesh == null:
			continue
		var instance_count := grass.multimesh.instance_count
		var kept: Array[Transform3D] = []
		var removed_here: Array[Transform3D] = []
		for index in instance_count:
			var local := grass.multimesh.get_instance_transform(index)
			var world := grass.global_transform * local
			if world.origin.distance_to(pos) <= clear_radius:
				removed_here.append(local)
			else:
				kept.append(local)
		if removed_here.is_empty():
			continue
		removed.append({"grass": grass, "mesh": mesh, "transforms": removed_here})
		var replacement := MultiMesh.new()
		replacement.transform_format = MultiMesh.TRANSFORM_3D
		replacement.mesh = mesh
		replacement.instance_count = kept.size()
		for index in kept.size():
			replacement.set_instance_transform(index, kept[index])
		grass.multimesh = replacement
	return removed


func _restore_grass_around(cleared: Array) -> void:
	for entry in cleared:
		var grass := entry["grass"] as MultiMeshInstance3D
		if grass == null or not is_instance_valid(grass):
			continue
		var mesh := entry["mesh"] as Mesh
		var removed := entry["transforms"] as Array
		var current: Array[Transform3D] = []
		for index in grass.multimesh.instance_count:
			current.append(grass.multimesh.get_instance_transform(index))
		for transform in removed:
			current.append(transform)
		var replacement := MultiMesh.new()
		replacement.transform_format = MultiMesh.TRANSFORM_3D
		replacement.mesh = mesh
		replacement.instance_count = current.size()
		for index in current.size():
			replacement.set_instance_transform(index, current[index])
		grass.multimesh = replacement


func _on_tramp_entered(body: Node3D, area: Area3D) -> void:
	if body != self or area.is_queued_for_deletion():
		return
	if health <= 0 or get_tree().paused:
		return
	if velocity.y < -3.0 or (velocity.y <= 0.0 and last_fall_speed < -3.0):
		_slam_impact()
	var charges := int(area.get_meta("charges"))
	var bonus := register_trampoline_bounce(area)
	var launch := trampoline_launch_speed + bonus
	velocity.y = maxf(velocity.y, launch)
	launched = true
	slammed = false
	enemy_bounces = 0                        # a trampoline bounce refills the enemy-bounce allowance
	charges = maxi(0, charges - 1)
	area.set_meta("charges", charges)
	var label := area.get_node_or_null("ChargeLabel") as Label3D
	if label != null:
		label.text = str(charges)
	if charges <= 0:
		_restore_grass_around(area.get_meta("cleared_grass"))
		area.queue_free()


func _update_hud() -> void:
	var status: String
	if cooldown_left > 0.0:
		status = "Trampoline in %.1fs" % cooldown_left
	else:
		status = "Trampoline ready (E)"
	if place_mode:
		status = "PLACE MODE: left click to place, E to cancel   |   " + status
	hud.text = "HP: %d / %d\n%s\nWASD move | Space jump | Q dash | E place mode | Esc pause | R restart" % [health, max_health, status]


func _update_hit_shake(delta: float) -> void:
	if hit_shake_time > 0.0:
		hit_shake_time = maxf(0.0, hit_shake_time - delta)
		var progress := hit_shake_time / 0.28
		var offset := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * hit_shake_strength * progress
		camera.position = camera.position.lerp(offset, 0.65)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-14.0 * delta))

func _update_fov(delta: float) -> void:
	if not bool(SettingsManager.get_value("dynamic_fov")) or bool(SettingsManager.get_value("reduced_motion")):
		camera.fov = base_fov
		return
	var air_fov := 0.0
	if not is_on_floor():
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		air_fov = clampf(4.0 + absf(velocity.y) * 0.25 + horizontal_speed * 0.2, 4.0, 14.0)
	var motion_fov := minf(24.0, air_fov + dash_fov_kick)
	var effect_strength := float(SettingsManager.get_value("fov_strength"))
	var target_fov := clampf(base_fov + motion_fov * effect_strength, 40.0, 140.0)
	var response := 18.0 if target_fov > camera.fov else 7.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-response * delta))
	if dash_left <= 0.0:
		dash_fov_kick = lerpf(dash_fov_kick, 0.0, 1.0 - exp(-10.0 * delta))


func _start_hit_shake() -> void:
	if bool(SettingsManager.get_value("reduced_motion")):
		return
	hit_shake_time = 0.28
	hit_shake_strength = 0.09

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


func try_dash() -> bool:
	if health <= 0 or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or UIManager.screen != "" or UIManager.modal.visible:
		return false
	if dash_left > 0.0 or dash_charge < dash_minimum_charge:
		return false
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	dash_direction = global_transform.basis * Vector3(input.x, 0.0, input.y)
	if dash_direction.length_squared() < 0.001:
		dash_direction = -global_transform.basis.z
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()
	var strength := clampf((dash_charge - dash_minimum_charge) / maxf(0.01, 1.0 - dash_minimum_charge), 0.0, 1.0)
	dash_speed = lerpf(dash_min_speed, dash_max_speed, strength)
	dash_fov_kick = lerpf(10.0, 18.0, strength)
	dash_left = lerpf(dash_min_duration, dash_max_duration, strength)
	dash_charge = 0.0
	return true
