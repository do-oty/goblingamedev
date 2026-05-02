extends "res://scripts/hobgoblin.gd"

## Boss-tier hobgoblin: larger AOEs, quick dash chains, delayed crown ring after each slam.

const KING_EXTRA_VISUAL_SCALE: float = 1.38
const KING_HP_MULT: float = 1.4

var king_dash_segment_time: float = 0.0
var king_dash_segments_left: int = 0
var king_dash_burst_cd: float = 12.0


func _ready() -> void:
	hobgoblin_leap_aoe_radius_override = 134.0
	hobgoblin_leap_max_range_override = 300.0
	hobgoblin_leap_damage_mult_override = 1.88
	super._ready()
	add_to_group("world_boss")
	current_health = int(round(float(current_health) * KING_HP_MULT))
	elite_max_health = current_health
	$AnimatedSprite2D.scale *= KING_EXTRA_VISUAL_SCALE
	base_sprite_scale = $AnimatedSprite2D.scale
	xp_reward = max(xp_reward + 22, 32)
	xp_tier = "rainbow"
	z_index = 8
	king_dash_burst_cd = randf_range(8.0, 14.0)


func get_enemy_archetype() -> String:
	return "king_goblin"


func _update_archetype_behavior(delta: float, direction: Vector2, distance: float) -> void:
	king_dash_burst_cd = max(king_dash_burst_cd - delta, 0.0)
	if king_dash_segments_left > 0:
		king_dash_segment_time -= delta
		if king_dash_segment_time > 0.0:
			var dash_dir: Vector2 = (target_player.global_position - global_position).normalized() if distance > 14.0 else direction
			if dash_dir == Vector2.ZERO:
				dash_dir = Vector2.RIGHT
			global_position += dash_dir * 560.0 * delta
			_play_walk_animation(dash_dir)
			return
		king_dash_segments_left -= 1
		if king_dash_segments_left > 0:
			king_dash_segment_time = 0.11
			return
		king_dash_burst_cd = randf_range(8.0, 14.0)
	if (
		king_dash_burst_cd <= 0.0
		and king_dash_segments_left <= 0
		and not leap_is_winding_up
		and not leap_is_airborne
		and leap_landing_timer <= 0.0
		and distance > 130.0
		and distance < 480.0
	):
		king_dash_segments_left = 7
		king_dash_segment_time = 0.1
	super._update_archetype_behavior(delta, direction, distance)


func _apply_leap_impact_damage() -> void:
	super._apply_leap_impact_damage()
	var impact_pos: Vector2 = global_position
	var outer_r: float = _hob_leap_aoe_radius() * 1.32
	get_tree().create_timer(0.36).timeout.connect(func () -> void:
		if not is_instance_valid(self):
			return
		_king_crown_ring_damage(impact_pos, outer_r)
	)


func _king_crown_ring_damage(center: Vector2, outer_radius: float) -> void:
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	var d: float = target_player.global_position.distance_to(center)
	var inner_avoid: float = _hob_leap_aoe_radius() * 0.5
	if d <= inner_avoid or d > outer_radius:
		return
	var dmg: int = int(round(float(_get_contact_damage()) * 1.05))
	target_player.call("receive_damage", dmg)
	if target_player.has_method("add_screen_shake"):
		target_player.call("add_screen_shake", 9.0, 0.15)
