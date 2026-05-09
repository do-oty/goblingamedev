extends "res://scripts/hobgoblin.gd"

## Boss-tier unit with its own pattern set (dash bursts + royal slam + delayed crown ring).

const KING_EXTRA_VISUAL_SCALE: float = 1.38
const KING_HP_MULT: float = 1.4
const KING_COLLIDER_SCALE: float = 1.42
const KING_COLLIDER_Y_OFFSET: float = 8.0
const KING_SLAM_COOLDOWN_MIN: float = 2.0
const KING_SLAM_COOLDOWN_MAX: float = 3.0
const KING_SLAM_WINDUP: float = 1.15
const KING_SLAM_AOE_RADIUS: float = 350.0
const KING_RING_DELAY: float = 1.05
const KING_RING_RADIUS_MULT: float = 1.62
const KING_DASH_SPEED: float = 440.0
const KING_DASH_SEGMENT_TIME: float = 0.34
const KING_DASH_SEGMENT_PAUSE: float = 0.08
const KING_DASH_COOLDOWN_MIN: float = 7.5
const KING_DASH_COOLDOWN_MAX: float = 11.5
const KING_DASH_WINDUP: float = 0.72
const KING_DASH_INDICATOR_LENGTH: float = 260.0
const KING_DASH_INDICATOR_WIDTH: float = 112.0
const KING_DASH_TARGET_COUNT: int = 4
const KING_DASH_TARGET_REACHED_DISTANCE: float = 26.0
const KING_DASH_TARGET_SPREAD: float = 168.0
const KING_DASH_TARGET_OVERSHOOT: float = 72.0
const KING_DASH_PREDICT_SECONDS: float = 0.28
const KING_ZONE_CAST_COOLDOWN_MIN: float = 12.0
const KING_ZONE_CAST_COOLDOWN_MAX: float = 18.0
const KING_ZONE_WARNING_TIME: float = 1.25
const KING_ZONE_ACTIVE_TIME: float = 2.8
const KING_ZONE_RADIUS: float = 420.0
const KING_ZONE_CENTER_OFFSET: float = 340.0
const KING_ZONE_DAMAGE_MULT: float = 1.08
const KING_ZONE_DAMAGE_TICK: float = 0.35
const KING_DASH_HIT_DAMAGE_MULT: float = 0.78
const KING_SLAM_DAMAGE_MULT: float = 0.95
const KING_RING_DAMAGE_MULT: float = 0.82
const KING_SLAM_RECOVER_LOCK: float = 0.7
const KING_PHASE1_BARRAGE_COOLDOWN_MIN: float = 8.5
const KING_PHASE1_BARRAGE_COOLDOWN_MAX: float = 13.0
const KING_PHASE1_BARRAGE_WARN_TIME: float = 1.05
const KING_PHASE1_SIGIL_RADIUS: float = 170.0
const KING_PHASE1_SIGIL_COUNT: int = 6
const KING_PHASE1_BARRAGE_DAMAGE_MULT: float = 1.05
const KING_SLAM_SHOCKWAVE_WARN: float = 0.55
const KING_SLAM_SHOCKWAVE_WIDTH: float = 110.0
const KING_SLAM_SHOCKWAVE_LENGTH: float = 1400.0
const KING_SLAM_SHOCKWAVE_DAMAGE_MULT: float = 0.72

enum KingAttackState {
	STATE_IDLE,
	STATE_DASH_WINDUP,
	STATE_DASHING,
	STATE_SLAM_WINDUP
}

var king_dash_segment_time: float = 0.0
var king_dash_burst_cd: float = 12.0
var king_dash_direction: Vector2 = Vector2.RIGHT
var king_dash_hit_cooldown: float = 0.0
var king_dash_targets: Array[Vector2] = []
var king_dash_target_index: int = 0
var king_dash_segment_pause: float = 0.0
var king_slam_cooldown: float = 2.4
var king_slam_windup_timer: float = 0.0
var king_zone_cast_cooldown: float = 8.0
var king_phase1_barrage_cooldown: float = 5.0
var king_cast_lock_timer: float = 0.0
var king_state: int = KingAttackState.STATE_IDLE
var king_phase_two_enabled: bool = false
var king_dash_indicator: Polygon2D = null
var king_dash_indicator_inner: Polygon2D = null
var king_dash_indicator_outline: Line2D = null
var king_slam_indicator: Polygon2D = null
var king_slam_indicator_inner: Polygon2D = null
var king_slam_indicator_outline: Line2D = null
var king_ring_indicator: Polygon2D = null
var king_ring_indicator_outline: Line2D = null
var king_dash_path_line: Line2D = null
var king_dash_path_points: Array[Polygon2D] = []
var king_dash_path_fill: Line2D = null
var king_dash_path_inner: Line2D = null
var king_dash_path_outline: Line2D = null
var king_zone_warning_nodes: Array[Polygon2D] = []
var king_active_zones: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	add_to_group("world_boss")
	current_health = int(round(float(current_health) * KING_HP_MULT))
	elite_max_health = current_health
	$AnimatedSprite2D.scale *= KING_EXTRA_VISUAL_SCALE
	base_sprite_scale = $AnimatedSprite2D.scale
	var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision != null:
		body_collision.scale *= KING_COLLIDER_SCALE
		body_collision.position.y += KING_COLLIDER_Y_OFFSET
	xp_reward = max(xp_reward + 22, 32)
	xp_tier = "rainbow"
	z_index = 8
	# Disable inherited leap loop so king remains a unique boss pattern.
	leap_is_winding_up = false
	leap_is_airborne = false
	leap_windup_timer = 0.0
	leap_air_timer = 0.0
	leap_landing_timer = 0.0
	leap_cooldown = 9999.0
	chase_timer_before_leap = 0.0
	_hide_leap_indicator()
	king_dash_burst_cd = randf_range(KING_DASH_COOLDOWN_MIN, KING_DASH_COOLDOWN_MAX)
	king_slam_cooldown = randf_range(KING_SLAM_COOLDOWN_MIN, KING_SLAM_COOLDOWN_MAX)
	king_zone_cast_cooldown = randf_range(KING_ZONE_CAST_COOLDOWN_MIN, KING_ZONE_CAST_COOLDOWN_MAX)
	king_phase1_barrage_cooldown = randf_range(KING_PHASE1_BARRAGE_COOLDOWN_MIN, KING_PHASE1_BARRAGE_COOLDOWN_MAX)


