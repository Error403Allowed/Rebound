extends CanvasLayer

const THEME = preload("res://UI/rebound_theme.tres")
const ARENA := "res://Scenes/main.tscn"
const LESSONS := [
	["BOUNCE. STOMP. SURVIVE.", "Survive endless waves in the grass arena. Launch from trampolines and land near enemies to damage them. There is no final victory wave: improve your run score. Coins are run-only; permanent progression is not implemented."],
	["MOVE WITH INTENT", "W A S D — move\nMouse — look and aim\nShift + forward — sprint\nSpace — jump (holding repeats jumps)\nEscape — pause\nR — restart with confirmation"],
	["CHOOSE YOUR TRAMPOLINE", "1 GREEN: launch 12 / 4 charges / 5-second cooldown\n2 BLUE: launch 15 / 3 charges / 8-second cooldown\n3 PURPLE: launch 20 / 2 charges / 12-second cooldown\nAim at flat ground and LEFT CLICK. No E required. Placement uses one shared cooldown. Each launch consumes a charge."],
	["BUILD YOUR REBOUND", "Return to the same trampoline to add 1.5 launch velocity per consecutive bounce, capped at +8. Switching trampolines resets the bonus. Charges still apply: no trampoline lasts forever."],
	["LAND YOUR ATTACK", "After a trampoline launch, land to trigger one impact. Enemies within 1.5 metres of your landing centre take 1 damage. The shockwave expands to that radius. Direct descending contact from above also triggers a stomp. Hitting an enemy rebounds you upward. The current build protects you from enemy contact during the launched state."],
	["READ THE ENEMIES", "CHASER: predictive pursuit and airborne repositioning.\nDODGER (wave 3+): yellow warning, then sidestep.\nFLANKER (wave 5+): angled interception.\nCHARGER (wave 7+): warning, committed rush, recovery.\nRoles and the basic/speedy variants are separate."],
	["SURVIVE THE WAVE", "Clear all living and pending enemies to finish a wave. Use the break to prepare. Score and coins update during the run. Death freezes gameplay and opens results. Closing or restarting resets run currency. Settings are saved separately."]
]
var root_ui: Control
var content: VBoxContainer
var screen := ""
var return_screen := "title"
var lesson := 0
var loading := false
var load_bar: ProgressBar
var hud: Control
var health_bar: ProgressBar
var health_text: Label
var wave_text: Label
var score_text: Label
var tier_text: Label
var cooldown: ProgressBar
var fps_text: Label
var elapsed := 0.0
var modal: ConfirmationDialog
var pending_action := Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = THEME
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)
	modal = ConfirmationDialog.new()
	modal.theme = THEME
	modal.confirmed.connect(func():
		if pending_action.is_valid(): pending_action.call())
	add_child(modal)
	SettingsManager.changed.connect(_preference_changed)
	call_deferred("_apply_preferences")

