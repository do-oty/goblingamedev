extends "res://scripts/enemy.gd"

const HOBGOBLIN_HP_MULT: float = 2.8
const HOBGOBLIN_SPEED_MULT: float = 0.68
const HOBGOBLIN_DAMAGE_MULT: float = 1.35
const HOBGOBLIN_VISUAL_SCALE: float = 2.08
const HOBGOBLIN_LEAP_COOLDOWN_MIN: float = 3.6
const HOBGOBLIN_LEAP_COOLDOWN_MAX: float = 5.4
const HOBGOBLIN_LEAP_WINDUP: float = 1.15
const HOBGOBLIN_LEAP_AIR_TIME: float = 0.42
const HOBGOBLIN_LEAP_MAX_RANGE: float = 220.0
const HOBGOBLIN_LEAP_AOE_RADIUS: float = 90.0
const HOBGOBLIN_LEAP_DAMAGE_MULT: float = 1.65
const HOBGOBLIN_INDICATOR_ALPHA_MIN: float = 0.08
const HOBGOBLIN_INDICATOR_ALPHA_MAX: float = 0.24
const HOBGOBLIN_LEAP_HEIGHT_PIXELS: float = 70.0
const HOBGOBLIN_LANDING_ANIM_TIME: float = 0.18
const HOBGOBLIN_CHASE_TIME_BEFORE_LEAP: float = 1.6
const HOBGOBLIN_POST_LEAP_LOCKOUT: float = 2.3
const HOBGOBLIN_LEAP_OVERSHOOT: float = 20.0

## Set > 0 on subclasses (e.g. king) to enlarge telegraphs / impacts without duplicating logic.
var hobgoblin_leap_aoe_radius_override: float = -1.0
var hobgoblin_leap_max_range_override: float = -1.0
var hobgoblin_leap_damage_mult_override: float = -1.0

var leap_cooldown: float = 0.0
var leap_windup_timer: float = 0.0
var leap_air_timer: float = 0.0
var leap_is_winding_up: bool = false
var leap_is_airborne: bool = false
var leap_target_position: Vector2 = Vector2.ZERO
var leap_start_position: Vector2 = Vector2.ZERO
var leap_indicator: Polygon2D = null
var leap_indicator_inner: Polygon2D = null
var leap_outline_red: Line2D = null
var leap_landing_timer: float = 0.0
var leap_direction: Vector2 = Vector2.RIGHT
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var chase_timer_before_leap: float = 0.0
var post_leap_lockout_timer: float = 0.0
@export var hobgoblin_landing_smoke_vfx_scene: PackedScene


func _hob_leap_aoe_radius() -> float:
	return hobgoblin_leap_aoe_radius_override if hobgoblin_leap_aoe_radius_override > 0.0 else HOBGOBLIN_LEAP_AOE_RADIUS


func _hob_leap_max_range() -> float:
	return hobgoblin_leap_max_range_override if hobgoblin_leap_max_range_override > 0.0 else HOBGOBLIN_LEAP_MAX_RANGE


func _hob_leap_damage_mult() -> float:
	return hobgoblin_leap_damage_mult_override if hobgoblin_leap_damage_mult_override > 0.0 else HOBGOBLIN_LEAP_DAMAGE_MULT


func _ready() -> void:
	super._ready()
	current_health = int(round(float(current_health) * HOBGOBLIN_HP_MULT))
	elite_max_health = current_health
	elite_speed_multiplier *= HOBGOBLIN_SPEED_MULT
	elite_damage_multiplier *= HOBGOBLIN_DAMAGE_MULT
	xp_reward = max(xp_reward + 3, 4)
	xp_tier = "green"
	$AnimatedSprite2D.scale *= HOBGOBLIN_VISUAL_SCALE
	base_sprite_position = $AnimatedSprite2D.position
	base_sprite_scale = $AnimatedSprite2D.scale
	$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
	leap_cooldown = randf_range(2.0, 2.8)


