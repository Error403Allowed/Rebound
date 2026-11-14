extends SceneTree

const FIXTURE := "res://Tests/.stage4-fixture.cfg"
const INVALID := "res://Tests/.stage4-invalid.cfg"
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run_tests() -> void:
	var progression = root.get_node("Progression")
	progression.storage_path = FIXTURE
	progression.load_progress()
	if "--readback" in OS.get_cmdline_user_args():
		check(progression.currency == 0, "separate process restores remaining currency")
		check(progression.levels == {"health": 1, "stomp": 1, "cooldown": 1}, "separate process restores purchased levels")
		check(progression.best_score == 500 and progression.highest_wave == 3, "separate process restores records")
		await test_run_integration(progression)
		print("STAGE4 READBACK FAILURES: ", failures)
		quit(0 if failures == 0 else 1)
		return
	check(progression.currency == 0 and progression.levels.health == 0, "missing save uses defaults")
	var id: int = progression.begin_run()
	check(progression.finish_run(id, 100, 500, 3) == OK, "run currency and records saved")
	check(progression.finish_run(id, 100, 500, 3) == OK and progression.currency == 100, "same run cannot bank twice")
	check(progression.purchase("health") == OK and progression.currency == 75, "health purchase and deduction")
	check(progression.purchase("stomp") == OK and progression.currency == 0, "stomp purchase and deduction")
	check(progression.purchase("cooldown") != OK and progression.currency == 0, "insufficient funds rejected")
	id = progression.begin_run()
	check(progression.finish_run(id, 40, 100, 1) == OK and progression.best_score == 500, "lower score does not replace record")
	check(progression.purchase("cooldown") == OK and progression.currency == 0, "cooldown purchase and deduction")
	var base: Array[float] = [5.0, 8.0, 12.0]
	check(progression.upgraded_health(100) == 120 and progression.upgraded_stomp(1) == 2, "upgraded health and damage")
	check(progression.upgraded_cooldowns(base) == [4.5, 7.5, 11.5] and base == [5.0, 8.0, 12.0], "cooldowns calculated without mutating base")
	check(progression.upgraded_health(100) == progression.upgraded_health(100), "repeated base calculation is stable")
	progression.levels.health = 5
	progression.currency = 10000
	check(progression.purchase("health") != OK and progression.levels.health == 5 and progression.currency == 10000, "level cap enforced without charging")
	progression.load_progress()
	check(progression.currency == 0 and progression.levels.health == 1, "reload restores last saved purchase state")
	progression.currency = 100
	progression.storage_path = "res://Tests/.stage4-no-directory/progression.cfg"
	check(progression.purchase("health") != OK and progression.currency == 100 and progression.levels.health == 1, "failed purchase save rolls back balance and level")
	id = progression.begin_run()
	check(progression.finish_run(id, 10, 999, 9) != OK and progression.currency == 100 and progression.best_score == 500, "failed banking save rolls back currency and records")
	progression.storage_path = FIXTURE
	progression.load_progress()
	var config := ConfigFile.new()
	config.set_value("progression", "version", 1)
	config.set_value("progression", "currency", -5)
	config.set_value("progression", "levels", {"health": 999, "stomp": "bad", "cooldown": -1})
	config.save(INVALID)
	progression.storage_path = INVALID
	progression.load_progress()
	check(progression.currency == 0 and progression.levels == {"health": 0, "stomp": 0, "cooldown": 0}, "invalid save values use safe defaults")
	progression.storage_path = FIXTURE
	progression.load_progress()
	print("STAGE4 TRANSACTION FAILURES: ", failures)
	quit(0 if failures == 0 else 1)

func test_run_integration(progression: Node) -> void:
	var ui = root.get_node("UIManager")
	ui.show_shop("title")
	check(ui.screen == "shop", "upgrade shop builds")
	ui.start_run()
	for frame in 3600:
		await process_frame
		if current_scene != null and ui.screen == "": break
	var player = get_first_node_in_group("player")
	if player == null:
		check(false, "upgraded player loads")
		return
	check(player.max_health == 120 and player.health == 120 and player.stomp_damage == 2 and player.trampoline_cooldowns == [4.5, 7.5, 11.5], "upgrades apply to new run")
	ui.start_run()
	var old_player = player
	for frame in 3600:
		await process_frame
		player = get_first_node_in_group("player")
		if player != null and player != old_player and ui.screen == "": break
	check(player != null and player.max_health == 120 and player.stomp_damage == 2 and player.trampoline_cooldowns == [4.5, 7.5, 11.5], "restarting does not compound upgrades")
	var manager = current_scene.get_node("WaveManager")
	manager.currency = 7
	manager.score = 200
	manager.wave = 2
	player.hit_timer = 0.0
	player.take_damage(player.max_health)
	check(paused and manager.banked and ui.screen == "results" and progression.currency == 7, "death pauses and banks earned currency")
	manager.bank_run()
	ui.show_results()
	check(progression.currency == 7, "results and repeated banking do not duplicate currency")
	ui.show_shop("results")
	ui._back()
	check(ui.screen == "results" and paused, "shop returns to frozen results")
