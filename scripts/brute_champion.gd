extends "res://scripts/enemy.gd"

## Standalone charger enemy (former brute elite behavior). Not rolled via elite tables.


func _ready() -> void:
	brute_mode = true
	super._ready()
	elite_brute_knockback_resist = 0.35
	elite_damage_multiplier *= 1.15
	current_health = int(round(float(current_health) * 1.35))
	elite_max_health = current_health
	brute_charge_cooldown = randf_range(BRUTE_CHARGE_COOLDOWN_MIN, BRUTE_CHARGE_COOLDOWN_MAX)


func get_enemy_archetype() -> String:
	return "brute_champion"
