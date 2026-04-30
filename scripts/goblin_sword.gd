extends "res://scripts/enemy.gd"

const SWORD_HP_MULT: float = 1.55
const SWORD_SPEED_MULT: float = 1.2
const SWORD_DAMAGE_MULT: float = 1.35
const SWORD_VISUAL_SCALE: float = 1.08
const SWORD_CONTACT_COOLDOWN_MULT: float = 0.78
const SWORD_KNOCKBACK_RESIST_MULT: float = 0.42


func _ready() -> void:
	super._ready()
	current_health = int(round(float(current_health) * SWORD_HP_MULT))
	elite_max_health = current_health
	elite_speed_multiplier *= SWORD_SPEED_MULT
	elite_damage_multiplier *= SWORD_DAMAGE_MULT
	xp_reward = max(xp_reward + 1, 2)
	xp_tier = "green"
	$AnimatedSprite2D.scale *= SWORD_VISUAL_SCALE
	$AnimatedSprite2D.modulate = Color(1.0, 0.9, 0.82, 1.0)


func get_enemy_archetype() -> String:
	return "sword"


func _get_contact_cooldown() -> float:
	return CONTACT_COOLDOWN_SECONDS * SWORD_CONTACT_COOLDOWN_MULT


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	super.take_damage(amount, source_position, knockback_force * SWORD_KNOCKBACK_RESIST_MULT)
