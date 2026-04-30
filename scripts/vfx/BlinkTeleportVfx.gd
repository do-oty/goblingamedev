extends Node2D

const TP_SPEED_SCALE: float = 4.2

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func play_tp(animation_name: StringName = &"") -> void:
	if animated_sprite == null:
		queue_free()
		return
	if animated_sprite.sprite_frames == null:
		queue_free()
		return

	var chosen_anim: StringName = animation_name
	if chosen_anim == StringName(""):
		chosen_anim = animated_sprite.animation
	if not animated_sprite.sprite_frames.has_animation(chosen_anim):
		if animated_sprite.sprite_frames.has_animation(&"default"):
			chosen_anim = &"default"
		else:
			var names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
			if names.is_empty():
				queue_free()
				return
			chosen_anim = StringName(names[0])

	animated_sprite.speed_scale = TP_SPEED_SCALE
	animated_sprite.play(chosen_anim)
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0


func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
