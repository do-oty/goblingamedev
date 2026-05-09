extends Control

signal retry_pressed
signal lobby_pressed

var key_guidance_active: bool = false
var key_world_position: Vector2 = Vector2.ZERO
var player_world_position: Vector2 = Vector2.ZERO
var portal_locked: bool = true
var pulse_time: float = 0.0

var death_screen_active: bool = false
var kills_current: int = 0
var kills_target: int = 10
var map_label_text: String = "Grass Region"

var death_title_label: Label = null
var death_stats_label: Label = null
var retry_button: Button = null
var lobby_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_death_widgets()


func _process(delta: float) -> void:
	pulse_time += delta
	if key_guidance_active or portal_locked or death_screen_active:
		queue_redraw()


func _draw() -> void:
	if key_guidance_active and not death_screen_active:
		_draw_key_arrow()
	if portal_locked and not death_screen_active:
		_draw_locked_portal_icon()
	if death_screen_active:
		_draw_death_overlay()


func set_key_guidance(active: bool, key_pos: Vector2, player_pos: Vector2) -> void:
	key_guidance_active = active
	key_world_position = key_pos
	player_world_position = player_pos
	queue_redraw()


func set_portal_locked(is_locked: bool) -> void:
	portal_locked = is_locked
	queue_redraw()


func show_death_screen(current_kills: int, target_kills: int, map_name: String) -> void:
	death_screen_active = true
	kills_current = current_kills
	kills_target = target_kills
	map_label_text = map_name
	_update_death_widgets()
	queue_redraw()


func hide_death_screen() -> void:
	death_screen_active = false
	if death_title_label != null:
		death_title_label.visible = false
	if death_stats_label != null:
		death_stats_label.visible = false
	if retry_button != null:
		retry_button.visible = false
	if lobby_button != null:
		lobby_button.visible = false
	queue_redraw()


func _draw_key_arrow() -> void:
	var to_key: Vector2 = key_world_position - player_world_position
	if to_key.length() < 1.0:
		return
	var dir: Vector2 = to_key.normalized()
	var rect_size: Vector2 = size
	var center: Vector2 = rect_size * 0.5
	var margin: float = 36.0
	var max_x: float = max(center.x - margin, 1.0)
	var max_y: float = max(center.y - margin, 1.0)
	var t: float = min(max_x / max(abs(dir.x), 0.0001), max_y / max(abs(dir.y), 0.0001))
	var arrow_pos: Vector2 = center + dir * t
	var pulse_alpha: float = 0.42 + (0.52 * (0.5 + 0.5 * sin(pulse_time * 5.8)))
	var arrow_color: Color = Color(1.0, 0.85, 0.2, pulse_alpha)
	var side: Vector2 = dir.orthogonal() * 10.0
	var back: Vector2 = -dir * 18.0
	var p1: Vector2 = arrow_pos
	var p2: Vector2 = arrow_pos + back + side
	var p3: Vector2 = arrow_pos + back - side
	draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([arrow_color, arrow_color, arrow_color]))
	draw_circle(arrow_pos + (back * 0.45), 6.0, Color(1.0, 0.94, 0.65, pulse_alpha * 0.9))


func _draw_locked_portal_icon() -> void:
	var icon_center: Vector2 = Vector2(size.x - 78.0, 78.0)
	var ring_color: Color = Color(0.3, 0.56, 1.0, 0.82)
	var lock_color: Color = Color(0.85, 0.15, 0.15, 0.95)
	draw_circle(icon_center, 28.0, Color(0.1, 0.12, 0.2, 0.55))
	draw_arc(icon_center, 28.0, 0.0, TAU, 28, ring_color, 2.0)
	draw_line(icon_center + Vector2(-16, -16), icon_center + Vector2(16, 16), lock_color, 4.0)
	draw_line(icon_center + Vector2(16, -16), icon_center + Vector2(-16, 16), lock_color, 4.0)
	draw_rect(Rect2(icon_center + Vector2(-10, -2), Vector2(20, 15)), Color(0.2, 0.2, 0.24, 0.95), true)
	draw_arc(icon_center + Vector2(0, -2), 8.0, PI, TAU, 14, Color(0.75, 0.75, 0.8, 0.95), 2.0)


func _draw_death_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)


func _create_death_widgets() -> void:
	death_title_label = Label.new()
	death_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_title_label.add_theme_font_size_override("font_size", 42)
	death_title_label.text = "You Died"
	death_title_label.visible = false
	death_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_title_label.position = Vector2(-180, 140)
	death_title_label.size = Vector2(360, 60)
	death_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_title_label)

	death_stats_label = Label.new()
	death_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_stats_label.add_theme_font_size_override("font_size", 24)
	death_stats_label.visible = false
	death_stats_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_stats_label.position = Vector2(-260, 220)
	death_stats_label.size = Vector2(520, 100)
	death_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_stats_label)

	retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.visible = false
	retry_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	retry_button.position = Vector2(-170, 350)
	retry_button.size = Vector2(150, 52)
	retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
	retry_button.pressed.connect(_on_retry_pressed)
	add_child(retry_button)

	lobby_button = Button.new()
	lobby_button.text = "Back to Lobby"
	lobby_button.visible = false
	lobby_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lobby_button.position = Vector2(20, 350)
	lobby_button.size = Vector2(190, 52)
	lobby_button.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_button.process_mode = Node.PROCESS_MODE_ALWAYS
	lobby_button.pressed.connect(_on_lobby_pressed)
	add_child(lobby_button)


func _update_death_widgets() -> void:
	if death_title_label == null or death_stats_label == null or retry_button == null or lobby_button == null:
		return
	death_title_label.visible = true
	death_stats_label.visible = true
	retry_button.visible = true
	lobby_button.visible = true
	death_stats_label.text = "Kills: %d/%d\nMap: %s" % [kills_current, kills_target, map_label_text]


func _on_retry_pressed() -> void:
	retry_pressed.emit()


func _on_lobby_pressed() -> void:
	lobby_pressed.emit()
