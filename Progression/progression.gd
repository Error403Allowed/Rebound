extends Node

signal changed
signal save_failed(error: int)

const VERSION := 1
const UPGRADES := {
	"rebound": {"title": "Rebound", "description": "Unlock increasing launch power on consecutive bounces from the same trampoline: +1.5 per bounce, capped at +8.", "step": 1.5, "cap": 1, "cost": 55},
	"health": {"title": "Vitality", "description": "Increase maximum and starting health.", "step": 20, "cap": 5, "cost": 25},
	"stomp": {"title": "Impact", "description": "Deal more damage with every landing attack.", "step": 1, "cap": 3, "cost": 75},
	"cooldown": {"title": "Quick Setup", "description": "Reduce all placement cooldowns by 0.5 seconds per level.", "step": 0.5, "cap": 5, "cost": 40},
}
var storage_path := "user://progression.cfg"
var currency := 0
var levels: Dictionary = {"health": 0, "stomp": 0, "cooldown": 0, "rebound": 0}
var best_score := 0
var highest_wave := 0
var last_error: int = OK
var load_notice := ""
var next_run_id := 0
var active_runs: Dictionary = {}
var credited_runs: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()

func _snapshot() -> Dictionary:
	return {"version": VERSION, "currency": currency, "levels": levels.duplicate(true), "best_score": best_score, "highest_wave": highest_wave}

func _restore(data: Dictionary) -> void:
	currency = int(data.currency)
	levels = data.levels.duplicate(true)
	best_score = int(data.best_score)
	highest_wave = int(data.highest_wave)

func _valid_integer(value: Variant, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= maximum

func load_progress() -> void:
	currency = 0
	levels = {"health": 0, "stomp": 0, "cooldown": 0, "rebound": 0}
	best_score = 0
	highest_wave = 0
	load_notice = ""
	if not FileAccess.file_exists(storage_path):
		return
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error != OK or config.get_value("progression", "version", -1) != VERSION:
		load_notice = "Saved progress could not be read. Defaults are active; the existing file has not been changed."
		last_error = ERR_FILE_CORRUPT
		return
	var saved_levels: Variant = config.get_value("progression", "levels", {})
	if typeof(saved_levels) != TYPE_DICTIONARY:
		load_notice = "Some saved upgrades were invalid and have been reset."
		saved_levels = {}
	for key in UPGRADES:
		var value: Variant = saved_levels.get(key, 0)
		if _valid_integer(value, int(UPGRADES[key].cap)):
			levels[key] = value
		else:
			load_notice = "Some saved upgrades were invalid and have been reset."
	for key in ["currency", "best_score", "highest_wave"]:
		var value: Variant = config.get_value("progression", key, 0)
		if _valid_integer(value, 1000000000):
			set(key, int(value))
		else:
			load_notice = "Some saved values were invalid and have been reset."
	last_error = OK

func save_progress() -> int:
	var config := ConfigFile.new()
	var snapshot := _snapshot()
	for key in snapshot:
		config.set_value("progression", key, snapshot[key])
	var temporary := storage_path + ".tmp"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	last_error = error
	if error != OK:
		save_failed.emit(error)
	return error

func price(key: String) -> int:
	if not UPGRADES.has(key):
		return -1
	if int(levels[key]) >= int(UPGRADES[key].cap):
		return -1
	return int(UPGRADES[key].cost) * int(pow(2, int(levels[key])))

func purchase(key: String) -> int:
	var cost := price(key)
	if cost < 0:
		return ERR_INVALID_PARAMETER
	if currency < cost:
		return ERR_UNAVAILABLE
	var before := _snapshot()
	currency -= cost
	levels[key] = int(levels[key]) + 1
	var error := save_progress()
	if error != OK:
		_restore(before)
		return error
	load_notice = ""
	changed.emit()
	return OK

func upgraded_health(base: int) -> int:
	return base + int(levels.health) * int(UPGRADES.health.step)

func upgraded_stomp(base: int) -> int:
	return base + int(levels.stomp) * int(UPGRADES.stomp.step)

func upgraded_cooldowns(base: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for value in base:
		result.append(maxf(1.0, value - int(levels.cooldown) * float(UPGRADES.cooldown.step)))
	return result

func begin_run() -> int:
	next_run_id += 1
	active_runs[next_run_id] = false
	credited_runs[next_run_id] = 0
	return next_run_id

func finish_run(id: int, earned: int, score: int, wave: int) -> int:
	if not active_runs.has(id):
		return ERR_INVALID_PARAMETER
	if bool(active_runs[id]):
		return OK
	if earned < 0 or score < 0 or wave < 0:
		return ERR_INVALID_PARAMETER
	var before := _snapshot()
	currency = mini(1000000000, currency + maxi(0, earned - int(credited_runs.get(id, 0))))
	best_score = maxi(best_score, mini(1000000000, score))
	highest_wave = maxi(highest_wave, mini(1000000000, wave))
	var error := save_progress()
	if error != OK:
		_restore(before)
		return error
	credited_runs[id] = maxi(earned, int(credited_runs.get(id, 0)))
	active_runs[id] = true
	load_notice = ""
	changed.emit()
	return OK


func upgraded_rebound_increment() -> float:
	return 1.5 if int(levels.get("rebound", 0)) > 0 else 0.0


func credit_run_total(id: int, earned: int) -> int:
	if not active_runs.has(id) or bool(active_runs[id]) or earned < 0:
		return ERR_INVALID_PARAMETER
	var paid := int(credited_runs.get(id, 0))
	if earned <= paid:
		return OK
	var before := _snapshot()
	currency = mini(1000000000, currency + earned - paid)
	var error := save_progress()
	if error != OK:
		_restore(before)
		return error
	credited_runs[id] = earned
	changed.emit()
	return OK
