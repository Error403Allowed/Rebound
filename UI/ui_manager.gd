extends CanvasLayer

const THEME = preload("res://UI/stomped_theme.tres")
const GLASS = preload("res://UI/liquid_glass.gdshader")
const BACKDROP = preload("res://UI/menu_backdrop.gdshader")
const ARENA := "res://Scenes/main.tscn"
const MENU_WORLD := "res://Scenes/menu_world.tscn"
const LESSONS := [
	["Intro", "Stomped is a horde-survival game with the focus of squishing enemies by bouncing noto them from a trampoline"],
	["MOVE WITH INTENT", "W A S D — move\nMouse — look and aim\nShift + forward — sprint\nSpace — jump (holding repeats jumps)\nQ — dash on ground or in air. Charge refills in 3 seconds; 20% minimum. More charge gives more speed and distance; capped at 100%. Each dash spends the meter.\nF — upgrades (banked XP; applies next run)\nEscape — settings\nR — restart with confirmation"],
	["Survival", "Survive endless waves in the grass arena. Launch from trampolines and land near enemies to damage them. There is no final victory wave: improve your run score. Earn XP immediately and spend it on upgrades during the run."],
	["MOVE WITH INTENT", "W A S D — move\nMouse — look and aim\nSpace — jump (holding repeats jumps)\nF — upgrades (banked XP; applies immediately)\nEscape — pause menu\nR — restart with confirmation"],
	["BUILD YOUR STOMPED", "Buy Stomped in the shop for 55 XP to unlock +1.5 launch velocity per consecutive bounce on the same trampoline, capped at +8. Without the upgrade, bounces use base launch strength. Switching trampolines resets the bonus. Charges still apply: no trampoline lasts forever."],
	["LAND YOUR ATTACK", "After a trampoline launch, land to trigger one impact. Enemies within 2 metres of your landing centre take your stomp damage, starting at 1. The shockwave expands to that radius. Direct descending contact from above also triggers a stomp. Landing on a trampoline can stomp and bounce together. Hitting an enemy stompeds you upward. The current build protects you from enemy contact during the launched state."],
	["READ THE ENEMIES", "CHASER: predictive pursuit and airborne repositioning.\nDODGER (wave 3+): yellow warning, then sidestep.\nFLANKER (wave 5+): angled interception.\nCHARGER (wave 7+): warning, committed rush, recovery.\nRoles and the basic/speedy variants are separate."],
	["SURVIVE THE WAVE", "Clear all living and pending enemies to finish a wave. Use the break to prepare. Score and XP update during the run. Death freezes gameplay and opens results. XP is credited as you earn it, and purchases apply immediately. Spend banked XP between runs. If a save fails, pending XP is retried on the next award or when leaving the run."]
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
var dash_bar: TextureProgressBar
var dash_text: Label
var fps_text: Label
var elapsed := 0.0
var modal: ConfirmationDialog
var pending_action := Callable()
var menu_world: Node3D
var settings_description: Label

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
	item.text = text.left(1).to_upper() + text.substr(1).to_lower() if text == text.to_upper() else text
	item.text = item.text.replace("Xp", "XP").replace(" xp", " XP")
	item.add_theme_font_size_override("font_size", int(size * (1.18 if bool(SettingsManager.get_value("large_text")) else 1.0)))
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func _button(parent: Node, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text.left(1).to_upper() + text.substr(1).to_lower() if text == text.to_upper() else text
	item.text = item.text.replace("Xp", "XP").replace(" xp", " XP")
	item.custom_minimum_size.y = 48
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.mouse_entered.connect(_animate_button.bind(item, true))
	item.mouse_exited.connect(_animate_button.bind(item, false))
	item.focus_entered.connect(_animate_button.bind(item, true))
	item.focus_exited.connect(_animate_button.bind(item, false))
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func _clear() -> void:
	for child in root_ui.get_children():
		root_ui.remove_child(child)
		child.queue_free()
	hud = null

func _page(title: String, subtitle: String = "") -> void:
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _manager() == null or (screen == "loading" and is_instance_valid(menu_world)):
		_show_menu_world()
		shade.color = Color(0.012, 0.02, 0.04, 0.22)
	else:
		_clear_menu_world()
		shade.color = Color(0.012, 0.02, 0.04, 0.48)
	root_ui.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	root_ui.add_child(margin)
	var center := MarginContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := screen == "loading"
	var desired_width := 620.0 if compact else 700.0 if screen == "title" else 1420.0 if screen == "settings" else 1060.0
	var desired_height := 300.0 if compact else 720.0 if screen == "title" else viewport_size.y - 96.0
	panel.custom_minimum_size = Vector2(maxf(240.0, minf(desired_width, viewport_size.x - 64.0)), maxf(180.0, minf(desired_height, viewport_size.y - 96.0)))
	if not bool(SettingsManager.get_value("high_contrast")):
		var clear_style := StyleBoxEmpty.new()

		panel.add_theme_stylebox_override("panel", clear_style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if screen == "title" else Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 36 if side == "left" or side == "right" else 28)
	panel.add_child(inset)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12 if screen == "title" else 18)
	if screen == "title":
		scroll.free()
		inset.add_child(content)
	else:
		inset.add_child(scroll)
		scroll.add_child(content)
	_label(content, title, 48).modulate = Color.WHITE if screen == "title" else Color(0.85, 0.77, 0.6)
	if not subtitle.is_empty():
		_label(content, subtitle, 20).modulate = Color(0.7, 0.78, 0.86)
	var rule := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.3, 0.65, 0.72, 0.6)
	line.thickness = 1
	rule.add_theme_stylebox_override("separator", line)
	content.add_child(rule)
	var hint := Label.new()
	hint.text = "ESC  BACK        TAB / ARROWS  NAVIGATE        ENTER  SELECT"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.6, 0.69, 0.77)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(36, viewport_size.y - 28)

