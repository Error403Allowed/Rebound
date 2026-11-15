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
const TELEGRAPH_COLOR := Color(1.0, 0.95, 0.4)

# meshes and materials are built once and shared by every enemy (needs Godot 4.1+)
static var _blob_mesh: ArrayMesh
static var _eye_mesh: ArrayMesh
static var _eye_mat: StandardMaterial3D
static var _chunk_mesh: SphereMesh
static var _chunk_mats := {}

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
var mesh: MeshInstance3D          # the blob body
var visual: Node3D                # holds body + eyes, so they scale and turn together
var collision: CollisionShape3D
var material: StandardMaterial3D

var body_size := 1.0
var wobble_phase := 0.0
var hit_flash := 0.0
var current_color := Color(0, 0, 0, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var stats: Dictionary = STATS[type]
	health = stats["health"]
	speed = stats["speed"]
	damage = stats["damage"]
	var size: float = stats["size"]
	body_size = size
	orbit_sign = -1.0 if randf() < 0.5 else 1.0
	ability_cooldown = randf_range(1.0, 3.0)
	wobble_phase = randf() * TAU
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")

	# glossy jelly material (one per enemy, since its colour changes)
	material = StandardMaterial3D.new()
	material.albedo_color = ROLE_COLORS[role]
	material.roughness = 0.2
	material.rim_enabled = true
	material.rim = 0.7
	material.rim_tint = 0.5
	material.emission_enabled = true
	material.emission = ROLE_COLORS[role] * 0.3

	visual = Node3D.new()
	visual.scale = Vector3.ONE * size
	add_child(visual)

	mesh = MeshInstance3D.new()
	mesh.mesh = _get_blob_mesh()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh)

	var eyes := MeshInstance3D.new()
	eyes.mesh = _get_eye_mesh()
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(eyes)

	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45 * size
	collision.shape = shape
	collision.position.y = 0.45 * size
	add_child(collision)

	# Enemy role names are intentionally omitted from gameplay.
	# They will be introduced in a dedicated tutorial or help screen later.


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if dead or not is_instance_valid(player) or player.health <= 0:
		return
	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

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

	_update_visuals(delta, toward)

	if attack_timer <= 0.0 and flat_distance <= attack_range and absf(player.global_position.y - global_position.y) < 1.8 and not player.launched:
		player.take_damage(damage, self)
		attack_timer = attack_cooldown


# ---------- look ----------

func _update_visuals(delta: float, toward: Vector3) -> void:
	# turn the eyes toward the player
	var target_yaw := atan2(-toward.x, -toward.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	# jelly wobble: squash and stretch that keeps its volume, and pulses harder when telegraphing an attack
	var t := Time.get_ticks_msec() * 0.001
	var amp := 0.18 if telegraph else 0.07
	var freq := 18.0 if telegraph else 7.0
	var w := sin(t * freq + wobble_phase) * amp
	visual.scale = Vector3(1.0 - w * 0.6, 1.0 + w, 1.0 - w * 0.6) * body_size

	# colour: white when hit, yellow when telegraphing, otherwise the role colour
	var color: Color = ROLE_COLORS[role]
	if telegraph:
		color = TELEGRAPH_COLOR
	if hit_flash > 0.0:
		color = Color.WHITE
	if color != current_color:
		current_color = color
		material.albedo_color = color
		material.emission = color * 0.3


func squish(amount: int = 1) -> void:
	if dead:
		return
	health -= amount
	if health > 0:
		hit_flash = 0.15                    # survived the hit: flash white
		return
	dead = true
	remove_from_group("enemy")
	collision.set_deferred("disabled", true)
	died.emit(type)
	# squashed flat for a moment, then bursts into particles
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.5, 0.25, 1.5) * body_size, 0.06)
	tween.tween_callback(_burst)
	tween.tween_callback(queue_free)


