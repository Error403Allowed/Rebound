
extends StaticBody3D

@export var mountain_height: float = 100.0
@export var base_radius: float = 35.0
@export var summit_radius: float = 2.0
@export var segments: int = 16
@export var levels: int = 12
@export var roughness: float = 5.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready():
	generate_mountain()


func generate_mountain():
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	var rings: Array[PackedVector3Array] = []

	# Generate horizontal rings of mountain vertices.
	for level in range(levels):
		var ring := PackedVector3Array()

		var height_ratio = float(level) / float(levels - 1)
		var radius = lerpf(base_radius, summit_radius, height_ratio)

		for segment in range(segments):
			var angle = TAU * float(segment) / float(segments)

			var variation = rng.randf_range(-roughness, roughness)
			var final_radius = radius + variation

			var x = cos(angle) * final_radius
			var z = sin(angle) * final_radius
			var y = height_ratio * mountain_height

			ring.append(Vector3(x, y, z))

		rings.append(ring)

	# Create the mesh.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rock_color = Color(0.32, 0.30, 0.28)
	var snow_color = Color(0.85, 0.88, 0.92)

	# Connect adjacent rings using triangles.
	for level in range(levels - 1):
		for segment in range(segments):
			var next_segment = (segment + 1) % segments

			var a = rings[level][segment]
			var b = rings[level + 1][segment]
			var c = rings[level][next_segment]
			var d = rings[level + 1][next_segment]

			var height_ratio = float(level) / float(levels)

			var color = rock_color.lerp(
				snow_color,
				smoothstep(0.72, 0.95, height_ratio)
			)

			surface.set_color(color)
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)

			surface.set_color(color)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)

	# Close the top of the mountain.
	var peak = Vector3(0, mountain_height, 0)

	for segment in range(segments):
		var next_segment = (segment + 1) % segments

		surface.set_color(snow_color)
		surface.add_vertex(rings[levels - 1][segment])
		surface.add_vertex(peak)
		surface.add_vertex(rings[levels - 1][next_segment])

	surface.generate_normals()

	var generated_mesh = surface.commit()
	mesh_instance.mesh = generated_mesh

	# Apply vertex colours.
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh_instance.material_override = material

	# Generate collision from the same mesh.
	var collision_shape := ConcavePolygonShape3D.new()
	collision_shape.set_faces(generated_mesh.get_faces())
	collision.shape = collision_shape