func get_enemy_archetype() -> String:
	return "king_goblin"


func _update_archetype_behavior(delta: float, direction: Vector2, distance: float) -> void:
	_update_phase_unlock()
	_update_zone_damage(delta)
	king_dash_hit_cooldown = max(king_dash_hit_cooldown - delta, 0.0)
	king_dash_burst_cd = max(king_dash_burst_cd - delta, 0.0)
	king_slam_cooldown = max(king_slam_cooldown - delta, 0.0)
	king_zone_cast_cooldown = max(king_zone_cast_cooldown - delta, 0.0)
	king_phase1_barrage_cooldown = max(king_phase1_barrage_cooldown - delta, 0.0)
	king_cast_lock_timer = max(king_cast_lock_timer - delta, 0.0)

	match king_state:
		KingAttackState.STATE_DASH_WINDUP:
			king_slam_windup_timer = max(king_slam_windup_timer - delta, 0.0)
			_update_dash_path_indicator_visual()
			_play_attack_animation(king_dash_direction)
			if king_slam_windup_timer <= 0.0:
				king_state = KingAttackState.STATE_DASHING
				king_dash_segment_time = KING_DASH_SEGMENT_TIME
			return
		KingAttackState.STATE_DASHING:
			if king_dash_target_index >= king_dash_targets.size():
				_hide_dash_indicator()
				_hide_dash_path_indicator()
				king_dash_targets.clear()
				king_state = KingAttackState.STATE_IDLE
				king_dash_burst_cd = randf_range(KING_DASH_COOLDOWN_MIN, KING_DASH_COOLDOWN_MAX)
				return
			king_dash_segment_pause = max(king_dash_segment_pause - delta, 0.0)
			if king_dash_segment_pause > 0.0:
				return
			var dash_target: Vector2 = king_dash_targets[king_dash_target_index]
			var to_target: Vector2 = dash_target - global_position
			var dist_to_target: float = to_target.length()
			king_dash_direction = to_target.normalized() if dist_to_target > 0.001 else king_dash_direction
			if king_dash_direction == Vector2.ZERO:
				king_dash_direction = Vector2.RIGHT
			_update_dash_indicator()
			king_dash_segment_time -= delta
			if king_dash_segment_time > 0.0 and dist_to_target > KING_DASH_TARGET_REACHED_DISTANCE:
				var step_dist: float = min(KING_DASH_SPEED * delta, dist_to_target)
				global_position = global_position.move_toward(dash_target, step_dist)
				_play_walk_animation(king_dash_direction)
				_try_dash_contact_hit()
				return
			king_dash_target_index += 1
			king_dash_segment_time = KING_DASH_SEGMENT_TIME
			king_dash_segment_pause = KING_DASH_SEGMENT_PAUSE
			return
		KingAttackState.STATE_SLAM_WINDUP:
			king_slam_windup_timer = max(king_slam_windup_timer - delta, 0.0)
			_update_slam_indicator()
			_play_attack_animation(direction if direction != Vector2.ZERO else king_dash_direction)
			if king_slam_windup_timer <= 0.0:
				_hide_slam_indicator()
				_apply_royal_slam()
				king_state = KingAttackState.STATE_IDLE
				king_slam_cooldown = randf_range(KING_SLAM_COOLDOWN_MIN, KING_SLAM_COOLDOWN_MAX)
			return
		_:
			pass

	if king_phase_two_enabled and king_zone_cast_cooldown <= 0.0:
		_cast_royal_zone_decree()
		king_zone_cast_cooldown = randf_range(KING_ZONE_CAST_COOLDOWN_MIN, KING_ZONE_CAST_COOLDOWN_MAX)
		return
	if king_phase1_barrage_cooldown <= 0.0:
		_cast_phase1_lane_barrage()
		king_phase1_barrage_cooldown = randf_range(KING_PHASE1_BARRAGE_COOLDOWN_MIN, KING_PHASE1_BARRAGE_COOLDOWN_MAX)
		return
	if king_cast_lock_timer > 0.0:
		return
	if king_slam_cooldown <= 0.0 and distance < 270.0:
		_begin_slam_windup()
		return