func _show_menu_world() -> void:
	if menu_world != null and is_instance_valid(menu_world):
		return
	var packed := ResourceLoader.load(MENU_WORLD)
	if packed == null:
		return
	menu_world = (packed as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(menu_world)

func _clear_menu_world() -> void:
	if menu_world != null and is_instance_valid(menu_world):
		menu_world.queue_free()
	menu_world = null

func _focus_first() -> void:
	var buttons := root_ui.find_children("*", "Button", true, false)
	for button in buttons:
		if not button.disabled:
			button.grab_focus()
			return

func show_title() -> void:
	MusicManager.play_menu()
	screen = "title"
	get_tree().paused = false
	_page("STOMPED")
	_button(content, "START SURVIVAL", start_run)
	_button(content, "UPGRADES", func(): show_shop("title"))
	_button(content, "HOW TO PLAY", func(): open_help("title"))
	_button(content, "SETTINGS", func(): open_settings("title"))
	_button(content, "CREDITS", show_credits)
	_button(content, "QUIT", func(): confirm("Quit Stomped?", "Close the game?", func(): get_tree().quit()))
	_label(content, "BEST SCORE  %d     HIGHEST WAVE  %d     XP  %d" % [Progression.best_score, Progression.highest_wave, Progression.currency], 18)
	if Progression.load_notice != "": _label(content, Progression.load_notice, 18)
	_focus_first()

func _show_welcome() -> void:
	screen = "welcome"
	_page("WELCOME TO STOMPED", "Set up your experience before your first run.")
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
	_page("CREDITS", "STOMPED / HACKCLUB HAVEN GAME JAM")
	_label(content, "Shrravan — Lead programmer\nNiyat — Programmer and asset creator\nEngine — Godot Engine\nTeam credits taken from the project README.", 26)
	_button(content, "BACK TO TITLE", show_title)
	_focus_first()

func confirm(title: String, message: String, action: Callable) -> void:
	pending_action = action
	modal.title = title
	modal.dialog_text = message
	modal.popup_centered(Vector2i(540, 220))

func start_run() -> void:
	MusicManager.play_combat()
	if loading: return
	if not _bank_before_leaving(): return
	get_tree().paused = false
	screen = "loading"
	_page("Loading")
	load_bar = ProgressBar.new()
	load_bar.custom_minimum_size.y = 10
	load_bar.show_percentage = false
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
		health_text.text = "Health: %d/%d" % [player.health, player.max_health]
		wave_text.text = "XP: %d%s" % [Progression.currency, " (save pending)" if manager.bank_error != OK else ""]
		score_text.text = "Score: %d" % manager.score
		tier_text.text = '"E" to show trampoline' if player.cooldown_left <= 0.0 else "Trampoline ready in %.1f s" % player.cooldown_left
		dash_bar.value = player.dash_charge * 100.0
		dash_text.text = '"Q" dash: %d%%' % int(round(player.dash_charge * 100.0))
		dash_bar.modulate = Color(0.45, 1.0, 0.75) if player.dash_charge >= 0.999 else Color.WHITE if player.dash_charge >= player.dash_minimum_charge else Color(0.6, 0.65, 0.7)
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

func _hud_label(parent: Node, text: String, size: int = 22) -> Label:
	var label := _label(parent, text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _hud_bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.35)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	for style in [track, fill]:
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func show_game() -> void:
	_clear_menu_world()
	screen = ""
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(hud)
	var left := VBoxContainer.new()
	left.position = Vector2(20, 20)
	left.custom_minimum_size.x = 320
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(left)
	_hud_label(left, '"F" for upgrades')
	wave_text = _hud_label(left, "XP: %d" % Progression.currency)
	score_text = _hud_label(left, "Score: 0")
	fps_text = _hud_label(left, "")
	var right := VBoxContainer.new()
	hud.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -480
	right.offset_right = -20
	right.offset_top = 20
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_text = _hud_label(right, "Health: 100/100")
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_bar = _hud_bar(right, Color(0.3, 0.95, 0.6), 14)
	tier_text = _hud_label(right, '"E" to place trampoline')
	tier_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _hud_label(hud, '"Esc" to pause', 14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -40
	hint.offset_bottom = -14

	var dash_box := VBoxContainer.new()
	hud.add_child(dash_box)
	dash_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dash_box.offset_left = -120
	dash_box.offset_right = 120
	dash_box.offset_top = -76
	dash_box.offset_bottom = -20
	dash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_text = _hud_label(dash_box, '"Q" dash: 100%', 18)
	dash_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_bar = TextureProgressBar.new()
	dash_bar.fill_mode = TextureProgressBar.FILL_BILINEAR_LEFT_AND_RIGHT
	dash_bar.max_value = 100.0
	dash_bar.custom_minimum_size = Vector2(240, 8)
	dash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 240
	texture.height = 8
	dash_bar.texture_progress = texture
	dash_bar.nine_patch_stretch = true
	dash_box.add_child(dash_bar)
	var player := _player()
	if player != null: player.hud.hide()
	var manager := _manager()
	if manager != null:
		manager.info.hide()
		manager.results.hide()

func show_pause() -> void:
	MusicManager.pause_to_menu()
	screen = "pause"
	_page("PAUSED", "The arena, enemies, attacks and wave countdown are frozen.")
	var manager := _manager()
	if manager != null:
		_label(content, "Wave %d / Score %d / Kills %d / Run XP %d\nTime survived: %ds" % [manager.wave, manager.score, manager.kills, manager.currency, int(elapsed)], 26)
	_button(content, "RESUME", func():
		_manager()._resume()
		show_game())
	_button(content, "SETTINGS", func(): open_settings("pause"))
	_button(content, "HOW TO PLAY", func(): open_help("pause"))
	_button(content, "RESTART RUN", request_restart)
	_button(content, "MAIN MENU", func(): confirm("End this run?", "Your run will end. Any pending XP save will be retried.", leave_run))
	_button(content, "QUIT", func(): confirm("Quit Stomped?", "Your run will end. Any pending XP save will be retried.", quit_game))
	_focus_first()

func show_results() -> void:
	screen = "results"
	var manager := _manager()
	_page("NEW PERSONAL BEST" if manager.new_best else "DEFEAT")
	_label(content, str(manager.score), 72)
	_label(content, "FINAL SCORE", 20)
	_label(content, "Wave reached: %d / Waves cleared: %d\nEnemies defeated: %d / Time: %ds" % [manager.wave, manager.waves_cleared, manager.kills, int(elapsed)], 26)
	_label(content, "XP EARNED  %d     BALANCE  %d" % [manager.currency, Progression.currency], 28)
	if not manager.banked:
		_label(content, "Progress could not be saved. Your earned XP is still held in this run. Retry before leaving.", 22)
		_button(content, "RETRY SAVE", func():
			manager.bank_run()
			show_results())
	_button(content, "PLAY AGAIN", start_run)
	var shop := _button(content, "UPGRADES", func(): show_shop("results"))
	shop.disabled = not manager.banked
	_button(content, "SETTINGS", func(): open_settings("results"))
	_button(content, "MAIN MENU", leave_run)
	_button(content, "QUIT", func(): confirm("Quit Stomped?", "Your banked progress is saved.", quit_game))
	_focus_first()

func request_restart() -> void:
	confirm("Restart run?", "End this run, save any pending XP, and begin again?", start_run)

func leave_run() -> void:
	if not _bank_before_leaving(): return
	_clear_menu_world()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/boot.tscn")

func _back() -> void:
	match return_screen:
		"game": _manager()._resume()
		"pause": show_pause()
		"results": show_results()
		"welcome": _show_welcome()
		_: show_title()

func open_settings(origin: String) -> void:
	return_screen = origin
	screen = "settings"
	_page("SETTINGS", "Your preferences apply immediately and are saved automatically.")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 440
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	content.add_child(body)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	var divider := VSeparator.new()
	body.add_child(divider)
	var help_box := VBoxContainer.new()
	help_box.custom_minimum_size.x = 260
	body.add_child(help_box)
	_label(help_box, "SETTING DETAILS", 18).modulate = Color(0.85, 0.77, 0.6)
	settings_description = _label(help_box, "Focus or hover a setting to view its details. Changes apply immediately and are saved automatically.", 20)
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
				_toggle(box, "Dynamic movement FOV", "dynamic_fov")
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
				_label(box, "WASD — Move\nMouse — Look\nSpace — Jump\nQ — Charged dash (ground and air)\n1 / 2 / 3 — Select trampoline\nE / Left click — Place\nF — Upgrades (immediate)\nEscape — Pause / back\nR — Request restart\n\nCustom key rebinding is still pending; these are the current bindings.", 24)
			"Data":
				_label(box, "Settings file: user://settings.cfg\nPreferences and permanent progression are saved separately.", 22)
				_button(box, "RESET SETTINGS", func(): confirm("Reset preferences?", "Restore default preferences? Your run is not reset.", func():
					SettingsManager.reset_defaults()
					open_settings(return_screen)))
				_button(box, "CLEAR ALL STATS", confirm_clear_stats)
				_label(box, "Save status: " + error_string(SettingsManager.last_save_error), 20)
	_button(content, "BACK", _back)
	_focus_first()

func confirm_clear_stats() -> void:
	confirm("Clear all stats?", "This permanently removes your XP, upgrades, best score, and highest wave. This cannot be undone.", func():
		Progression.reset_progress()
		open_settings(return_screen))

func _toggle(parent: Node, title: String, key: String) -> void:
	var item := CheckButton.new()
	item.text = title
	item.button_pressed = bool(SettingsManager.get_value(key))
	_setting_help(item, title + ": switch on or off. Changes are saved automatically.")
	item.toggled.connect(func(value: bool): SettingsManager.set_value(key, value))
	parent.add_child(item)

func _slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step_size: float) -> void:
	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.add_theme_constant_override("margin_left", 22)
	padding.add_theme_constant_override("margin_right", 22)
	padding.add_theme_constant_override("margin_top", 8)
	padding.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(padding)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	padding.add_child(row)
	var label := _label(row, "%s: %s" % [title, str(SettingsManager.get_value(key))])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_size
	slider.value = float(SettingsManager.get_value(key))
	slider.custom_minimum_size.y = 34
	slider.value_changed.connect(func(value: float):
		label.text = "%s: %s" % [title, str(snappedf(value, step_size))]
		SettingsManager.set_value(key, value))
	slider.custom_minimum_size.x = 220
	row.add_child(slider)
	_setting_help(slider, "%s: adjust from %s to %s. Changes are saved automatically." % [title, str(minimum), str(maximum)])

func _option(parent: Node, title: String, key: String, labels: Array, values: Array) -> void:
	_label(parent, title)
	var item := OptionButton.new()
	for text in labels: item.add_item(str(text))
	item.select(maxi(0, values.find(SettingsManager.get_value(key))))
	item.item_selected.connect(func(index: int): SettingsManager.set_value(key, values[index]))
	parent.add_child(item)
	_setting_help(item, title + ": choose an option. Changes are saved automatically.")

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
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_ESCAPE:
		return
	if modal.visible:
		get_viewport().set_input_as_handled()
		modal.hide()
		pending_action = Callable()
		_focus_first()
		return
	if screen == "":
		return
	get_viewport().set_input_as_handled()
	match screen:
		"help", "settings", "shop": _back()
		"credits": show_title()
		"pause": _manager()._resume()
		"results": leave_run()
		"welcome":
			SettingsManager.set_value("setup_complete", true)
			show_title()
		"loading_error": leave_run()
		"title": confirm("Quit Stomped?", "Close the game?", quit_game)


func _bank_before_leaving() -> bool:
	var manager := _manager()
	if manager == null:
		return true
	if manager.bank_run() == OK:
		return true
	get_tree().paused = true
	screen = "save_error"
	_page("COULD NOT SAVE", "Your run is still here. No currency has been discarded.")
	_label(content, "Check available disk space and file permissions, then retry. Error: " + error_string(manager.bank_error), 24)
	_button(content, "RETRY SAVE", func():
		if manager.bank_run() == OK:
			if manager.game_over: show_results()
			else: show_pause())
	return false

func quit_game() -> void:
	if _bank_before_leaving(): get_tree().quit()

func show_shop(origin: String) -> void:
	return_screen = origin
	screen = "shop"
	_page("BOUNCE BACK STRONGER", "UPGRADES / Applied immediately")
	_label(content, "AVAILABLE XP  %d" % Progression.currency, 34)
	for key in ["health", "stomp", "cooldown", "stomped"]:
		var definition: Dictionary = Progression.UPGRADES[key]
		var level: int = int(Progression.levels[key])
		var cap: int = int(definition.cap)
		var card := PanelContainer.new()
		content.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		_label(box, str(definition.title) + "     %d / %d" % [level, cap], 28)
		_label(box, str(definition.description), 20)
		var current := ""
		var upcoming := ""
		match key:
			"health":
				current = "%d starting health" % (100 + level * 20)
				upcoming = "%d starting health" % (100 + (level + 1) * 20)
			"stomp":
				current = "%d stomp damage" % (1 + level)
				upcoming = "%d stomp damage" % (2 + level)
			"stomped":
				current = "Unlocked: +1.5 per consecutive bounce, capped at +8" if level > 0 else "Locked: every bounce uses base launch strength"
				upcoming = "Unlock +1.5 per consecutive bounce, capped at +8"
			"cooldown":
				current = "%.1f / %.1f / %.1fs" % [5.0 - level * 0.5, 8.0 - level * 0.5, 12.0 - level * 0.5]
				upcoming = "%.1f / %.1f / %.1fs" % [5.0 - (level + 1) * 0.5, 8.0 - (level + 1) * 0.5, 12.0 - (level + 1) * 0.5]
		_label(box, "CURRENT  " + current, 22)
		if level < cap: _label(box, "NEXT  " + upcoming, 22)
		var price: int = Progression.price(key)
		var text := "MAXIMUM LEVEL" if level >= cap else "BUY / %d XP" % price
		if level < cap and Progression.currency < price: text = "NEED %d MORE XP" % (price - Progression.currency)
		var buy := _button(box, text, _purchase_upgrade.bind(key, origin))
		buy.disabled = level >= cap or Progression.currency < price
	_button(content, "BACK", _back)
	_focus_first()

func _purchase_upgrade(key: String, origin: String) -> void:
	var manager := _manager()
	if manager != null and not manager.banked:
		manager.bank_error = Progression.credit_run_total(manager.run_id, manager.currency)
		if manager.bank_error != OK:
			show_shop(origin)
			_label(content, "XP could not be saved. Purchase cancelled; retry when saving works.", 22)
			return
	var error: int = Progression.purchase(key)
	show_shop(origin)
	_label(content, "UPGRADE PURCHASED AND SAVED" if error == OK else "Purchase not completed: " + error_string(error), 22)


func _animate_button(button: Button, active: bool) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	if button.has_meta("hover_tween"):
		var previous: Tween = button.get_meta("hover_tween")
		if previous.is_valid(): previous.kill()
	var target := Color(1.08, 1.1, 1.12) if active else Color.WHITE
	if bool(SettingsManager.get_value("reduced_motion")):
		button.modulate = target
		return
	var tween := button.create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "modulate", target, 0.12)


func _setting_help(control: Control, description: String) -> void:
	control.tooltip_text = description
	var update := func():
		if is_instance_valid(settings_description):
			settings_description.text = description
	control.focus_entered.connect(update)
	control.mouse_entered.connect(update)
