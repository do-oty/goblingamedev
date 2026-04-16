extends Control

@onready var menu_screen: Control = $MenuScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var continue_button: Button = $"MenuScreen/CenterContainer/Panel/PanelMargin/VBox/ContinueButton"
@onready var music_slider: HSlider = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/MusicSlider"
@onready var sfx_slider: HSlider = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/SfxSlider"
@onready var vibration_check: CheckButton = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/VibrationCheck"
@onready var notifications_check: CheckButton = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/NotificationsCheck"
@onready var settings_summary: Label = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/SettingsSummary"


func _ready() -> void:
	continue_button.visible = GameState.has_save()
	menu_screen.visible = true
	settings_screen.visible = false
	vibration_check.button_pressed = true
	notifications_check.button_pressed = false
	_update_settings_summary()


func _on_start_button_pressed() -> void:
	GameState.start_new_game()


func _on_continue_button_pressed() -> void:
	GameState.continue_game()


func _on_settings_button_pressed() -> void:
	menu_screen.visible = false
	settings_screen.visible = true


func _on_close_settings_button_pressed() -> void:
	settings_screen.visible = false
	menu_screen.visible = true


func _on_music_slider_value_changed(_value: float) -> void:
	_update_settings_summary()


func _on_sfx_slider_value_changed(_value: float) -> void:
	_update_settings_summary()


func _on_vibration_check_toggled(_toggled_on: bool) -> void:
	_update_settings_summary()


func _on_notifications_check_toggled(_toggled_on: bool) -> void:
	_update_settings_summary()


func _update_settings_summary() -> void:
	settings_summary.text = "Music: %d%%\nSFX: %d%%\nVibration: %s\nNotifications: %s" % [
		int(round(music_slider.value)),
		int(round(sfx_slider.value)),
		"On" if vibration_check.button_pressed else "Off",
		"On" if notifications_check.button_pressed else "Off"
	]
