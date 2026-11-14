extends Node3D

@export var world_size := 65.0        # playable area (metres)
@export var floor_size := 70.0        # matches the grass area_size
@export var wall_height := 40.0
@export var wall_thickness := 1.0
@export var wall_color := Color(0.5, 0.5, 0.5, 0.05)   # gray, alpha 0.05 = 5% visible
@export var floor_color := Color(0.07, 0.22, 0.04)     # must equal grass_green in the Scenery script


func _ready() -> void:
	build_floor()
	build_walls()


func build_floor() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# top surface sits exactly at y = 0, where the grass is planted
	make_box("Floor", Vector3(floor_size, 1.0, floor_size), Vector3(0, -0.5, 0), mat)


func build_walls() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var half := world_size / 2.0
	var t := wall_thickness
	var y := wall_height / 2.0
	var long := world_size + t * 2.0

	# inner faces land exactly on +-half, so the playable area is 65x65
	make_box("WallNorth", Vector3(long, wall_height, t), Vector3(0, y, -half - t / 2.0), mat, false)
	make_box("WallSouth", Vector3(long, wall_height, t), Vector3(0, y,  half + t / 2.0), mat, false)
	make_box("WallWest",  Vector3(t, wall_height, world_size), Vector3(-half - t / 2.0, y, 0), mat, false)
	make_box("WallEast",  Vector3(t, wall_height, world_size), Vector3( half + t / 2.0, y, 0), mat, false)


func make_box(node_name: String, size: Vector3, pos: Vector3, mat: Material, shadows := true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh_inst.mesh = box
	if not shadows:
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)