#	if king_dash_burst_cd <= 0.0 and distance > 110.0 and distance < 560.0:
#		_begin_dash_windup(direction)
#		return


func _apply_royal_slam() -> void:
	var impact_pos: Vector2 = global_position
	var core_r: float = KING_SLAM_AOE_RADIUS
	_spawn_hobgoblin_landing_smoke(impact_pos)
	_push_nearby_enemies(impact_pos, core_r + 28.0, 420.0, 42.0, 0.3)
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("add_screen_shake"):
			target_player.call("add_screen_shake", 16.0, 0.24)
		if target_player.has_method("receive_damage") and target_player.global_position.distance_to(impact_pos) <= core_r:
			var slam_damage: int = int(round(float(_get_contact_damage()) * KING_SLAM_DAMAGE_MULT))
			target_player.call("receive_damage", slam_damage)
			_spawn_bleed_burst_at(target_player.global_position)
		if target_player.global_position.distance_to(impact_pos) <= core_r and target_player.has_method("apply_launch_force"):
			target_player.call("apply_launch_force", impact_pos, 520.0, 42.0, 0.34)
	# Reworked follow-up: directional shockwaves instead of delayed ring.
	_cast_slam_shockwaves(impact_pos)
	king_cast_lock_timer = max(king_cast_lock_timer, KING_SLAM_SHOCKWAVE_WARN + KING_SLAM_RECOVER_LOCK)


func _king_crown_ring_damage(center: Vector2, outer_radius: float) -> void:
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	var d: float = target_player.global_position.distance_to(center)
	var inner_avoid: float = KING_SLAM_AOE_RADIUS * 0.82
	if d <= inner_avoid or d > outer_radius:
		return
	var dmg: int = int(round(float(_get_contact_damage()) * KING_RING_DAMAGE_MULT))
	target_player.call("receive_damage", dmg)
	_spawn_bleed_burst_at(target_player.global_position)
	if target_player.has_method("add_screen_shake"):
		target_player.call("add_screen_shake", 10.0, 0.16)


func _try_dash_contact_hit() -> void:
	if king_dash_hit_cooldown > 0.0:
		return
	if target_player == null or not is_instance_valid(target_player):
		return
	if not target_player.has_method("receive_damage"):
		return
	if target_player.global_position.distance_to(global_position) > CONTACT_RANGE * 1.25:
		return
	var dash_damage: int = int(round(float(_get_contact_damage()) * KING_DASH_HIT_DAMAGE_MULT))
	target_player.call("receive_damage", dash_damage)
	_spawn_bleed_burst_at(target_player.global_position)
	if target_player.has_method("apply_launch_force"):
		target_player.call("apply_launch_force", global_position, 280.0, 22.0, 0.16)
	king_dash_hit_cooldown = 0.62


func _should_hold_position() -> bool:
	return king_state == KingAttackState.STATE_DASH_WINDUP or king_state == KingAttackState.STATE_SLAM_WINDUP


func _disable_contact_damage() -> bool:
	return king_state == KingAttackState.STATE_DASH_WINDUP or king_state == KingAttackState.STATE_SLAM_WINDUP


func _begin_dash_windup(direction: Vector2) -> void:
	king_state = KingAttackState.STATE_DASH_WINDUP
	king_slam_windup_timer = KING_DASH_WINDUP
	king_dash_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	_build_locked_dash_targets()
	_show_dash_path_indicator()


func _begin_slam_windup() -> void:
	king_state = KingAttackState.STATE_SLAM_WINDUP
	king_slam_windup_timer = KING_SLAM_WINDUP
	_show_slam_indicator()


func _update_phase_unlock() -> void:
	if king_phase_two_enabled:
		return
	var hp_ratio: float = float(current_health) / max(float(elite_max_health), 1.0)
	if hp_ratio <= 0.6:
		king_phase_two_enabled = true


func _show_dash_indicator() -> void:
	if king_dash_indicator == null:
		king_dash_indicator = Polygon2D.new()
		king_dash_indicator.z_index = -2
		king_dash_indicator.color = Color(0.58, 0.04, 0.04, 0.16)
		add_child(king_dash_indicator)
	if king_dash_indicator_inner == null:
		king_dash_indicator_inner = Polygon2D.new()
		king_dash_indicator_inner.z_index = -2
		king_dash_indicator_inner.color = Color(0.74, 0.13, 0.13, 0.12)
		add_child(king_dash_indicator_inner)
	if king_dash_indicator_outline == null:
		king_dash_indicator_outline = Line2D.new()
		king_dash_indicator_outline.width = 1.3
		king_dash_indicator_outline.closed = true
		king_dash_indicator_outline.default_color = Color(0.58, 0.04, 0.04, 0.78)
		king_dash_indicator_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		king_dash_indicator_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		king_dash_indicator_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		king_dash_indicator_outline.z_index = 0
		add_child(king_dash_indicator_outline)
	_update_dash_indicator()
	king_dash_indicator.visible = true
	king_dash_indicator_inner.visible = true
	king_dash_indicator_outline.visible = true


