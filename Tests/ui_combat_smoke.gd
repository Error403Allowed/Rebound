extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func run_tests() -> void:
	for path in ["res://Scenes/player.gd", "res://UI/ui_manager.gd", "res://UI/boot.gd", "res://UI/settings_store.gd", "res://Scenes/wave_manager.gd", "res://enemy.gd"]:
		var script = load(path)
		check(script != null and script.can_instantiate(), "compile " + path)
	var ui = root.get_node_or_null("UIManager")
	if ui == null or not ui.has_method("start_run"):
		check(false, "UI autoload available")
		quit(1)
		return
	ui.show_title()
	check(ui.screen in ["title", "welcome"], "startup menu")
	ui.open_help("title")
	for index in ui.LESSONS.size():
		ui.lesson = index
		ui._show_lesson()
	check(ui.screen == "help", "all tutorial pages build")
	ui.open_settings("title")
	check(ui.screen == "settings", "settings screen builds")
	ui.show_credits()
	check(ui.screen == "credits", "credits screen builds")
	ui.start_run()
	for frame in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://Scenes/main.tscn" and ui.screen == "":
			break
	check(current_scene != null and ui.screen == "", "menu to arena and HUD")
	var player = get_first_node_in_group("player")
	var manager = current_scene.get_node_or_null("WaveManager") if current_scene != null else null
	if player == null or manager == null:
		check(false, "player and wave manager available")
		quit(1)
		return
	for tier in 3:
		player.selected_tier = tier
		player._spawn_trampoline(Vector3(10 + tier * 4, 0, 10))
		var area: Area3D = null
		for child in current_scene.get_children():
			if child is Area3D:
				area = child
		player.velocity.y = -5.0
		player._on_tramp_entered(player, area)
		check(is_equal_approx(player.velocity.y, [12.0, 15.0, 20.0][tier]), "launch tier " + str(tier))
		check(int(area.get_meta("charges")) == [3, 2, 1][tier], "charge consumed tier " + str(tier))
	manager._spawn_enemy()
	var enemy = get_first_node_in_group("enemy")
	enemy.health = 3
	enemy.global_position = player.global_position + Vector3(1.0, 0, 0)
	manager._spawn_enemy()
	var outside: Node3D = null
	for candidate in get_nodes_in_group("enemy"):
		if candidate != enemy:
			outside = candidate
	outside.health = 3
	outside.global_position = player.global_position + Vector3(2.0, 0, 0)
	player.velocity.y = -8.0
	player._slam_impact()
	check(enemy.health == 2, "enemy inside radius takes damage")
	check(outside.health == 3, "enemy outside radius is unharmed")
	check(player.velocity.y == player.rebound_speed, "enemy hit rebounds player upward")
	manager._pause()
	var before: Vector3 = enemy.global_position
	var timer: float = enemy.attack_timer
	var hp: int = player.health
	var wave_timer: float = manager.break_timer
	player.take_damage(20, enemy)
	ui.open_settings("pause")
	await create_timer(0.25, true).timeout
	check(paused and enemy.global_position == before and enemy.attack_timer == timer and player.health == hp and manager.break_timer == wave_timer, "pause freezes movement, attacks, health and wave timer in settings")
	ui._back()
	check(ui.screen == "pause", "settings returns to pause")
	manager._resume()
	await create_timer(0.2, true).timeout
	check(not paused and ui.screen == "", "resume returns to gameplay")
	player.launched = false
	player.hit_timer = 0.0
	player.take_damage(player.max_health)
	check(paused and manager.game_over and ui.screen == "results", "death freezes arena and opens results")
	if failures.is_empty():
		print("ALL SMOKE TEST ASSERTIONS PASSED")
	quit(0 if failures.is_empty() else 1)
