extends Node3D

@export var ground_y := 0.0             # world height of the TOP of your floor
@export var floor_size := 70.0          # must match floor_size in the World script
@export var outer_size := 900.0
@export var rings := 22
@export var points_per_side := 48
@export var flat_distance := 160.0      # flat meadow out to here, then hills rise
@export var hill_height := 40.0
@export var create_environment := true  # turn off if you already have a WorldEnvironment + light

var noise := FastNoiseLite.new()
var grass_green := Color(0.07, 0.22, 0.04)   # must equal floor_color in the World script
var rock_gray := Color(0.42, 0.42, 0.45)


func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 0.004
	noise.fractal_octaves = 2
	build_terrain()
	if create_environment:
		build_environment()


func terrain_height(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z))
	var rise := smoothstep(flat_distance, flat_distance + 350.0, d)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return n * hill_height * rise


func ring_points(e: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var total := points_per_side * 4
	for i in total:
		var side := floori(float(i) / points_per_side)
		var t := float(i % points_per_side) / points_per_side
		var x := 0.0
		var z := 0.0
		match side:
			0:
				x = -e + 2.0 * e * t
				z = -e
			1:
				x = e
				z = -e + 2.0 * e * t
			2:
				x = e - 2.0 * e * t
				z = e
			_:
				x = -e
				z = e - 2.0 * e * t
		pts.append(Vector3(x, terrain_height(x, z), z))
	return pts


func add_vert(st: SurfaceTool, v: Vector3) -> void:
	var t := smoothstep(0.45, 0.85, v.y / hill_height)
	st.set_color(grass_green.lerp(rock_gray, t))
	st.add_vertex(v)


func build_terrain() -> void:
	var inner := floor_size / 2.0
	var outer := outer_size / 2.0

	var all_rings: Array[PackedVector3Array] = []
	for k in rings + 1:
		var e := lerpf(inner, outer, pow(float(k) / rings, 1.7))
		all_rings.append(ring_points(e))

	var total := points_per_side * 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for k in rings:
		for i in total:
			var j := (i + 1) % total
			var a := all_rings[k][i]
			var b := all_rings[k][j]
			var c := all_rings[k + 1][i]
			var d := all_rings[k + 1][j]
			for v in [a, c, d, a, d, b]:
				add_vert(st, v)

	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	# ignore parent transforms and pin to world space, just under the floor top
	inst.top_level = true
	inst.global_position = Vector3(0.0, ground_y - 0.05, 0.0)


func build_environment() -> void:
	var haze := Color(0.20, 0.26, 0.34)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.035, 0.065, 0.12)
	sky_mat.sky_horizon_color = haze
	sky_mat.ground_horizon_color = haze
	sky_mat.ground_bottom_color = Color(0.07, 0.09, 0.12)
	sky_mat.sky_energy_multiplier = 0.7

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.46, 0.6)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = haze
	env.fog_density = 0.002

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -30, 0)
	sun.light_color = Color(0.95, 0.83, 0.68)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