func _update_dash_indicator() -> void:
	if king_dash_indicator == null:
		return
	var dir: Vector2 = king_dash_direction.normalized()
	if king_dash_target_index < king_dash_targets.size():
		dir = (king_dash_targets[king_dash_target_index] - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var right: Vector2 = dir.orthogonal()
	var half_w: float = KING_DASH_INDICATOR_WIDTH * 0.5
	var p1: Vector2 = right * -half_w
	var p2: Vector2 = right * half_w
	var p3: Vector2 = (dir * KING_DASH_INDICATOR_LENGTH) + (right * (half_w * 0.54))
	var p4: Vector2 = (dir * KING_DASH_INDICATOR_LENGTH) + (right * (-half_w * 0.54))
	var outer_poly: PackedVector2Array = PackedVector2Array([p1, p2, p3, p4])
	var inner_half: float = half_w * 0.58
	var ip1: Vector2 = (dir * 16.0) + (right * -inner_half)
	var ip2: Vector2 = (dir * 16.0) + (right * inner_half)
	var ip3: Vector2 = (dir * (KING_DASH_INDICATOR_LENGTH - 12.0)) + (right * (inner_half * 0.55))
	var ip4: Vector2 = (dir * (KING_DASH_INDICATOR_LENGTH - 12.0)) + (right * (-inner_half * 0.55))
	king_dash_indicator.polygon = outer_poly
	if king_dash_indicator_inner != null:
		king_dash_indicator_inner.polygon = PackedVector2Array([ip1, ip2, ip3, ip4])
	if king_dash_indicator_outline != null:
		king_dash_indicator_outline.points = outer_poly
	var progress: float = clamp(1.0 - (king_slam_windup_timer / max(KING_DASH_WINDUP, 0.001)), 0.0, 1.0)
	var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.012))
	var alpha: float = lerp(0.16, 0.42, clamp(progress * 0.7 + pulse * 0.3, 0.0, 1.0))
	king_dash_indicator.modulate.a = alpha
	if king_dash_indicator_inner != null:
		king_dash_indicator_inner.modulate.a = alpha * 0.82
	if king_dash_indicator_outline != null:
		king_dash_indicator_outline.default_color = Color(0.58, 0.04, 0.04, clamp(alpha + 0.2, 0.2, 0.86))


func _hide_dash_indicator() -> void:
	if king_dash_indicator != null:
		king_dash_indicator.visible = false
	if king_dash_indicator_inner != null:
		king_dash_indicator_inner.visible = false
	if king_dash_indicator_outline != null:
		king_dash_indicator_outline.visible = false


func _show_slam_indicator() -> void:
	if king_slam_indicator == null:
		king_slam_indicator = Polygon2D.new()
		king_slam_indicator.z_index = -2
		king_slam_indicator.color = Color(0.58, 0.04, 0.04, 0.16)
		king_slam_indicator.polygon = _build_circle_polygon(KING_SLAM_AOE_RADIUS, 36)
		add_child(king_slam_indicator)
	if king_slam_indicator_inner == null:
		king_slam_indicator_inner = Polygon2D.new()
		king_slam_indicator_inner.z_index = -2
		king_slam_indicator_inner.color = Color(0.74, 0.13, 0.13, 0.12)
		king_slam_indicator_inner.polygon = _build_circle_polygon(KING_SLAM_AOE_RADIUS * 0.6, 30)
		add_child(king_slam_indicator_inner)
	if king_slam_indicator_outline == null:
		king_slam_indicator_outline = Line2D.new()
		king_slam_indicator_outline.width = 1.3
		king_slam_indicator_outline.closed = true
		king_slam_indicator_outline.default_color = Color(0.58, 0.04, 0.04, 0.78)
		king_slam_indicator_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		king_slam_indicator_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		king_slam_indicator_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		king_slam_indicator_outline.z_index = 0
		king_slam_indicator_outline.points = king_slam_indicator.polygon
		add_child(king_slam_indicator_outline)
	king_slam_indicator.visible = true
	king_slam_indicator_inner.visible = true
	king_slam_indicator_outline.visible = true
	_update_slam_indicator()


func _update_slam_indicator() -> void:
	if king_slam_indicator == null:
		return
	king_slam_indicator.position = Vector2.ZERO
	var progress: float = clamp(1.0 - (king_slam_windup_timer / max(KING_SLAM_WINDUP, 0.001)), 0.0, 1.0)
	var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.01))
	var alpha: float = lerp(0.18, 0.44, clamp(progress * 0.65 + pulse * 0.35, 0.0, 1.0))
	king_slam_indicator.modulate.a = alpha
	if king_slam_indicator_inner != null:
		king_slam_indicator_inner.modulate.a = alpha * 0.82
	if king_slam_indicator_outline != null:
		king_slam_indicator_outline.default_color = Color(0.58, 0.04, 0.04, clamp(alpha + 0.2, 0.2, 0.86))


func _hide_slam_indicator() -> void:
	if king_slam_indicator != null:
		king_slam_indicator.visible = false
	if king_slam_indicator_inner != null:
		king_slam_indicator_inner.visible = false
	if king_slam_indicator_outline != null:
		king_slam_indicator_outline.visible = false