func _burst() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var popup := Label3D.new()
	var manager := scene.get_node_or_null("WaveManager")
	popup.text = "+%d XP" % int(manager.coins_per_kill) if manager != null else "Defeated"
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.font_size = 48
	popup.pixel_size = 0.009
	popup.outline_size = 10
	scene.add_child(popup)
	popup.global_position = global_position + Vector3(0, 1.1 * body_size, 0)
	var tween := popup.create_tween().set_parallel()
	if not bool(SettingsManager.get_value("reduced_motion")):
		tween.tween_property(popup, "position:y", popup.position.y + 0.8, 0.7)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(popup.queue_free)
	var count := mini(18, maxi(0, 144 - get_tree().get_nodes_in_group("enemy_debris").size()))
	var default_gravity := maxf(0.01, float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)))
	for index in count:
		var part := RigidBody3D.new()
		part.mass = 0.15
		part.gravity_scale = gravity / default_gravity
		part.collision_layer = 0
		part.collision_mask = 1
		part.linear_damp = 0.4
		part.angular_damp = 0.8
		part.add_to_group("enemy_debris")
		var visual := MeshInstance3D.new()
		visual.mesh = _get_chunk_mesh()
		visual.material_override = _get_chunk_material(role)
		var size := randf_range(1.2, 2.2) * body_size
		visual.scale = Vector3.ONE * size
		part.add_child(visual)
		var collider := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.09 * size
		collider.shape = shape
		part.add_child(collider)
		var bounce := PhysicsMaterial.new()
		bounce.bounce = 0.35
		bounce.friction = 0.7
		part.physics_material_override = bounce
		scene.add_child(part)
		part.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.25, 0.8), randf_range(-0.3, 0.3)) * body_size
		part.linear_velocity = velocity * 0.25 + Vector3(randf_range(-6.0, 6.0), randf_range(5.0, 10.0), randf_range(-6.0, 6.0))
		part.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		get_tree().create_timer(3.5, false).timeout.connect(part.queue_free)


# ---------- shared meshes (built once) ----------

static func _get_blob_mesh() -> ArrayMesh:
	if _blob_mesh == null:
		_blob_mesh = _build_blob_mesh()
	return _blob_mesh


static func _get_eye_mesh() -> ArrayMesh:
	if _eye_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sx in [-1.0, 1.0]:
			_add_sphere(st, Vector3(sx * 0.17, 0.5, -0.41), 0.11, Color.WHITE)
			_add_sphere(st, Vector3(sx * 0.17, 0.5, -0.495), 0.055, Color(0.02, 0.02, 0.05))
		_eye_mesh = st.commit()
		_eye_mat = StandardMaterial3D.new()
		_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_eye_mat.vertex_color_use_as_albedo = true
		_eye_mesh.surface_set_material(0, _eye_mat)
	return _eye_mesh


static func _get_chunk_mesh() -> SphereMesh:
	if _chunk_mesh == null:
		_chunk_mesh = SphereMesh.new()
		_chunk_mesh.radius = 0.09
		_chunk_mesh.height = 0.18
		_chunk_mesh.radial_segments = 6
		_chunk_mesh.rings = 3
	return _chunk_mesh


static func _get_chunk_material(r: int) -> StandardMaterial3D:
	if not _chunk_mats.has(r):
		var m := StandardMaterial3D.new()
		m.albedo_color = ROLE_COLORS[r]
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = ROLE_COLORS[r] * 0.5
		_chunk_mats[r] = m
	return _chunk_mats[r]


# lumpy dome with a flat base: wider than it is tall, bottom sits at y = 0
static func _build_blob_mesh() -> ArrayMesh:
	var rings := 12
	var segs := 16
	var grid: Array = []
	for r in rings + 1:
		var phi := PI * float(r) / rings
		var row: Array[Vector3] = []
		for s in segs:
			var theta := TAU * float(s) / segs
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var lump := 1.0 + 0.06 * sin(d.x * 5.0 + d.z * 3.0) + 0.05 * sin(d.y * 6.0 + d.x * 2.0)
			var p := d * 0.5 * lump
			p.y = p.y * 0.85 + 0.4
			if p.y < 0.0:
				p.y = 0.0
			row.append(p)
		grid.append(row)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s]
			var d2: Vector3 = grid[r + 1][s2]
			for v in [a, c, b, b, c, d2]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _add_sphere(st: SurfaceTool, center: Vector3, radius: float, color: Color) -> void:
	var rings := 6
	var segs := 8
	for i in rings:
		var p0 := PI * float(i) / rings
		var p1 := PI * float(i + 1) / rings
		for j in segs:
			var t0 := TAU * float(j) / segs
			var t1 := TAU * float(j + 1) / segs
			var a := center + radius * Vector3(sin(p0) * cos(t0), cos(p0), sin(p0) * sin(t0))
			var b := center + radius * Vector3(sin(p0) * cos(t1), cos(p0), sin(p0) * sin(t1))
			var c := center + radius * Vector3(sin(p1) * cos(t0), cos(p1), sin(p1) * sin(t0))
			var d := center + radius * Vector3(sin(p1) * cos(t1), cos(p1), sin(p1) * sin(t1))
			for v in [a, c, b, b, c, d]:
				st.set_color(color)
				st.add_vertex(v)
