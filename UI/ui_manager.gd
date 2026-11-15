extends CanvasLayer

const THEME = preload("res://UI/rebound_theme.tres")
const GLASS = preload("res://UI/liquid_glass.gdshader")
const BACKDROP = preload("res://UI/menu_backdrop.gdshader")
const ARENA := "res://Scenes/main.tscn"
const MENU_WORLD := "res://Scenes/menu_world.tscn"
const LESSONS := [
	["Intro", "Rebound is a horde-survival game with the focus of squishing enemies by bouncing noto them from a trampolines"],
	["Controls", "W A S D — move\nMouse — look and aim\nSpace — jump \nQ — dash on ground or in air. More charge gives more speed and distance; capped at 100%. Each dash spends the meter.\nF — upgrades (banked XP; applies next run)\nEscape — settings\nR — restart with confirmation"],
	["How to Play", "Survive endless waves in the grass arena. Place trampolines, and launch from them, landing on enemies to damage them. Earn EXP on enemy defeat, and spend it in the shop to purchase upgrades"],
	["Thats all!", "Good luck, and have fun"],
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
	var buttons := _focusable_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _focusable_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node in root_ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and not button.disabled:
			result.append(button)
	return result

func _wrap_focus(direction: int) -> void:
	var buttons := _focusable_buttons()
	if buttons.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner() as Button
	var index := buttons.find(current)
	if index < 0:
		index = 0 if direction > 0 else buttons.size() - 1
	else:
		index = wrapi(index + direction, 0, buttons.size())
	buttons[index].grab_focus()

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
		"title": confirm("Quit Rebound?", "Close the game?", quit_game)


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
	for key in ["health", "stomp", "cooldown", "rebound"]:
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
			"rebound":
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