func configure_as_elite(progress_ratio: float = 0.0, forced_type: String = "") -> void:
	super.configure_as_elite(progress_ratio, forced_type)
	# Neutral tint so tank aura/sheen read clearly on the large silhouette.
	$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)


func get_enemy_archetype() -> String:
	return "hobgoblin"


func _update_archetype_behavior(delta: float, direction: Vector2, distance: float) -> void:
	leap_cooldown = max(leap_cooldown - delta, 0.0)
	post_leap_lockout_timer = max(post_leap_lockout_timer - delta, 0.0)
	_update_hobgoblin_ground_shadow_motion()
	if not (leap_is_winding_up or leap_is_airborne or leap_landing_timer > 0.0):
		# Force some chase time before each leap to create punish windows.
		if distance > CONTACT_RANGE * 1.2 and distance < 560.0:
			chase_timer_before_leap = min(chase_timer_before_leap + delta, HOBGOBLIN_CHASE_TIME_BEFORE_LEAP + 0.5)
		else:
			chase_timer_before_leap = 0.0
	if leap_landing_timer > 0.0:
		leap_landing_timer = max(leap_landing_timer - delta, 0.0)
		var landing_progress: float = 1.0 - (leap_landing_timer / max(HOBGOBLIN_LANDING_ANIM_TIME, 0.001))
		var full_progress: float = (HOBGOBLIN_LEAP_WINDUP + HOBGOBLIN_LEAP_AIR_TIME + (landing_progress * HOBGOBLIN_LANDING_ANIM_TIME)) / (HOBGOBLIN_LEAP_WINDUP + HOBGOBLIN_LEAP_AIR_TIME + HOBGOBLIN_LANDING_ANIM_TIME)
		_set_leap_anim_progress(full_progress)
		_update_leap_shadow(0.0)
		if leap_landing_timer <= 0.0:
			_reset_sprite_after_leap()
		return
	if leap_is_winding_up:
		leap_windup_timer = max(leap_windup_timer - delta, 0.0)
		var windup_progress: float = 1.0 - (leap_windup_timer / max(HOBGOBLIN_LEAP_WINDUP, 0.001))
		var full_progress_windup: float = (windup_progress * HOBGOBLIN_LEAP_WINDUP) / (HOBGOBLIN_LEAP_WINDUP + HOBGOBLIN_LEAP_AIR_TIME + HOBGOBLIN_LANDING_ANIM_TIME)
		_set_leap_anim_progress(full_progress_windup)
		_update_leap_indicator_visual()
		_update_leap_shadow(0.0)
		if leap_windup_timer <= 0.0:
			leap_is_winding_up = false
			leap_is_airborne = true
			leap_air_timer = HOBGOBLIN_LEAP_AIR_TIME
			$AnimatedSprite2D.modulate.a = 0.95
			# Remove warning marker once actual leap starts.
			_hide_leap_indicator()
		return
	if leap_is_airborne:
		leap_air_timer = max(leap_air_timer - delta, 0.0)
		var air_progress: float = 1.0 - (leap_air_timer / max(HOBGOBLIN_LEAP_AIR_TIME, 0.001))
		global_position = leap_start_position.lerp(leap_target_position, air_progress)
		var arc: float = sin(air_progress * PI)
		$AnimatedSprite2D.position = base_sprite_position + Vector2(0.0, -HOBGOBLIN_LEAP_HEIGHT_PIXELS * arc)
		$AnimatedSprite2D.scale = base_sprite_scale
		var full_progress_air: float = (HOBGOBLIN_LEAP_WINDUP + (air_progress * HOBGOBLIN_LEAP_AIR_TIME)) / (HOBGOBLIN_LEAP_WINDUP + HOBGOBLIN_LEAP_AIR_TIME + HOBGOBLIN_LANDING_ANIM_TIME)
		_set_leap_anim_progress(full_progress_air)
		_update_leap_shadow(arc)
		_hide_leap_indicator()
		if leap_air_timer <= 0.0:
			leap_is_airborne = false
			global_position = leap_target_position
			_reset_sprite_after_leap()
			leap_landing_timer = HOBGOBLIN_LANDING_ANIM_TIME
			post_leap_lockout_timer = HOBGOBLIN_POST_LEAP_LOCKOUT
			_apply_leap_impact_damage()
		return
	if leap_cooldown <= 0.0 and post_leap_lockout_timer <= 0.0 and chase_timer_before_leap >= HOBGOBLIN_CHASE_TIME_BEFORE_LEAP and distance > CONTACT_RANGE * 1.55 and distance < 520.0:
		var leap_dir: Vector2 = direction if direction != Vector2.ZERO else Vector2.RIGHT
		leap_direction = leap_dir
		leap_start_position = global_position
		var leap_distance: float = min(distance + HOBGOBLIN_LEAP_OVERSHOOT, _hob_leap_max_range())
		leap_target_position = global_position + (leap_dir * leap_distance)
		leap_is_winding_up = true
		leap_windup_timer = HOBGOBLIN_LEAP_WINDUP
		leap_cooldown = randf_range(HOBGOBLIN_LEAP_COOLDOWN_MIN, HOBGOBLIN_LEAP_COOLDOWN_MAX)
		_show_leap_indicator()
		$AnimatedSprite2D.modulate = Color(1.1, 0.9, 0.9, 1.0)
		_set_leap_anim_progress(0.0)
		chase_timer_before_leap = 0.0


