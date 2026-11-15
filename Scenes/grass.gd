extends Node3D

@export var grass_material: ShaderMaterial
@export var area_size := 70.0
@export var chunk_size := 10.0
@export var world_size := 65.0       # must match the World script
@export var edge_margin := 0.3

@export_group("Near layer (detailed)")
@export var near_spacing := 0.28
@export var near_fade_start := 14.0
@export var near_fade_end := 22.0
@export var near_blades := 9

@export_group("Far layer (cheap)")
@export var far_spacing := 0.9
@export var far_grow_start := 14.0   # same band as the near fade, so they swap in place
@export var far_grow_end := 22.0
@export var far_fade_start := 40.0
@export var far_fade_end := 50.0
@export var far_blades := 5


func _ready() -> void:
	var near_mesh := make_tuft(near_blades, 0.22, 0.20, 0.38, 0.018, 0.032, true)
	var far_mesh := make_tuft(far_blades, 0.38, 0.18, 0.34, 0.028, 0.048, false)

	# each layer gets its own copy of the material with its own fade distances
	var near_mat := grass_material.duplicate() as ShaderMaterial
	near_mat.set_shader_parameter("grow_start", -10.0)
	near_mat.set_shader_parameter("grow_end", -5.0)
	near_mat.set_shader_parameter("fade_start", near_fade_start)
	near_mat.set_shader_parameter("fade_end", near_fade_end)

	var far_mat := grass_material.duplicate() as ShaderMaterial
	far_mat.set_shader_parameter("grow_start", far_grow_start)
	far_mat.set_shader_parameter("grow_end", far_grow_end)
	far_mat.set_shader_parameter("fade_start", far_fade_start)
	far_mat.set_shader_parameter("fade_end", far_fade_end)

	near_mesh.surface_set_material(0, near_mat)
	far_mesh.surface_set_material(0, far_mat)

	build_layer(near_mesh, near_spacing, near_fade_end)
	build_layer(far_mesh, far_spacing, far_fade_end)


func build_layer(mesh: Mesh, spacing: float, cull_after: float) -> void:
	var chunks := int(area_size / chunk_size)
	var half := area_size / 2.0
	var per_side := int(chunk_size / spacing)
	var limit := world_size / 2.0 - edge_margin

	for cx in chunks:
		for cz in chunks:
			var origin := Vector3(-half + cx * chunk_size, 0.0, -half + cz * chunk_size)
			var centre := origin + Vector3(chunk_size / 2.0, 0.0, chunk_size / 2.0)
			var transforms: Array[Transform3D] = []

			for gx in per_side:
				for gz in per_side:
					var pos := origin + Vector3((gx + randf()) * spacing, 0.0, (gz + randf()) * spacing)
					if absf(pos.x) > limit or absf(pos.z) > limit:
						continue
					pos.y = get_ground_height(pos.x, pos.z)
					var s := randf_range(0.92, 1.08)
					var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s, s))
					# stored relative to the chunk centre, so the chunk's own position is real
					transforms.append(Transform3D(b, pos - centre))

			if transforms.is_empty():
				continue

			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i, transforms[i])

			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.position = centre
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# safety cull only: the shader has already shrunk blades to nothing by then
			inst.visibility_range_end = cull_after + chunk_size
			add_child(inst)


func get_ground_height(_x: float, _z: float) -> float:
	return 0.0


func make_tuft(blades: int, spread: float, hmin: float, hmax: float,
		wmin: float, wmax: float, two_segments: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in blades:
		var a := randf() * TAU
		var base := Vector3(cos(a), 0.0, sin(a)) * spread * sqrt(randf())
		var h := randf_range(hmin, hmax)
		var w := randf_range(wmin, wmax)
		var _curve := randf_range(-0.22, 0.22)
		var rot := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(0.0, 0.18))

		var verts: Array[Vector3]
		if two_segments:
			var p: Array[Vector3] = [
				Vector3(-w, 0, 0), Vector3(w, 0, 0),
				Vector3(-w * 0.7, h * 0.5, 0), Vector3(w * 0.7, h * 0.5, 0),
				Vector3(0, h, 0)]
			for idx in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
				verts.append(p[idx])
		else:
			verts = [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(0, h, 0)]

		for v in verts:
			st.add_vertex(rot * v + base)
	return st.commit()
