extends Node
## Preferences only. Currency, upgrades and records belong to future Stage 4.

signal changed(key: String, value: Variant)
signal save_finished(error: int)

const SAVE_PATH := "user://settings.cfg"
const FORMAT_VERSION := 1
const DEFAULTS := {
	"setup_complete": false,
	"mouse_sensitivity": 0.0025,
	"invert_y": false,
	"base_fov": 75.0,
	"dynamic_fov": true,
	"fov_strength": 1.0,
	"crosshair": true,
	"crosshair_size": 22.0,
	"crosshair_color": Color.WHITE,
	"placement_preview": true,
	"enemy_labels": true,
	"damage_flash": true,
	"hud_opacity": 1.0,
	"ui_scale": 1.0,
	"large_text": false,
	"high_contrast": false,
	"reduced_motion": false,
	"reduced_flashing": false,
	"master_volume": 0.8,
	"display_mode": 0,
	"vsync": true,
	"fps_cap": 0,
	"show_fps": false,
}
const RANGES := {
	"mouse_sensitivity": Vector2(0.0002, 0.01),
	"base_fov": Vector2(60.0, 110.0),
	"fov_strength": Vector2(0.0, 1.5),
	"crosshair_size": Vector2(12.0, 48.0),
	"hud_opacity": Vector2(0.4, 1.0),
	"ui_scale": Vector2(0.75, 1.5),
	"master_volume": Vector2(0.0, 1.0),
}
var values: Dictionary = DEFAULTS.duplicate(true)
var last_save_error: int = OK
var last_saved_unix: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> int:
	if not DEFAULTS.has(key):
		return ERR_INVALID_PARAMETER
	values[key] = _validated(key, value)
	changed.emit(key, values[key])
	return save_preferences()

func _validated(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if RANGES.has(key):
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return fallback
		var number := float(value)
		if not is_finite(number):
			return fallback
		var bounds: Vector2 = RANGES[key]
		return clampf(number, bounds.x, bounds.y)
	if typeof(value) != typeof(fallback):
		return fallback
	if key == "display_mode" and int(value) not in [0, 1, 2]:
		return fallback
	if key == "fps_cap" and int(value) not in [0, 30, 60, 90, 120, 144, 165, 240]:
		return fallback
	return value

func load_preferences() -> void:
	values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	if config.get_value("metadata", "version", -1) != FORMAT_VERSION:
		return
	for key in DEFAULTS:
		values[key] = _validated(key, config.get_value("preferences", key, DEFAULTS[key]))

func save_preferences() -> int:
	var config := ConfigFile.new()
	config.set_value("metadata", "version", FORMAT_VERSION)
	for key in values:
		config.set_value("preferences", key, values[key])
	last_save_error = config.save(SAVE_PATH)
	if last_save_error == OK:
		last_saved_unix = int(Time.get_unix_time_from_system())
	save_finished.emit(last_save_error)
	return last_save_error

func reset_defaults() -> int:
	var completed: bool = bool(values.get("setup_complete", false))
	values = DEFAULTS.duplicate(true)
	values["setup_complete"] = completed
	for key in values:
		changed.emit(key, values[key])
	return save_preferences()
