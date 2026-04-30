extends Node2D

const BASE_SCALE: float = 1.2

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func play_slash(scale_multiplier: float = 1.0, facing_angle: float = 0.0) -> void:
	rotation = facing_angle
	scale = Vector2.ONE * max(scale_multiplier * BASE_SCALE, 0.1)
	modulate = Color(1, 1, 1, 1)
	var lifetime: float = 0.26

	if animated_sprite != null:
		if animated_sprite.sprite_frames != null:
			var anim_name: StringName = &"slash_up"
			if facing_angle > 0.0:
				anim_name = &"slash_down"
			if not animated_sprite.sprite_frames.has_animation(anim_name):
				anim_name = animated_sprite.animation
			if animated_sprite.sprite_frames.has_animation(anim_name):
				var frame_count: int = animated_sprite.sprite_frames.get_frame_count(anim_name)
				var anim_fps: float = max(animated_sprite.sprite_frames.get_animation_speed(anim_name), 1.0)
				var speed_scale_value: float = 1.55
				animated_sprite.speed_scale = speed_scale_value
				lifetime = max(float(frame_count) / (anim_fps * speed_scale_value), 0.16)
				animated_sprite.play(anim_name)
				animated_sprite.frame = 0
				animated_sprite.frame_progress = 0.0
				animated_sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
			else:
				animated_sprite.play()
		else:
			animated_sprite.play()
	elif sprite != null:
		sprite.visible = true

	var tween: Tween = create_tween()
	tween.tween_interval(lifetime * 0.45)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.55)
	tween.parallel().tween_property(self, "scale", scale * 1.1, lifetime * 0.55)
	tween.tween_callback(queue_free)