func _show_ring_indicator(inner_r: float, outer_r: float) -> void:
	if king_ring_indicator == null:
		king_ring_indicator = Polygon2D.new()
		king_ring_indicator.z_index = -2
		king_ring_indicator.color = Color(0.58, 0.04, 0.04, 0.2)
		add_child(king_ring_indicator)
	if king_ring_indicator_outline == null:
		king_ring_indicator_outline = Line2D.new()
		king_ring_indicator_outline.width = 1.3
		king_ring_indicator_outline.closed = true
		king_ring_indicator_outline.default_color = Color(0.58, 0.04, 0.04, 0.82)
		king_ring_indicator_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		king_ring_indicator_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		king_ring_indicator_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		king_ring_indicator_outline.z_index = 0
		add_child(king_ring_indicator_outline)
	var ring_points: PackedVector2Array = PackedVector2Array()
	var outer: PackedVector2Array = _build_circle_polygon(outer_r, 42)
	var inner: PackedVector2Array = _build_circle_polygon(inner_r, 42)
	for p in outer:
		ring_points.append(p)
	for i in range(inner.size() - 1, -1, -1):
		ring_points.append(inner[i])
	king_ring_indicator.polygon = ring_points
	king_ring_indicator.position = Vector2.ZERO
	king_ring_indicator.visible = true
	king_ring_indicator_outline.points = outer
	king_ring_indicator_outline.visible = true


func _hide_ring_indicator() -> void:
	if king_ring_indicator != null:
		king_ring_indicator.visible = false
	if king_ring_indicator_outline != null:
		king_ring_indicator_outline.visible = false


func _build_locked_dash_targets() -> void:
	king_dash_targets.clear()
	king_dash_target_index = 0
	var player_pos: Vector2 = target_player.global_position if target_player != null else global_position + (king_dash_direction * 120.0)
	if target_player is CharacterBody2D:
		player_pos += (target_player as CharacterBody2D).velocity * KING_DASH_PREDICT_SECONDS
	var forward: Vector2 = (player_pos - global_position).normalized()
	if forward == Vector2.ZERO:
		forward = king_dash_direction if king_dash_direction != Vector2.ZERO else Vector2.RIGHT
	var side: Vector2 = forward.orthogonal()
	var last_lateral: float = 0.0
	for i in range(KING_DASH_TARGET_COUNT):
		var lateral: float = randf_range(-KING_DASH_TARGET_SPREAD, KING_DASH_TARGET_SPREAD)
		if i > 0 and abs(lateral - last_lateral) < 48.0:
			lateral += 64.0 if lateral < 0.0 else -64.0
		last_lateral = lateral
		var forward_step: float = KING_DASH_TARGET_OVERSHOOT + (float(i) * randf_range(30.0, 52.0))
		var target: Vector2 = player_pos + (forward * forward_step) + (side * lateral)
		king_dash_targets.append(target)


func _show_dash_path_indicator() -> void:
	_hide_dash_path_indicator()
	if get_parent() == null:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(global_position)
	for target in king_dash_targets:
		pts.append(target)
	king_dash_path_fill = Line2D.new()
	king_dash_path_fill.width = KING_DASH_INDICATOR_WIDTH
	king_dash_path_fill.default_color = Color(0.58, 0.04, 0.04, 0.16)
	king_dash_path_fill.joint_mode = Line2D.LINE_JOINT_ROUND
	king_dash_path_fill.begin_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_fill.end_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_fill.points = pts
	king_dash_path_fill.z_index = -2
	get_parent().add_child(king_dash_path_fill)
	king_dash_path_inner = Line2D.new()
	king_dash_path_inner.width = KING_DASH_INDICATOR_WIDTH * 0.58
	king_dash_path_inner.default_color = Color(0.9, 0.16, 0.16, 0.18)
	king_dash_path_inner.joint_mode = Line2D.LINE_JOINT_ROUND
	king_dash_path_inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_inner.end_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_inner.points = pts
	king_dash_path_inner.z_index = -1
	get_parent().add_child(king_dash_path_inner)
	king_dash_path_outline = Line2D.new()
	king_dash_path_outline.width = 2.0
	king_dash_path_outline.default_color = Color(0.22, 0.0, 0.0, 0.92)
	king_dash_path_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	king_dash_path_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	king_dash_path_outline.points = pts
	king_dash_path_outline.z_index = 0
	get_parent().add_child(king_dash_path_outline)
	# Patch corner holes by stamping circles at each turn point.
	for i in range(1, pts.size() - 1):
		var corner_world: Vector2 = pts[i]
		var outer_dot: Polygon2D = Polygon2D.new()
		outer_dot.polygon = _build_circle_polygon(KING_DASH_INDICATOR_WIDTH * 0.52, 20)
		outer_dot.color = Color(0.58, 0.04, 0.04, 0.16)
		outer_dot.global_position = corner_world
		outer_dot.z_index = -2
		get_parent().add_child(outer_dot)
		king_dash_path_points.append(outer_dot)
		var inner_dot: Polygon2D = Polygon2D.new()
		inner_dot.polygon = _build_circle_polygon((KING_DASH_INDICATOR_WIDTH * 0.58) * 0.5, 16)
		inner_dot.color = Color(0.9, 0.16, 0.16, 0.18)
		inner_dot.global_position = corner_world
		inner_dot.z_index = -1
		get_parent().add_child(inner_dot)
		king_dash_path_points.append(inner_dot)


