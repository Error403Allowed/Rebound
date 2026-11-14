extends Node3D

const PAD = preload("res://Scenes/placed_trampoline.tscn")
const COLORS = [Color(0.2, 0.9, 0.4), Color(0.2, 0.5, 1.0), Color(0.7, 0.3, 1.0)]
const NAMES = ["GREEN / Standard", "BLUE / Strong", "PURPLE / Super"]
@export var placement_range: float = 10.0
@export var green_cooldown: float = 5.0
@export var blue_cooldown: float = 8.0
@export var purple_cooldown: float = 12.0
var selected: int = 0
var remaining: float = 0.0
var valid: bool = false
var candidate := Vector3.ZERO
var active_pad: Node3D
var preview: MeshInstance3D
var preview_material: StandardMaterial3D
var label: Label
var clearance := BoxShape3D.new()
var player: CharacterBody3D
var camera: Camera3D

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	camera = player.get_node("Head/Camera3D") as Camera3D
	process_physics_priority = 20
	clearance.size = Vector3(3.15, 0.45, 3.15)
	preview = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3, 0.15, 3)
	preview.mesh = mesh
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview.material_override = preview_material
	add_child(preview)
	preview.top_level = true
	preview.hide()
	var hud := CanvasLayer.new()
	add_child(hud)
	label = Label.new()
	label.position = Vector2(24, 130)
	label.add_theme_font_size_override("font_size", 20)
	hud.add_child(label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-7, -16)
	crosshair.add_theme_font_size_override("font_size", 24)
	hud.add_child(crosshair)

func handle_event(event: InputEvent) -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or player.get("dead") == true:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			selected = event.physical_keycode - KEY_1
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_target()
		if valid and remaining <= 0.0:
			_place()
		return true
	return false

func _physics_process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	_update_target()
	var duration: float = _selected_cooldown()
	var state: String = "READY (%.0fs placement cooldown)" % duration if remaining <= 0.0 else "Cooldown: %.1fs" % remaining
	label.text = "%s | %s\n1/2/3 select | Left click place | One active trampoline" % [NAMES[selected], state]

func _update_target() -> void:
	valid = false
	preview.hide()
	if player.get("dead") == true or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 40.0, 7, [player.get_rid()])
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	candidate = point + Vector3.UP * 0.22
	preview.global_position = candidate
	preview.show()
	var normal: Vector3 = hit["normal"]
	var surface: Node = hit["collider"] as Node
	valid = normal.dot(Vector3.UP) >= 0.95 and origin.distance_to(point) <= placement_range
	valid = valid and surface is StaticBody3D
	if valid:
		for offset in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			var probe := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.25, point + offset - Vector3.UP * 0.25, 1)
			var support: Dictionary = space.intersect_ray(probe)
			if support.is_empty():
				valid = false
				break
			var support_normal: Vector3 = support["normal"]
			var support_position: Vector3 = support["position"]
			if support_normal.y < 0.95 or absf(support_position.y - point.y) > 0.08:
				valid = false
				break
	if valid:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = clearance
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.3)
		query.collision_mask = 7
		valid = space.intersect_shape(query, 1).is_empty()
	var tint: Color = COLORS[selected] if valid else Color(1.0, 0.18, 0.15)
	tint.a = 0.4 if remaining <= 0.0 else 0.18
	preview_material.albedo_color = tint

func _place() -> void:
	var pad: Node3D = PAD.instantiate() as Node3D
	pad.set("strength", selected)
	player.get_parent().add_child(pad)
	pad.global_position = candidate
	if is_instance_valid(active_pad):
		active_pad.set("monitoring", false)
		active_pad.queue_free()
	active_pad = pad
	remaining = _selected_cooldown()

func _selected_cooldown() -> float:
	var green: float = maxf(5.0, green_cooldown)
	var blue: float = maxf(green + 1.0, blue_cooldown)
	var purple: float = maxf(blue + 1.0, purple_cooldown)
	return [green, blue, purple][selected]
