extends Node

@export var enemy_scene: PackedScene
@export var world_size := 65.0              # must match the World script

@export_group("Waves")
@export var first_wave_delay := 5.0
@export var time_between_waves := 6.0
@export var base_count := 5                 # enemies in wave 1 is base_count + count_per_wave
@export var count_per_wave := 3
@export var max_alive := 25                 # cap on enemies at once, protects your fps
@export var heal_between_waves := 0         # HP restored when a wave is cleared (0 = none)

@export_group("Spawning")
@export var spawn_edge_inset := 2.0         # how far inside the walls enemies appear
@export var min_spawn_distance := 20.0      # never spawn closer to the player than this

var wave := 0
var to_spawn := 0                           # enemies still waiting to spawn this wave
var alive := 0
var kills := 0
var in_break := true
var break_timer := 0.0
var spawn_timer := 0.0
var spawn_interval := 1.0
var speedy_chance := 0.0

var player: Node3D
var info: Label
var banner: Label
var banner_tween: Tween


func _ready() -> void:
	break_timer = first_wave_delay
	_build_hud()


func _process(delta: float) -> void:
	if in_break:
		break_timer -= delta
		if break_timer <= 0.0:
			_start_wave()
	else:
		if to_spawn > 0 and alive < max_alive:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy()
				to_spawn -= 1
				alive += 1
				spawn_timer = spawn_interval
		elif to_spawn == 0 and alive == 0:
			_end_wave()
	_update_hud()


# ---------- waves ----------

func _start_wave() -> void:
	wave += 1
	in_break = false
	to_spawn = base_count + wave * count_per_wave
	spawn_interval = maxf(0.25, 1.2 - wave * 0.08)     # spawns get quicker each wave
	speedy_chance = clampf((wave - 1) * 0.1, 0.0, 0.5) # speedy slimes appear from wave 2
	spawn_timer = 0.0
	_show_banner("WAVE %d" % wave)


func _end_wave() -> void:
	in_break = true
	break_timer = time_between_waves
	_show_banner("WAVE %d CLEARED" % wave)
	if heal_between_waves > 0 and player != null:
		player.health = mini(player.health + heal_between_waves, player.max_health)


# ---------- spawning ----------

func _pick_type() -> int:
	# add more enemy types here later
	if randf() < speedy_chance:
		return Enemy.Type.SPEEDY
	return Enemy.Type.BASIC


func _spawn_point() -> Vector3:
	var lim := world_size / 2.0 - spawn_edge_inset
	var p := Vector3.ZERO
	for attempt in 10:
		var t := randf_range(-lim, lim)
		match randi() % 4:
			0: p = Vector3(t, 0.1, -lim)
			1: p = Vector3(t, 0.1, lim)
			2: p = Vector3(-lim, 0.1, t)
			_: p = Vector3(lim, 0.1, t)
		if player == null:
			return p
		var flat := Vector2(p.x - player.global_position.x, p.z - player.global_position.z)
		if flat.length() >= min_spawn_distance:
			return p
	return p


func _spawn_enemy() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	var e := Enemy.new()                     # no scene needed, the script builds everything
	e.type = _pick_type()                    # must be set before it enters the scene
	e.died.connect(_on_enemy_died)
	add_child(e)
	e.global_position = _spawn_point()


func _on_enemy_died(_enemy_type: int) -> void:
	alive -= 1
	kills += 1


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()

	info = Label.new()
	info.custom_minimum_size = Vector2(500, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	info.offset_top += 15
	layer.add_child(info)

	banner = Label.new()
	banner.custom_minimum_size = Vector2(700, 100)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 52)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_top -= 160
	banner.offset_bottom -= 160
	banner.modulate.a = 0.0
	layer.add_child(banner)

	add_child(layer)


func _update_hud() -> void:
	if in_break:
		info.text = "Wave %d starts in %d   |   Kills: %d" % [wave + 1, ceili(break_timer), kills]
	else:
		info.text = "Wave %d   |   Enemies left: %d   |   Kills: %d" % [wave, to_spawn + alive, kills]


func _show_banner(text: String) -> void:
	if banner_tween:
		banner_tween.kill()
	banner.text = text
	banner.modulate.a = 1.0
	banner_tween = create_tween()
	banner_tween.tween_interval(1.2)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)