func _hide_dash_path_indicator() -> void:
	if king_dash_path_line != null and is_instance_valid(king_dash_path_line):
		king_dash_path_line.queue_free()
	king_dash_path_line = null
	for marker in king_dash_path_points:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	king_dash_path_points.clear()
	if king_dash_path_fill != null and is_instance_valid(king_dash_path_fill):
		king_dash_path_fill.queue_free()
	king_dash_path_fill = null
	if king_dash_path_inner != null and is_instance_valid(king_dash_path_inner):
		king_dash_path_inner.queue_free()
	king_dash_path_inner = null
	if king_dash_path_outline != null and is_instance_valid(king_dash_path_outline):
		king_dash_path_outline.queue_free()
	king_dash_path_outline = null


func _update_dash_path_indicator_visual() -> void:
	if king_dash_path_fill == null:
		return
	var progress: float = clamp(1.0 - (king_slam_windup_timer / max(KING_DASH_WINDUP, 0.001)), 0.0, 1.0)
	var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.01))
	var alpha: float = lerp(0.14, 0.42, clamp(progress * 0.72 + pulse * 0.28, 0.0, 1.0))
	king_dash_path_fill.modulate.a = alpha
	if king_dash_path_inner != null:
		king_dash_path_inner.modulate.a = alpha * 0.92
	if king_dash_path_outline != null:
		king_dash_path_outline.default_color = Color(0.22, 0.0, 0.0, clamp(alpha + 0.28, 0.3, 0.96))


func _spawn_world_lane_indicator(start_world: Vector2, end_world: Vector2, lane_width: float) -> Dictionary:
	var parent_node: Node = get_parent() if get_parent() != null else self
	var dir: Vector2 = (end_world - start_world).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var lane_len: float = max(start_world.distance_to(end_world), 26.0)
	var right: Vector2 = dir.orthogonal()
	var half: float = lane_width * 0.5
	var p1: Vector2 = right * -half
	var p2: Vector2 = right * half
	var p3: Vector2 = (dir * lane_len) + (right * (half * 0.68))
	var p4: Vector2 = (dir * lane_len) + (right * (-half * 0.68))
	var outer_poly: PackedVector2Array = PackedVector2Array([p1, p2, p3, p4])
	var inner_half: float = half * 0.58
	var ip1: Vector2 = (dir * 14.0) + (right * -inner_half)
	var ip2: Vector2 = (dir * 14.0) + (right * inner_half)
	var ip3: Vector2 = (dir * (lane_len - 8.0)) + (right * (inner_half * 0.68))
	var ip4: Vector2 = (dir * (lane_len - 8.0)) + (right * (-inner_half * 0.68))
	var inner_poly: PackedVector2Array = PackedVector2Array([ip1, ip2, ip3, ip4])
	var fill: Polygon2D = Polygon2D.new()
	fill.z_index = -2
	fill.color = Color(0.72, 0.04, 0.04, 0.3)
	fill.polygon = outer_poly
	fill.global_position = start_world
	parent_node.add_child(fill)
	var inner: Polygon2D = Polygon2D.new()
	inner.z_index = -2
	inner.color = Color(1.0, 0.12, 0.12, 0.46)
	inner.polygon = inner_poly
	inner.global_position = start_world
	parent_node.add_child(inner)
	var outline: Line2D = Line2D.new()
	outline.width = 1.3
	outline.closed = true
	outline.default_color = Color(0.22, 0.0, 0.0, 0.96)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.z_index = 0
	outline.points = outer_poly
	outline.global_position = start_world
	parent_node.add_child(outline)
	return {"fill": fill, "inner": inner, "outline": outline}


func _cast_royal_zone_decree() -> void:
	_clear_zone_warning_nodes()
	var to_player: Vector2 = (target_player.global_position - global_position).normalized() if target_player != null else Vector2.RIGHT
	if to_player == Vector2.ZERO:
		to_player = Vector2.RIGHT
	var side: Vector2 = to_player.orthogonal()
	var center_a: Vector2 = global_position + (side * KING_ZONE_CENTER_OFFSET)
	var center_b: Vector2 = global_position - (side * KING_ZONE_CENTER_OFFSET)
	_show_zone_warning(center_a)
	_show_zone_warning(center_b)
	get_tree().create_timer(KING_ZONE_WARNING_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_activate_zone(center_a)
		_activate_zone(center_b)
	)


func _show_zone_warning(world_center: Vector2) -> void:
	var zone: Polygon2D = Polygon2D.new()
	zone.polygon = _build_circle_polygon(KING_ZONE_RADIUS, 46)
	zone.color = Color(0.58, 0.04, 0.04, 0.16)
	zone.global_position = world_center
	zone.z_index = -2
	(get_parent() if get_parent() != null else self).add_child(zone)
	king_zone_warning_nodes.append(zone)
	var tw: Tween = create_tween()
	tw.tween_property(zone, "modulate:a", 0.34, KING_ZONE_WARNING_TIME * 0.5)
	tw.tween_property(zone, "modulate:a", 0.2, KING_ZONE_WARNING_TIME * 0.5)


func _activate_zone(world_center: Vector2) -> void:
	for warning in king_zone_warning_nodes:
		if is_instance_valid(warning):
			warning.queue_free()
	king_zone_warning_nodes.clear()
	var zone: Polygon2D = Polygon2D.new()
	zone.polygon = _build_circle_polygon(KING_ZONE_RADIUS, 46)
	zone.color = Color(0.74, 0.13, 0.13, 0.3)
	zone.global_position = world_center
	zone.z_index = -2
	(get_parent() if get_parent() != null else self).add_child(zone)
	king_active_zones.append({
		"center": world_center,
		"radius": KING_ZONE_RADIUS,
		"time_left": KING_ZONE_ACTIVE_TIME,
		"tick_left": 0.0,
		"node": zone
	})