func _manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("WaveManager") if scene != null else null

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _label(parent: Node, text: String, size: int = 22) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func _button(parent: Node, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 52
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func _clear() -> void:
	for child in root_ui.get_children():
		root_ui.remove_child(child)
		child.queue_free()
	hud = null

func _page(title: String, subtitle: String) -> void:
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.03, 0.05, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	root_ui.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_label(content, title, 48)
	_label(content, subtitle, 20).modulate = Color(0.55, 0.85, 0.75)

func _focus_first() -> void:
	var buttons := root_ui.find_children("*", "Button", true, false)
	for button in buttons:
		if not button.disabled:
			button.grab_focus()
			return

func show_title() -> void:
	screen = "title"
	get_tree().paused = false
	if not bool(SettingsManager.get_value("setup_complete")):
		_show_welcome()
		return
	_page("REBOUND", "BOUNCE. STOMP. SURVIVE.  /  SURVIVAL PROTOTYPE")
	_label(content, "Master your landing. Read the horde. Make the next bounce count.", 28)
	_button(content, "START SURVIVAL", start_run)
	_button(content, "HOW TO PLAY", func(): open_help("title"))
	_button(content, "SETTINGS", func(): open_settings("title"))
	_button(content, "CREDITS", show_credits)
	_button(content, "QUIT", func(): confirm("Quit Rebound?", "Close the game?", func(): get_tree().quit()))
	_label(content, "Stage 3 / permanent upgrades and saved records are not available.", 18)
	_focus_first()

func _show_welcome() -> void:
	screen = "welcome"
	_page("WELCOME TO REBOUND", "Set up your experience before your first run.")
	_label(content, "Launch from coloured trampolines, land within 1.5 metres of enemies, and survive endless waves. Settings can be reopened at any time from pause.", 28)
	_button(content, "ACCESSIBILITY & CAMERA SETTINGS", func(): open_settings("welcome"))
	_button(content, "LEARN TO PLAY", func():
		SettingsManager.set_value("setup_complete", true)
		open_help("title"))
	_button(content, "SKIP TO TITLE", func():
		SettingsManager.set_value("setup_complete", true)
		show_title())
	_focus_first()

func open_help(origin: String) -> void:
	return_screen = origin
	lesson = 0
	_show_lesson()

func _show_lesson() -> void:
	screen = "help"
	_page(str(LESSONS[lesson][0]), "FIELD GUIDE / %d OF %d" % [lesson + 1, LESSONS.size()])
	_label(content, str(LESSONS[lesson][1]), 26)
	var row := HBoxContainer.new()
	content.add_child(row)
	var previous := _button(row, "PREVIOUS", func():
		lesson -= 1
		_show_lesson())
	previous.disabled = lesson == 0
	var next := _button(row, "NEXT", func():
		lesson += 1
		_show_lesson())
	next.disabled = lesson == LESSONS.size() - 1
	_button(content, "BACK", _back)
	if return_screen == "title": _button(content, "START SURVIVAL", start_run)
	_focus_first()

func show_credits() -> void:
	screen = "credits"
	_page("CREDITS", "REBOUND / HACKCLUB HAVEN GAME JAM")
	_label(content, "Shrravan — Lead programmer\nNiyat — Programmer and asset creator\nEngine — Godot Engine\nTeam credits taken from the project README.", 26)
	_button(content, "BACK TO TITLE", show_title)
	_focus_first()

func confirm(title: String, message: String, action: Callable) -> void:
	pending_action = action
	modal.title = title
	modal.dialog_text = message
	modal.popup_centered(Vector2i(540, 220))

func start_run() -> void:
	get_tree().paused = false
	screen = "loading"
	_page("PREPARING YOUR RUN", "Bounce on the same trampoline to build launch power. Charges still apply.")
	load_bar = ProgressBar.new()
	load_bar.custom_minimum_size.y = 28
	content.add_child(load_bar)
	var error := ResourceLoader.load_threaded_request(ARENA)
	if error != OK:
		_label(content, "Could not request arena: %s" % error_string(error))
		_button(content, "BACK TO TITLE", show_title)
		return
	loading = true

func _process(delta: float) -> void:
	if loading:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(ARENA, progress)
		if not progress.is_empty(): load_bar.value = float(progress[0]) * 100.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			loading = false
			var packed := ResourceLoader.load_threaded_get(ARENA) as PackedScene
			var error := get_tree().change_scene_to_packed(packed)
			if error != OK:
				_label(content, "Arena could not be opened: " + error_string(error))
				return
			call_deferred("_enter_game")
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading = false
			_label(content, "Arena loading failed. Your settings have not been reset.")
			_button(content, "BACK TO TITLE", show_title)
	if screen == "" and is_instance_valid(hud):
		var player := _player()
		var manager := _manager()
		if player == null or manager == null: return
		if not get_tree().paused: elapsed += delta
		health_bar.max_value = player.max_health
		health_bar.value = player.health
		health_text.text = "HEALTH  %d / %d" % [player.health, player.max_health]
		wave_text.text = "WAVE %d IN %.1fs" % [manager.wave + 1, maxf(0.0, manager.break_timer)] if manager.in_break else "WAVE %d / %d ALIVE / %d PENDING" % [manager.wave, manager.alive, manager.to_spawn]
		score_text.text = "SCORE %d   |   RUN COINS %d   |   %ds" % [manager.score, manager.currency, int(elapsed)]
		tier_text.text = "[1] GREEN  [2] BLUE  [3] PURPLE\nSELECTED: %s / %s" % [player.TIER_NAMES[player.selected_tier], "READY — LEFT CLICK" if player.cooldown_left <= 0.0 else "COOLDOWN %.1fs" % player.cooldown_left]
		cooldown.max_value = player.trampoline_cooldowns[player.selected_tier]
		cooldown.value = maxf(0.0, cooldown.max_value - player.cooldown_left)
		fps_text.text = "%d FPS" % Engine.get_frames_per_second() if bool(SettingsManager.get_value("show_fps")) else ""

func _enter_game() -> void:
	for attempt in 120:
		if _manager() != null:
			break
		await get_tree().process_frame
	if _manager() == null:
		screen = "loading_error"
		_page("ARENA UNAVAILABLE", "The arena did not become ready. Return to the menu and retry.")
		_button(content, "MAIN MENU", leave_run)
		return
	elapsed = 0.0
	_apply_preferences()
	show_game()

func show_game() -> void:
	screen = ""
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(hud)
	var top := VBoxContainer.new()
	top.position = Vector2(28, 24)
	top.custom_minimum_size.x = 720
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	health_text = _label(top, "HEALTH")
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(320, 20)
	health_bar.show_percentage = false
	top.add_child(health_bar)
	wave_text = _label(top, "PREPARE", 26)
	score_text = _label(top, "SCORE")
	tier_text = _label(top, "TRAMPOLINES")
	cooldown = ProgressBar.new()
	cooldown.show_percentage = false
	cooldown.custom_minimum_size.y = 12
	top.add_child(cooldown)
	fps_text = _label(top, "", 18)
	_label(top, "WASD move / Shift sprint / Space jump\n1–3 select / Left click place / Escape pause", 18)
	var player := _player()
	if player != null: player.hud.hide()
	var manager := _manager()
	if manager != null:
		manager.info.hide()
		manager.results.hide()

func show_pause() -> void:
	screen = "pause"
	_page("PAUSED", "The arena, enemies, attacks and wave countdown are frozen.")
	var manager := _manager()
	if manager != null:
		_label(content, "Wave %d / Score %d / Kills %d / Run coins %d\nTime survived: %ds" % [manager.wave, manager.score, manager.kills, manager.currency, int(elapsed)], 26)
	_button(content, "RESUME", func():
		_manager()._resume()
		show_game())
	_button(content, "SETTINGS", func(): open_settings("pause"))
	_button(content, "HOW TO PLAY", func(): open_help("pause"))
	_button(content, "RESTART RUN", request_restart)
	_button(content, "MAIN MENU", func(): confirm("End this run?", "Run score and coins will be lost.", leave_run))
	_button(content, "QUIT", func(): confirm("Quit Rebound?", "This run will end. Run coins are not saved.", func(): get_tree().quit()))
	_focus_first()

func show_results() -> void:
	screen = "results"
	_page("RUN OVER", "Regroup. Read the horde. Bounce back.")
	var manager := _manager()
	_label(content, "FINAL SCORE %d\nWave reached: %d / Waves cleared: %d\nEnemies defeated: %d\nRun coins: %d (not banked)\nTime survived: %ds" % [manager.score, manager.wave, maxi(0, manager.wave - 1), manager.kills, manager.currency, int(elapsed)], 28)
	_button(content, "PLAY AGAIN", start_run)
	var upgrades := _button(content, "UPGRADES — NOT IMPLEMENTED", func(): pass)
	upgrades.disabled = true
	_button(content, "SETTINGS", func(): open_settings("results"))
	_button(content, "MAIN MENU", leave_run)
	_button(content, "QUIT", func(): confirm("Quit Rebound?", "Close the game?", func(): get_tree().quit()))
	_focus_first()

func request_restart() -> void:
	confirm("Restart run?", "Your current score and run coins will be lost.", start_run)

func leave_run() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/boot.tscn")

func _back() -> void:
	match return_screen:
		"pause": show_pause()
		"results": show_results()
		"welcome": _show_welcome()
		_: show_title()

func open_settings(origin: String) -> void:
	return_screen = origin
	screen = "settings"
	_page("SETTINGS", "Changes apply immediately. Preferences are saved locally; progression is not.")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 440
	content.add_child(tabs)
	for title in ["Gameplay", "Camera", "Audio", "Video", "Accessibility", "Controls", "Data"]:
		var scroll := ScrollContainer.new()
		scroll.name = title
		tabs.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
		match title:
			"Gameplay":
				_toggle(box, "Crosshair", "crosshair")
				_slider(box, "Crosshair size", "crosshair_size", 12, 48, 1)
				_toggle(box, "Placement preview", "placement_preview")
				_toggle(box, "Enemy role labels", "enemy_labels")
				_toggle(box, "Damage flash", "damage_flash")
			"Camera":
				_slider(box, "Mouse sensitivity", "mouse_sensitivity", 0.0002, 0.01, 0.0001)
				_toggle(box, "Invert vertical look", "invert_y")
				_slider(box, "Base field of view", "base_fov", 60, 110, 1)
				_toggle(box, "Dynamic sprint/jump FOV", "dynamic_fov")
				_slider(box, "FOV effect strength", "fov_strength", 0, 1.5, 0.05)
			"Audio":
				_slider(box, "Master volume", "master_volume", 0, 1, 0.05)
				_label(box, "Music and dedicated effects tracks are not yet authored. Separate category sliders will be added with real audio buses, not as nonfunctional controls.", 20)
			"Video":
				_option(box, "Display mode", "display_mode", ["Borderless fullscreen", "Windowed", "Exclusive fullscreen"], [0, 1, 2])
				_toggle(box, "VSync", "vsync")
				_option(box, "Frame limit", "fps_cap", ["Unlimited", "30", "60", "90", "120", "144", "165", "240"], [0, 30, 60, 90, 120, 144, 165, 240])
				_toggle(box, "Show FPS", "show_fps")
			"Accessibility":
				_slider(box, "UI scale", "ui_scale", 0.75, 1.5, 0.05)
				_toggle(box, "Larger text", "large_text")
				_toggle(box, "High contrast panels", "high_contrast")
				_toggle(box, "Reduced camera motion", "reduced_motion")
				_toggle(box, "Disable damage flashing", "reduced_flashing")
				_label(box, "Roles have text labels as well as colours. Menus support Tab/arrows, Enter and Escape.", 20)
			"Controls":
				_label(box, "WASD — Move\nMouse — Look\nShift — Sprint forward\nSpace — Jump\n1 / 2 / 3 — Select trampoline\nLeft click — Place\nEscape — Pause / back\nR — Request restart\n\nCustom key rebinding is still pending; these are the current bindings.", 24)
			"Data":
				_label(box, "Settings file: user://settings.cfg\nVersioned preferences only; no currency, upgrade levels or records.", 22)
				_button(box, "RESET SETTINGS", func(): confirm("Reset preferences?", "Restore default preferences? Your run is not reset.", func():
					SettingsManager.reset_defaults()
					open_settings(return_screen)))
				_label(box, "Save status: " + error_string(SettingsManager.last_save_error), 20)
	_button(content, "BACK", _back)
	_focus_first()

func _toggle(parent: Node, title: String, key: String) -> void:
	var item := CheckButton.new()
	item.text = title
	item.button_pressed = bool(SettingsManager.get_value(key))
	item.toggled.connect(func(value: bool): SettingsManager.set_value(key, value))
	parent.add_child(item)

func _slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step_size: float) -> void:
	var label := _label(parent, "%s: %s" % [title, str(SettingsManager.get_value(key))])
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_size
	slider.value = float(SettingsManager.get_value(key))
	slider.custom_minimum_size.y = 34
	slider.value_changed.connect(func(value: float):
		label.text = "%s: %s" % [title, str(snappedf(value, step_size))]
		SettingsManager.set_value(key, value))
	parent.add_child(slider)

