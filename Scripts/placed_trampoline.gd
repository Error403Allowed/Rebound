extends "res://Scripts/trampoline.gd"

const COLORS = [Color(0.2, 0.9, 0.4), Color(0.2, 0.5, 1.0), Color(0.7, 0.3, 1.0)]
const SPEEDS = [12.0, 15.0, 20.0]
const LAUNCH_CHARGES = [4, 3, 2]
@export_range(0, 2) var strength: int = 0
var charges: int = 0
var charge_label: Label3D

func _ready() -> void:
	strength = clampi(strength, 0, 2)
	charges = LAUNCH_CHARGES[strength]
	trampoline_type = TrampolineType.STANDARD
	standard_launch_velocity = SPEEDS[strength]
	collision_layer = 0
	collision_mask = 2
	charge_label = Label3D.new()
	charge_label.position.y = 0.35
	charge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	charge_label.font_size = 44
	charge_label.pixel_size = 0.008
	add_child(charge_label)
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
	charges = maxi(0, charges - 1)
	_update_charges()
	if charges == 0:
		queue_free()

func _update_charges() -> void:
	if charge_label == null:
		return
	charge_label.text = str(charges)
	charge_label.modulate = Color.WHITE if charges > 1 else Color(1.0, 0.55, 0.35)
