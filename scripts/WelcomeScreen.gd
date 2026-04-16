extends Control

const SPLASH_DURATION_SECONDS: float = 3.0

@onready var logo_panel: PanelContainer = $"MarginContainer/VBox/LogoPanel"
@onready var subtitle_label: Label = $"MarginContainer/VBox/LogoPanel/SlideMargin/SlideVBox/SubtitleLabel"
@onready var progress_bar: ProgressBar = $"MarginContainer/VBox/ProgressBar"
@onready var splash_timer: Timer = $SplashTimer

var elapsed_time: float = 0.0


func _ready() -> void:
	modulate = Color(1, 1, 1, 0)
	progress_bar.max_value = SPLASH_DURATION_SECONDS
	progress_bar.value = 0.0
	_play_intro_animation()
	splash_timer.start(SPLASH_DURATION_SECONDS)


func _process(delta: float) -> void:
	elapsed_time = min(elapsed_time + delta, SPLASH_DURATION_SECONDS)
	progress_bar.value = elapsed_time


func _on_splash_timer_timeout() -> void:
	GameState.go_to_main_menu()


func _play_intro_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
	tween.parallel().tween_property(logo_panel, "scale", Vector2(1.05, 1.05), 1.2)
	tween.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(logo_panel, "scale", Vector2.ONE, 0.8)
