extends Camera3D

var base_transform: Transform3D
var time := 0.0

func _ready() -> void:
	base_transform = transform
	make_current()

func _process(delta: float) -> void:
	if SettingsManager.get_value("reduced_motion"):
		transform = base_transform
		return
	time += delta
	var sway := sin(time * 0.15) * 0.04
	var bob := sin(time * 0.1) * 0.15
	transform = base_transform.rotated(Vector3.UP, sway)
	transform.origin = base_transform.origin + Vector3(0, bob, 0)
