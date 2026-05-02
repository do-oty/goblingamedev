extends Control

const HIT_FLASH_SECONDS: float = 0.22

var hp_current: int = 1
var hp_max: int = 1
var hp_previous: int = 1
var hp_hit_flash_until: float = 0.0


func set_values(current_hp: int, max_hp: int) -> void:
	if current_hp < hp_previous:
		hp_hit_flash_until = (float(Time.get_ticks_msec()) / 1000.0) + HIT_FLASH_SECONDS
		_spawn_hit_particles()
	hp_current = max(current_hp, 0)
	hp_max = max(max_hp, 1)
	hp_previous = hp_current
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bar_rect: Rect2 = Rect2(Vector2.ZERO, size)
	if bar_rect.size.x <= 2.0 or bar_rect.size.y <= 2.0:
		return
	var hp_ratio: float = clamp(float(hp_current) / float(max(hp_max, 1)), 0.0, 1.0)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var hit_flash_strength: float = clamp((hp_hit_flash_until - now_seconds) / HIT_FLASH_SECONDS, 0.0, 1.0)
	_draw_segmented_bar(bar_rect, hp_ratio, Color(0.84, 0.1, 0.14), Color(1.0, 0.34, 0.36), hit_flash_strength, now_seconds)


func _draw_segmented_bar(
	bar_rect: Rect2,
	fill_ratio: float,
	base_color: Color,
	bright_color: Color,
	hit_flash: float,
	now_seconds: float
) -> void:
	draw_rect(bar_rect, Color(0.05, 0.05, 0.05, 0.95), true)
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 1.0), false, 1.1)
	var segment_size: float = max(8.0, bar_rect.size.y - 4.0)
	var gap: float = 2.0
	var step_width: float = segment_size + gap
	var segment_count: int = max(1, int(floor((bar_rect.size.x - 4.0 + gap) / step_width)))
	var fill_count: int = int(floor(fill_ratio * float(segment_count)))
	var start_x: float = bar_rect.position.x + 2.0
	var start_y: float = bar_rect.position.y + 2.0
	for i in range(segment_count):
		var x: float = start_x + (float(i) * step_width)
		var seg_rect: Rect2 = Rect2(x, start_y, segment_size, bar_rect.size.y - 4.0)
		if i < fill_count:
			var t: float = float(i) / float(max(segment_count - 1, 1))
			var seg_color: Color = base_color.lerp(bright_color, t)
			seg_color = seg_color.darkened(0.22 * (1.0 - t))
			var wave: float = sin((float(i) * 0.72) - (now_seconds * 7.4)) * 0.5 + 0.5
			seg_color = seg_color.lerp(bright_color, wave * 0.18)
			if hit_flash > 0.001:
				seg_color = seg_color.lerp(Color(1.0, 1.0, 1.0, 1.0), hit_flash * 0.85)
			draw_rect(seg_rect, seg_color, true)
			draw_rect(seg_rect, Color(0.0, 0.0, 0.0, 1.0), false, 0.7)
		else:
			draw_rect(seg_rect, Color(0.12, 0.12, 0.12, 0.9), true)
			draw_rect(seg_rect, Color(0.0, 0.0, 0.0, 1.0), false, 0.7)


func _spawn_hit_particles() -> void:
	for i in range(8):
		var droplet: Polygon2D = Polygon2D.new()
		droplet.polygon = PackedVector2Array([
			Vector2(0, -3),
			Vector2(3, 0),
			Vector2(0, 3),
			Vector2(-3, 0)
		])
		droplet.color = Color(0.85, 0.08, 0.08, 0.85)
		droplet.position = Vector2(randf_range(0.0, size.x), randf_range(0.0, size.y))
		droplet.z_index = 4
		add_child(droplet)
		var drift: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10.0, 22.0)
		var bleed_tween: Tween = create_tween()
		bleed_tween.tween_property(droplet, "position", droplet.position + drift, 0.28)
		bleed_tween.parallel().tween_property(droplet, "modulate:a", 0.0, 0.28)
		bleed_tween.tween_callback(droplet.queue_free)