func _update_zone_damage(delta: float) -> void:
	if king_active_zones.is_empty():
		return
	for i in range(king_active_zones.size() - 1, -1, -1):
		var z: Dictionary = king_active_zones[i]
		z["time_left"] = float(z.get("time_left", 0.0)) - delta
		z["tick_left"] = float(z.get("tick_left", 0.0)) - delta
		if float(z.get("tick_left", 0.0)) <= 0.0:
			_try_zone_damage_player(z)
			z["tick_left"] = KING_ZONE_DAMAGE_TICK
		king_active_zones[i] = z
		if float(z.get("time_left", 0.0)) <= 0.0:
			var node: Polygon2D = z.get("node", null) as Polygon2D
			if node != null and is_instance_valid(node):
				node.queue_free()
			king_active_zones.remove_at(i)


func _try_zone_damage_player(zone_data: Dictionary) -> void:
	if target_player == null or not is_instance_valid(target_player):
		return
	if not target_player.has_method("receive_damage"):
		return
	var center: Vector2 = zone_data.get("center", global_position)
	var radius: float = float(zone_data.get("radius", KING_ZONE_RADIUS))
	if target_player.global_position.distance_to(center) > radius:
		return
	var dmg: int = int(round(float(_get_contact_damage()) * KING_ZONE_DAMAGE_MULT))
	target_player.call("receive_damage", dmg)
	_spawn_bleed_burst_at(target_player.global_position)


func _cast_phase1_lane_barrage() -> void:
	if target_player == null or not is_instance_valid(target_player) or get_parent() == null:
		return
	var hazards: Array[Dictionary] = []
	for i in range(KING_PHASE1_SIGIL_COUNT):
		var ring_t: float = float(i) / float(max(KING_PHASE1_SIGIL_COUNT, 1))
		var ang: float = (ring_t * TAU) + randf_range(-0.25, 0.25)
		var dist: float = randf_range(150.0, 520.0)
		var center: Vector2 = target_player.global_position + (Vector2.RIGHT.rotated(ang) * dist)
		var sigil_nodes: Dictionary = _spawn_world_circle_indicator(center, KING_PHASE1_SIGIL_RADIUS)
		hazards.append({"center": center, "radius": KING_PHASE1_SIGIL_RADIUS, "nodes": sigil_nodes})
	king_cast_lock_timer = KING_PHASE1_BARRAGE_WARN_TIME + 0.4
	var t: Tween = create_tween()
	for hazard in hazards:
		var nodes: Dictionary = hazard.get("nodes", {})
		var fill: Polygon2D = nodes.get("fill", null) as Polygon2D
		var inner: Polygon2D = nodes.get("inner", null) as Polygon2D
		var outline: Line2D = nodes.get("outline", null) as Line2D
		if fill != null:
			fill.modulate.a = 0.26
			t.parallel().tween_property(fill, "modulate:a", 0.56, KING_PHASE1_BARRAGE_WARN_TIME)
		if inner != null:
			inner.modulate.a = 0.28
			inner.color = Color(1.0, 0.14, 0.14, 0.4)
			t.parallel().tween_property(inner, "modulate:a", 0.72, KING_PHASE1_BARRAGE_WARN_TIME)
		if outline != null:
			outline.default_color = Color(0.22, 0.0, 0.0, 0.95)
	get_tree().create_timer(KING_PHASE1_BARRAGE_WARN_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_apply_phase1_lane_barrage_damage(hazards)
		_cleanup_lane_entries(hazards)
	)


func _apply_phase1_lane_barrage_damage(lanes: Array[Dictionary]) -> void:
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	var ppos: Vector2 = target_player.global_position
	for lane_entry in lanes:
		var center: Vector2 = lane_entry.get("center", ppos)
		var radius: float = float(lane_entry.get("radius", KING_PHASE1_SIGIL_RADIUS))
		if ppos.distance_to(center) <= radius:
			var dmg: int = int(round(float(_get_contact_damage()) * KING_PHASE1_BARRAGE_DAMAGE_MULT))
			target_player.call("receive_damage", dmg)
			_spawn_bleed_burst_at(target_player.global_position)
			if target_player.has_method("add_screen_shake"):
				target_player.call("add_screen_shake", 11.0, 0.14)
			return


func _cleanup_lane_entries(lanes: Array[Dictionary]) -> void:
	for lane_entry in lanes:
		var nodes: Dictionary = lane_entry.get("nodes", {})
		var fill: Polygon2D = nodes.get("fill", null) as Polygon2D
		var inner: Polygon2D = nodes.get("inner", null) as Polygon2D
		var outline: Line2D = nodes.get("outline", null) as Line2D
		if fill != null and is_instance_valid(fill):
			fill.queue_free()
		if inner != null and is_instance_valid(inner):
			inner.queue_free()
		if outline != null and is_instance_valid(outline):
			outline.queue_free()