func _update_hobgoblin_ground_shadow_motion() -> void:
	if ground_shadow == null:
		return
	# Base enemy.gd updates the default shadow first; this applies hobgoblin leap-specific motion.
	if leap_is_airborne:
		ground_shadow.scale *= Vector2(0.68, 0.68)
		ground_shadow.modulate.a = clamp(ground_shadow.modulate.a * 0.7, 0.12, 0.72)
		return
	if leap_landing_timer > 0.0:
		var land_t: float = 1.0 - (leap_landing_timer / max(HOBGOBLIN_LANDING_ANIM_TIME, 0.001))
		var impact_boost: float = 1.22 - (land_t * 0.22)
		ground_shadow.scale *= Vector2(impact_boost, impact_boost * 0.96)
		ground_shadow.modulate.a = clamp(ground_shadow.modulate.a + (0.16 * (1.0 - land_t)), 0.12, 0.86)
		return
	if leap_is_winding_up:
		ground_shadow.scale *= Vector2(0.94, 0.92)


func _should_hold_position() -> bool:
	return leap_is_winding_up or leap_is_airborne or leap_landing_timer > 0.0


func _disable_contact_damage() -> bool:
	return leap_is_winding_up or leap_is_airborne or leap_landing_timer > 0.0


func _has_forced_velocity() -> bool:
	return leap_is_airborne


func _get_forced_velocity() -> Vector2:
	return Vector2.ZERO


func _show_leap_indicator() -> void:
	if leap_indicator == null:
		leap_indicator = Polygon2D.new()
		leap_indicator.polygon = _build_circle_polygon(_hob_leap_aoe_radius(), 30)
		leap_indicator.color = Color(0.58, 0.04, 0.04, HOBGOBLIN_INDICATOR_ALPHA_MIN)
		leap_indicator.z_index = -2
		add_child(leap_indicator)
	if leap_indicator_inner == null:
		leap_indicator_inner = Polygon2D.new()
		leap_indicator_inner.polygon = _build_circle_polygon(_hob_leap_aoe_radius() * 0.58, 24)
		leap_indicator_inner.color = Color(0.74, 0.13, 0.13, HOBGOBLIN_INDICATOR_ALPHA_MIN * 0.82)
		leap_indicator_inner.z_index = -2
		add_child(leap_indicator_inner)
	if leap_outline_red == null:
		leap_outline_red = Line2D.new()
		leap_outline_red.points = leap_indicator.polygon
		leap_outline_red.closed = true
		leap_outline_red.width = 1.2
		leap_outline_red.default_color = Color(0.58, 0.04, 0.04, 0.8)
		leap_outline_red.joint_mode = Line2D.LINE_JOINT_ROUND
		leap_outline_red.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leap_outline_red.end_cap_mode = Line2D.LINE_CAP_ROUND
		leap_outline_red.z_index = 0
		add_child(leap_outline_red)
	leap_indicator.position = leap_target_position - global_position
	if leap_indicator_inner != null:
		leap_indicator_inner.position = leap_target_position - global_position
	if leap_outline_red != null:
		leap_outline_red.position = leap_target_position - global_position
	leap_indicator.visible = true
	if leap_indicator_inner != null:
		leap_indicator_inner.visible = true
	if leap_outline_red != null:
		leap_outline_red.visible = true
	_update_leap_indicator_visual()


