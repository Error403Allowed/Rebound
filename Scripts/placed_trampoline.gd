extends "res://Scripts/trampoline.gd"

const COLORS = [Color(0.2, 0.9, 0.4), Color(0.2, 0.5, 1.0), Color(0.7, 0.3, 1.0)]
const SPEEDS = [18.0, 22.0, 27.0]
@export_range(0, 2) var strength: int = 0

func _ready() -> void:
	strength = clampi(strength, 0, 2)
	trampoline_type = TrampolineType.STANDARD
	standard_launch_velocity = SPEEDS[strength]
	collision_layer = 0
	collision_mask = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[strength]
	$Visuals/Surface.material_override = material
	super._ready()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("combat_player"):
		return
	if body.get("dead") == true:
		return
	var character := body as CharacterBody3D
	if character == null or character.velocity.y > 0.0:
		return
	super._on_body_entered(body)
