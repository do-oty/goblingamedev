extends Control

@onready var menu_screen: Control = $MenuScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var music_slider: HSlider = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/MusicSlider"
@onready var sfx_slider: HSlider = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/SfxSlider"
@onready var vibration_check: CheckButton = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/VibrationCheck"
@onready var notifications_check: CheckButton = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/NotificationsCheck"
@onready var settings_summary: Label = $"SettingsScreen/MarginContainer/ContentVBox/SettingsCard/SettingsMargin/SettingsVBox/SettingsSummary"

@onready var sequence_control: Control = $SequenceControl
@onready var splash_rect: TextureRect = $SequenceControl/SplashRect
@onready var cutscene_player: VideoStreamPlayer = $SequenceControl/CutscenePlayer
@onready var skip_label: Label = $SequenceControl/SkipLabel
@onready var skip_control: Control = $SequenceControl/SkipControl
@onready var sequence_bg: ColorRect = $SequenceControl/Background

@onready var menu_video_player: VideoStreamPlayer = $MenuVideoPlayer
@onready var menu_music_player: AudioStreamPlayer = $MenuMusicPlayer

func _ready() -> void:
	menu_screen.visible = false # Hide initially
	settings_screen.visible = false
	vibration_check.button_pressed = true
	notifications_check.button_pressed = false
	_update_settings_summary()
	
	# Setup sequence nodes
	splash_rect.texture = load("res://assets/cutscenes/ubihard.png")
	cutscene_player.stream = load("res://assets/cutscenes/startingcutscene.ogv")
	
	splash_rect.visible = true
	cutscene_player.visible = false
	skip_label.visible = false
	skip_control.visible = true
	
	splash_rect.modulate.a = 1.0
	splash_rect.scale = Vector2.ZERO
	
	# Connect finished signal
	if cutscene_player:
		cutscene_player.finished.connect(func():
			_end_sequence()
		)
	
	# Loop the background video if it finishes
	if menu_video_player:
		menu_video_player.finished.connect(func():
			menu_video_player.play()
		)
	
	# Connect input signal on SkipControl
	if skip_control:
		skip_control.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_end_sequence()
		)
	
	if GameState.played_intro:
		_end_sequence()
	else:
		GameState.played_intro = true
		_start_sequence()


func _start_sequence() -> void:
	var t = create_tween()
	
	# Setup pivot for centering scale
	splash_rect.pivot_offset = Vector2(200, 200)
	splash_rect.scale = Vector2.ZERO
	
	# Pop in!
	t.tween_property(splash_rect, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait
	t.tween_interval(2.0)
	# Fade out Splash and fade background color to black
	t.tween_property(splash_rect, "modulate:a", 0.0, 1.0)
	t.parallel().tween_property(sequence_bg, "color", Color(0, 0, 0, 1), 1.0)
	
	# Transition to Cutscene
	t.tween_callback(func():
		splash_rect.visible = false
		cutscene_player.visible = true
		cutscene_player.play()
		
		# Show skip label briefly
		skip_label.visible = true
		skip_label.modulate.a = 0.0
	)
	
	# Fade in skip label
	t.tween_property(skip_label, "modulate:a", 1.0, 0.5)
	# Wait
	t.tween_interval(2.0)
	# Fade out skip label
	t.tween_property(skip_label, "modulate:a", 0.0, 0.5)


func _end_sequence() -> void:
	if cutscene_player:
		cutscene_player.stop()
		cutscene_player.stream = null # Release stream to stop audio for sure
	sequence_control.visible = false
	
	# Now show and slide in the menu!
	menu_screen.visible = true
	
	# Play background video and music!
	if menu_video_player:
		menu_video_player.play()
	if menu_music_player:
		menu_music_player.play()
	
	var screen_width = get_viewport_rect().size.x
	menu_screen.offset_left = screen_width
	menu_screen.offset_right = screen_width
	
	await get_tree().process_frame
	
	var t = create_tween()
	t.tween_property(menu_screen, "offset_left", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(menu_screen, "offset_right", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


	
	# Prepare for sprites: Add TextureRect to buttons
	var start_btn = $MenuScreen/CenterContainer/Panel/PanelMargin/VBox/StartButton
	var settings_btn = $MenuScreen/CenterContainer/Panel/PanelMargin/VBox/SettingsButton
	var back_btn = $SettingsScreen/MarginContainer/ContentVBox/HeaderBar/BackButton
	
	for btn in [start_btn, settings_btn, back_btn]:
		if btn != null:
			var tex := TextureRect.new()
			tex.name = "Icon"
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.add_child(tex)


func _on_start_button_pressed() -> void:
	GameState.start_new_game()


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