func _ensure_leap_shadow() -> void:
	return


func _update_leap_shadow(arc_height: float) -> void:
	var _unused_arc_height: float = arc_height
	return


func _update_leap_indicator_visual() -> void:
	if leap_indicator == null or not leap_indicator.visible:
		return
	leap_indicator.position = leap_target_position - global_position
	if leap_indicator_inner != null:
		leap_indicator_inner.position = leap_target_position - global_position
	if leap_outline_red != null:
		leap_outline_red.position = leap_target_position - global_position
	var progress: float = clamp(1.0 - (leap_windup_timer / max(HOBGOBLIN_LEAP_WINDUP, 0.001)), 0.0, 1.0)
	var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.001 * lerp(2.0, 6.0, progress)))
	var alpha: float = lerp(HOBGOBLIN_INDICATOR_ALPHA_MIN, HOBGOBLIN_INDICATOR_ALPHA_MAX, pulse)
	leap_indicator.modulate.a = alpha
	if leap_indicator_inner != null:
		leap_indicator_inner.modulate.a = alpha * 0.85
	if leap_outline_red != null:
		leap_outline_red.default_color = Color(0.58, 0.04, 0.04, clamp(0.22 + alpha, 0.2, 0.82))


func _hide_leap_indicator() -> void:
	if leap_indicator != null:
		leap_indicator.visible = false
	if leap_indicator_inner != null:
		leap_indicator_inner.visible = false
	if leap_outline_red != null:
		leap_outline_red.visible = false


func _apply_leap_impact_damage() -> void:
	var impact_center: Vector2 = global_position
	_spawn_hobgoblin_landing_smoke(impact_center)
	var fx_anchor: Node2D = Node2D.new()
	fx_anchor.global_position = impact_center
	fx_anchor.z_index = -2
	var fx_parent: Node = get_parent() if get_parent() != null else self
	fx_parent.add_child(fx_anchor)

	var landing_core: Polygon2D = Polygon2D.new()
	landing_core.polygon = _build_circle_polygon(_hob_leap_aoe_radius() * 0.7, 28)
	landing_core.color = Color(1.0, 0.36, 0.24, 0.32)
	landing_core.z_index = 0
	fx_anchor.add_child(landing_core)
	landing_core.position = Vector2.ZERO
	var core_tween: Tween = create_tween()
	core_tween.tween_property(landing_core, "modulate:a", 0.0, 0.18)
	core_tween.parallel().tween_property(landing_core, "scale", Vector2(1.22, 1.22), 0.18)
	core_tween.tween_callback(landing_core.queue_free)

	var landing_ring: Polygon2D = Polygon2D.new()
	landing_ring.polygon = _build_circle_polygon(_hob_leap_aoe_radius(), 36)
	landing_ring.color = Color(1.0, 0.62, 0.35, 0.28)
	landing_ring.z_index = 0
	landing_ring.scale = Vector2(0.7, 0.7)
	fx_anchor.add_child(landing_ring)
	landing_ring.position = Vector2.ZERO
	var ring_tween: Tween = create_tween()
	ring_tween.tween_property(landing_ring, "scale", Vector2(1.28, 1.28), 0.24)
	ring_tween.parallel().tween_property(landing_ring, "modulate:a", 0.0, 0.24)
	ring_tween.tween_callback(landing_ring.queue_free)

	for i in range(8):
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -5),
			Vector2(3, 0),
			Vector2(0, 5),
			Vector2(-3, 0)
		])
		shard.color = Color(1.0, 0.7, 0.4, 0.55)
		shard.z_index = 1
		fx_anchor.add_child(shard)
		shard.position = Vector2.ZERO
		var shard_dir: Vector2 = Vector2.RIGHT.rotated((TAU * float(i)) / 8.0 + randf_range(-0.12, 0.12))
		var shard_dist: float = randf_range(_hob_leap_aoe_radius() * 0.45, _hob_leap_aoe_radius() * 0.75)
		var shard_tween: Tween = create_tween()
		shard_tween.tween_property(shard, "position", shard.position + (shard_dir * shard_dist), 0.18)
		shard_tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.18)
		shard_tween.parallel().tween_property(shard, "scale", Vector2(1.35, 1.35), 0.18)
		shard_tween.tween_callback(shard.queue_free)

	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(0.3)
	cleanup_tween.tween_callback(fx_anchor.queue_free)
	_push_nearby_enemies(impact_center, _hob_leap_aoe_radius() + 20.0, 340.0, 34.0, 0.28)
	if target_player != null and is_instance_valid(target_player) and target_player.has_method("add_screen_shake"):
		target_player.call("add_screen_shake", 14.0, 0.2)
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	if target_player.global_position.distance_to(global_position) <= _hob_leap_aoe_radius():
		var impact_damage: int = int(round(float(_get_contact_damage()) * _hob_leap_damage_mult()))
		target_player.call("receive_damage", impact_damage)
		if target_player.has_method("apply_launch_force"):
			target_player.call("apply_launch_force", impact_center, 460.0, 36.0, 0.34)


