extends "res://scripts/enemy.gd"

## Standalone blink enemy (former blink elite behavior).


func _ready() -> void:
	blink_mode = true
	super._ready()
	elite_speed_multiplier *= 0.92
	elite_blink_cooldown = randf_range(1.2, 2.4)
	$AnimatedSprite2D.modulate = Color(0.6, 0.36, 0.9, 1.0)


func get_enemy_archetype() -> String:
	return "blink_stalker"
