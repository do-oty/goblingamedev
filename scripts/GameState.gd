extends Node

const SAVE_PATH := "user://savegame.json"

var latest_save_data: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	latest_save_data = {
		"player_name": "Goblin Hero",
		"progress": "new_game",
		"created_at_unix": Time.get_unix_time_from_system()
	}
	_write_save(latest_save_data)
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")


func continue_game() -> void:
	if has_save():
		latest_save_data = load_save()
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func load_save() -> Dictionary:
	if not has_save():
		return {}

	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return {}

	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
	latest_save_data = {}


func save_game(data: Dictionary) -> void:
	latest_save_data = data
	_write_save(data)


func _write_save(data: Dictionary) -> void:
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("Could not create save file at %s" % SAVE_PATH)
		return

	save_file.store_string(JSON.stringify(data, "\t"))
