extends Node

const SAVE_PATH := "user://savegame.json"
const DEFAULT_SAVE_DATA := {
	"player_name": "Goblin Hero",
	"progress": "new_game",
	"created_at_unix": 0,
	"coins": 0,
	"permanent_upgrades": {},
	"last_run_summary": {}
}

var latest_save_data: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	latest_save_data = _with_defaults({})
	latest_save_data["created_at_unix"] = Time.get_unix_time_from_system()
	_write_save(latest_save_data)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/maps/LobbyMap.tscn")


func continue_game() -> void:
	if has_save():
		latest_save_data = _with_defaults(load_save())
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/maps/LobbyMap.tscn")


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func load_save() -> Dictionary:
	if not has_save():
		return _with_defaults({})

	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return _with_defaults({})

	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if parsed is Dictionary:
		return _with_defaults(parsed as Dictionary)

	return _with_defaults({})


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
	latest_save_data = {}


func save_game(data: Dictionary) -> void:
	latest_save_data = _with_defaults(data)
	_write_save(latest_save_data)


func _write_save(data: Dictionary) -> void:
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("Could not create save file at %s" % SAVE_PATH)
		return

	save_file.store_string(JSON.stringify(data, "\t"))


func get_coins() -> int:
	var save_data: Dictionary = _ensure_save_loaded()
	return int(save_data.get("coins", 0))


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	var save_data: Dictionary = _ensure_save_loaded()
	save_data["coins"] = int(save_data.get("coins", 0)) + amount
	save_game(save_data)


func try_spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	var save_data: Dictionary = _ensure_save_loaded()
	var current_coins: int = int(save_data.get("coins", 0))
	if current_coins < amount:
		return false
	save_data["coins"] = current_coins - amount
	save_game(save_data)
	return true


func get_upgrade_level(upgrade_id: String) -> int:
	var save_data: Dictionary = _ensure_save_loaded()
	var upgrades: Dictionary = save_data.get("permanent_upgrades", {})
	return int(upgrades.get(upgrade_id, 0))


func buy_upgrade(upgrade_id: String, cost: int, max_level: int) -> bool:
	if get_upgrade_level(upgrade_id) >= max_level:
		return false
	if not try_spend_coins(cost):
		return false
	var save_data: Dictionary = _ensure_save_loaded()
	var upgrades: Dictionary = save_data.get("permanent_upgrades", {})
	upgrades[upgrade_id] = int(upgrades.get(upgrade_id, 0)) + 1
	save_data["permanent_upgrades"] = upgrades
	save_game(save_data)
	return true


func get_total_permanent_bonus() -> Dictionary:
	var bonus: Dictionary = {
		"max_health": 0,
		"move_speed": 0.0,
		"luck": 0.0,
		"dash_cooldown_reduction": 0.0
	}
	var hp_level: int = get_upgrade_level("max_health")
	var speed_level: int = get_upgrade_level("move_speed")
	var luck_level: int = get_upgrade_level("luck")
	var dash_level: int = get_upgrade_level("dash_mastery")
	bonus["max_health"] = hp_level * 8
	bonus["move_speed"] = float(speed_level) * 3.0
	bonus["luck"] = float(luck_level) * 0.08
	bonus["dash_cooldown_reduction"] = float(dash_level) * 0.03
	return bonus


func record_last_run_summary(summary: Dictionary) -> void:
	var save_data: Dictionary = _ensure_save_loaded()
	save_data["last_run_summary"] = summary.duplicate(true)
	save_game(save_data)


func get_last_run_summary() -> Dictionary:
	var save_data: Dictionary = _ensure_save_loaded()
	var summary: Variant = save_data.get("last_run_summary", {})
	if summary is Dictionary:
		return (summary as Dictionary).duplicate(true)
	return {}


func get_last_run_summary_text() -> String:
	var summary: Dictionary = get_last_run_summary()
	if summary.is_empty():
		return "No recent run summary."
	return "Last Run: %s | Lv %d | Time %s | Run Coins %d | DMG Taken %d" % [
		summary.get("result", "Run"),
		int(summary.get("level", 1)),
		String(summary.get("time_text", "00:00")),
		int(summary.get("run_coins", 0)),
		int(summary.get("damage_taken", 0))
	]


func _ensure_save_loaded() -> Dictionary:
	if latest_save_data.is_empty():
		latest_save_data = load_save()
	return latest_save_data


func _with_defaults(data: Dictionary) -> Dictionary:
	var merged: Dictionary = DEFAULT_SAVE_DATA.duplicate(true)
	for key in data.keys():
		merged[key] = data[key]
	if int(merged.get("created_at_unix", 0)) <= 0:
		merged["created_at_unix"] = Time.get_unix_time_from_system()
	if not (merged.get("permanent_upgrades", {}) is Dictionary):
		merged["permanent_upgrades"] = {}
	if not (merged.get("last_run_summary", {}) is Dictionary):
		merged["last_run_summary"] = {}
	return merged