func _spawn_hobgoblin_landing_smoke(impact_center: Vector2) -> void:
	_spawn_world_vfx_scene(hobgoblin_landing_smoke_vfx_scene, impact_center, 3, Vector2(1.18, 1.18))


func _exit_tree() -> void:
	if leap_indicator != null:
		leap_indicator.queue_free()
		leap_indicator = null
	if leap_indicator_inner != null:
		leap_indicator_inner.queue_free()
		leap_indicator_inner = null
	if leap_outline_red != null:
		leap_outline_red.queue_free()
		leap_outline_red = null


func _set_leap_anim_progress(progress: float) -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	var anim_name: StringName = _get_attack_anim_for_direction(leap_direction)
	if anim.animation != anim_name:
		anim.play(anim_name)
	anim.speed_scale = 0.0
	var frame_idx: int = int(floor(clamp(progress, 0.0, 0.999) * 4.0))
	anim.frame = clampi(frame_idx, 0, 3)
	anim.frame_progress = 0.0


func _get_attack_anim_for_direction(direction: Vector2) -> StringName:
	# Force front/back attack set; left/right attack frames are intentionally unused.
	if direction.y < 0.0:
		return &"back_attack"
	return &"front_attack"


func _reset_sprite_after_leap() -> void:
	$AnimatedSprite2D.position = base_sprite_position
	$AnimatedSprite2D.scale = base_sprite_scale
	$AnimatedSprite2D.modulate.a = 1.0
	$AnimatedSprite2D.speed_scale = 1.0
	_update_leap_shadow(0.0)


func _play_walk_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	$AnimatedSprite2D.speed_scale = 1.0
	# Force front/back walk set for a cleaner silhouette.
	if direction.y < 0.0:
		$AnimatedSprite2D.play("enemy_back")
	else:
		$AnimatedSprite2D.play("enemy_front")
	_sync_elite_aura_anim()


func _play_attack_animation(direction: Vector2) -> void:
	attack_anim_timer = ATTACK_ANIM_DURATION
	$AnimatedSprite2D.speed_scale = 1.0
	# Force front/back attack set for readability.
	if direction.y < 0.0:
		$AnimatedSprite2D.play("back_attack")
	else:
		$AnimatedSprite2D.play("front_attack")
	_sync_elite_aura_anim()