func _cast_slam_shockwaves(center: Vector2) -> void:
	var base_dir: Vector2 = (target_player.global_position - center).normalized() if target_player != null else Vector2.RIGHT
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var dirs: Array[Vector2] = [
		base_dir,
		base_dir.rotated(PI * 0.5),
		base_dir.rotated(PI),
		base_dir.rotated(-PI * 0.5)
	]
	var lanes: Array[Dictionary] = []
	for d in dirs:
		var start: Vector2 = center
		var end: Vector2 = center + (d * KING_SLAM_SHOCKWAVE_LENGTH)
		var lane_nodes: Dictionary = _spawn_world_lane_indicator(start, end, KING_SLAM_SHOCKWAVE_WIDTH)
		lanes.append({"start": start, "end": end, "width": KING_SLAM_SHOCKWAVE_WIDTH, "nodes": lane_nodes})
	get_tree().create_timer(KING_SLAM_SHOCKWAVE_WARN).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_apply_slam_shockwave_damage(lanes)
		_cleanup_lane_entries(lanes)
	)


func _apply_slam_shockwave_damage(lanes: Array[Dictionary]) -> void:
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	var ppos: Vector2 = target_player.global_position
	for lane_entry in lanes:
		var start: Vector2 = lane_entry.get("start", ppos)
		var end: Vector2 = lane_entry.get("end", ppos)
		var width: float = float(lane_entry.get("width", KING_SLAM_SHOCKWAVE_WIDTH))
		var dist: float = Geometry2D.get_closest_point_to_segment(ppos, start, end).distance_to(ppos)
		if dist <= (width * 0.5):
			var dmg: int = int(round(float(_get_contact_damage()) * KING_SLAM_SHOCKWAVE_DAMAGE_MULT))
			target_player.call("receive_damage", dmg)
			_spawn_bleed_burst_at(target_player.global_position)
			return


func _spawn_world_circle_indicator(center_world: Vector2, radius: float) -> Dictionary:
	var parent_node: Node = get_parent() if get_parent() != null else self
	var fill: Polygon2D = Polygon2D.new()
	fill.z_index = -2
	fill.color = Color(0.72, 0.04, 0.04, 0.3)
	fill.polygon = _build_circle_polygon(radius, 44)
	fill.global_position = center_world
	parent_node.add_child(fill)
	var inner: Polygon2D = Polygon2D.new()
	inner.z_index = -2
	inner.color = Color(1.0, 0.12, 0.12, 0.44)
	inner.polygon = _build_circle_polygon(radius * 0.58, 36)
	inner.global_position = center_world
	parent_node.add_child(inner)
	var outline: Line2D = Line2D.new()
	outline.width = 1.3
	outline.closed = true
	outline.default_color = Color(0.22, 0.0, 0.0, 0.96)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.points = _build_circle_polygon(radius, 44)
	outline.z_index = 0
	outline.global_position = center_world
	parent_node.add_child(outline)
	return {"fill": fill, "inner": inner, "outline": outline}


func _spawn_bleed_burst_at(world_pos: Vector2) -> void:
	if get_parent() == null:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 18
	burst.lifetime = 0.34
	burst.explosiveness = 0.92
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 160)
	burst.initial_velocity_min = 46.0
	burst.initial_velocity_max = 96.0
	burst.scale_amount_min = 0.22
	burst.scale_amount_max = 0.46
	burst.color = Color(0.82, 0.08, 0.08, 0.92)
	burst.global_position = world_pos + Vector2(0.0, -8.0)
	burst.z_index = 10
	get_parent().add_child(burst)
	burst.emitting = true
	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(0.5)
	cleanup_tween.tween_callback(burst.queue_free)


func _clear_zone_warning_nodes() -> void:
	for n in king_zone_warning_nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	king_zone_warning_nodes.clear()


func _exit_tree() -> void:
	_clear_zone_warning_nodes()
	_hide_dash_path_indicator()
	for z in king_active_zones:
		var node: Polygon2D = z.get("node", null) as Polygon2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	king_active_zones.clear()
	if king_dash_indicator != null:
		king_dash_indicator.queue_free()
		king_dash_indicator = null
	if king_dash_indicator_inner != null:
		king_dash_indicator_inner.queue_free()
		king_dash_indicator_inner = null
	if king_dash_indicator_outline != null:
		king_dash_indicator_outline.queue_free()
		king_dash_indicator_outline = null
	if king_slam_indicator != null:
		king_slam_indicator.queue_free()
		king_slam_indicator = null
	if king_slam_indicator_inner != null:
		king_slam_indicator_inner.queue_free()
		king_slam_indicator_inner = null
	if king_slam_indicator_outline != null:
		king_slam_indicator_outline.queue_free()
		king_slam_indicator_outline = null
	if king_ring_indicator != null:
		king_ring_indicator.queue_free()
		king_ring_indicator = null
	if king_ring_indicator_outline != null:
		king_ring_indicator_outline.queue_free()
		king_ring_indicator_outline = null
	super._exit_tree()


func _update_ground_shadow() -> void:
	super._update_ground_shadow()
	if ground_shadow == null:
		return
	# King needs a much larger, lower shadow because the sprite reads very tall.
	ground_shadow.position.y += 76.0
	ground_shadow.scale *= Vector2(1.95, 1.32)
	ground_shadow.modulate.a = clamp(ground_shadow.modulate.a + 0.12, 0.2, 0.9)