func _option(parent: Node, title: String, key: String, labels: Array, values: Array) -> void:
	_label(parent, title)
	var item := OptionButton.new()
	for text in labels: item.add_item(str(text))
	item.select(maxi(0, values.find(SettingsManager.get_value(key))))
	item.item_selected.connect(func(index: int): SettingsManager.set_value(key, values[index]))
	parent.add_child(item)

func _preference_changed(_key: String, _value: Variant) -> void:
	_apply_preferences()

func _apply_preferences() -> void:
	var preferences: Dictionary = SettingsManager.values
	Engine.max_fps = int(preferences.fps_cap)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(preferences.master_volume))))
	if DisplayServer.get_name() != "headless":
		var mode: int = int(preferences.display_mode)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == 1 else DisplayServer.WINDOW_MODE_FULLSCREEN if mode == 0 else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == 0)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(preferences.vsync) else DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_factor = float(preferences.ui_scale)
	root_ui.theme = THEME.duplicate(true)
	root_ui.theme.default_font_size = 28 if bool(preferences.large_text) else 22
	if bool(preferences.high_contrast):
		var panel: StyleBoxFlat = root_ui.theme.get_stylebox("panel", "PanelContainer")
		panel.bg_color = Color.BLACK
		panel.border_color = Color.WHITE
	var player := _player()
	if player != null:
		player.mouse_sensitivity = float(preferences.mouse_sensitivity)
		player.base_fov = float(preferences.base_fov)
		player.crosshair.visible = bool(preferences.crosshair)
		player.crosshair.add_theme_font_size_override("font_size", int(preferences.crosshair_size))
	for enemy in get_tree().get_nodes_in_group("enemy"):
		for child in enemy.get_children():
			if child is Label3D: child.visible = bool(preferences.enemy_labels)

func _input(event: InputEvent) -> void:
	if modal.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and screen != "":
		get_viewport().set_input_as_handled()
		match screen:
			"help", "settings": _back()
			"credits": show_title()
			"pause":
				_manager()._resume()
				show_game()
			"title", "welcome": confirm("Quit Rebound?", "Close the game?", func(): get_tree().quit())
