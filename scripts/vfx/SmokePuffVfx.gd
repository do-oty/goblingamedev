extends Node2D

const DEFAULT_SPEED_SCALE: float = 1.0
const FALLBACK_LIFETIME: float = 0.45

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func play_smoke(animation_name: StringName = &"default", speed_scale_value: float = DEFAULT_SPEED_SCALE) -> void:
	if animated_sprite == null:
		_queue_free_fallback()
		return
	if animated_sprite.sprite_frames == null:
		_queue_free_fallback()
		return

	var chosen_anim: StringName = animation_name
	if not animated_sprite.sprite_frames.has_animation(chosen_anim):
		if animated_sprite.sprite_frames.has_animation(&"default"):
			chosen_anim = &"default"
		else:
			var names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
			if names.is_empty():
				_queue_free_fallback()
				return
			chosen_anim = StringName(names[0])

	animated_sprite.speed_scale = max(speed_scale_value, 0.01)
	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(chosen_anim)
	if frame_count <= 0:
		_queue_free_fallback()
		return
	if animated_sprite.sprite_frames.get_animation_loop(chosen_anim):
		# Safety for accidentally looped smoke clips.
		_queue_free_fallback()
	animated_sprite.play(chosen_anim)
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0


func _queue_free_fallback() -> void:
	var t: Tween = create_tween()
	t.tween_interval(FALLBACK_LIFETIME)
	t.tween_callback(queue_free)


func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
