extends Control

@onready var save_status_label: Label = $"CenterContainer/Panel/Margin/VBox/SaveStatusLabel"


func _ready() -> void:
	var save_data: Dictionary = GameState.load_save()
	if save_data.is_empty():
		save_status_label.text = "No mobile save loaded yet."
	else:
		save_status_label.text = "Continue point: %s" % save_data.get("progress", "unknown")


func _on_save_button_pressed() -> void:
	var updated_save: Dictionary = {
		"player_name": "Goblin Hero",
		"progress": "camp_cleared",
		"updated_at_unix": Time.get_unix_time_from_system()
	}
	GameState.save_game(updated_save)
	save_status_label.text = "Checkpoint saved for Continue."


func _on_back_to_menu_button_pressed() -> void:
	GameState.go_to_main_menu()
