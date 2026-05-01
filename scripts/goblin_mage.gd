extends "res://scripts/enemy.gd"

const MAGE_HP_MULT: float = 1.25
const MAGE_SPEED_MULT: float = 0.9
const MAGE_DAMAGE_MULT: float = 1.15
const MAGE_CAST_COOLDOWN_MIN: float = 2.9
const MAGE_CAST_COOLDOWN_MAX: float = 4.1
const MAGE_CHANNEL_TIME: float = 1.85
const MAGE_VOLLEY_COUNT: int = 4
const MAGE_AOE_RADIUS: float = 56.0
const MAGE_AOE_DAMAGE_MULT: float = 1.3
const MAGE_MIN_CAST_RANGE: float = 140.0
const MAGE_MAX_CAST_RANGE: float = 520.0
const MAGE_CHASE_DISTANCE: float = 250.0
const MAGE_PROJECTILE_HEIGHT: float = 46.0
const MAGE_VISUAL_SCALE: float = 1.24
const MAGE_INCANTATION_BASE_SCALE: float = 0.58
const MAGE_PROJECTILE_BASE_SCALE: float = 0.28
const MAGE_ELITE_INCANTATION_SCALE: float = 1.12
const MAGE_ELITE_AOE_RADIUS_MULT: float = 1.22
const MAGE_TELEGRAPH_COLOR: Color = Color(0.58, 0.04, 0.04, 0.12)
const MAGE_TELEGRAPH_ALPHA_MIN: float = 0.08
const MAGE_TELEGRAPH_ALPHA_MAX: float = 0.24
const MAGE_TELEGRAPH_INNER_COLOR: Color = Color(0.74, 0.13, 0.13, 0.1)
const MAGE_TELEGRAPH_OUTLINE_RED: Color = Color(0.58, 0.04, 0.04, 0.8)
const MAGE_EXPLOSION_Y_OFFSET: float = 8.0

var cast_cooldown: float = 0.0
var channel_timer: float = 0.0
var is_channeling: bool = false
var impact_events: Array[Dictionary] = []
var cast_fire_particles: CPUParticles2D = null
var should_chase_player: bool = true
@onready var incantation_sprite_node: AnimatedSprite2D = get_node_or_null("IncantationSprite") as AnimatedSprite2D
@onready var cast_projectile_sprite_node: AnimatedSprite2D = get_node_or_null("CastProjectileSprite") as AnimatedSprite2D
@onready var explosion_sprite_template: AnimatedSprite2D = get_node_or_null("ExplosionSprite") as AnimatedSprite2D
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	super._ready()
	current_health = int(round(float(current_health) * MAGE_HP_MULT))
	elite_max_health = current_health
	elite_speed_multiplier *= MAGE_SPEED_MULT
	elite_damage_multiplier *= MAGE_DAMAGE_MULT
	xp_reward = max(xp_reward + 1, 2)
	xp_tier = "green"
	$AnimatedSprite2D.scale *= MAGE_VISUAL_SCALE
	$AnimatedSprite2D.modulate = Color(0.78, 0.9, 1.0, 1.0)
	cast_cooldown = randf_range(0.8, 1.7)
	_setup_cast_fire_particles()


func get_enemy_archetype() -> String:
	return "mage"


func _play_walk_animation(direction: Vector2) -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	var desired: StringName = &"enemy_front"
	if abs(direction.x) > abs(direction.y):
		desired = &"mage_right" if direction.x > 0.0 else &"mage_left"
	else:
		desired = &"mage_front" if direction.y > 0.0 else &"mage_back"

	if anim.sprite_frames != null and anim.sprite_frames.has_animation(desired):
		anim.play(desired)
	else:
		super._play_walk_animation(direction)
		return
	_sync_elite_aura_anim()


func _play_attack_animation(direction: Vector2) -> void:
	attack_anim_timer = ATTACK_ANIM_DURATION
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	var desired: StringName = &"front_attack"
	if abs(direction.x) > abs(direction.y):
		desired = &"mage_attack_right" if direction.x >= 0.0 else &"mage_attack_left"
	else:
		desired = &"mage_attack_front" if direction.y >= 0.0 else &"mage_attack_back"

	if anim.sprite_frames != null and anim.sprite_frames.has_animation(desired):
		anim.play(desired)
	else:
		# Fallback to old naming (front/left/right attack) and base behavior.
		super._play_attack_animation(direction)
		return
	_sync_elite_aura_anim()


func _update_archetype_behavior(delta: float, direction: Vector2, distance: float) -> void:
	cast_cooldown = max(cast_cooldown - delta, 0.0)
	_update_mage_impacts(delta)
	should_chase_player = distance > MAGE_CHASE_DISTANCE
	_set_incant_collision_disabled(is_channeling)

	if is_channeling:
		channel_timer = max(channel_timer - delta, 0.0)
		if attack_anim_timer <= 0.0:
			_play_attack_animation(direction)
		if channel_timer <= 0.0:
			is_channeling = false
			_set_incant_collision_disabled(false)
			_hide_incantation_circle()
			_schedule_mage_volley()
		return

	if impact_events.is_empty() and cast_cooldown <= 0.0 and distance >= MAGE_MIN_CAST_RANGE and distance <= MAGE_MAX_CAST_RANGE:
		_start_mage_channel(direction)


func _should_hold_position() -> bool:
	return is_channeling or not impact_events.is_empty() or not should_chase_player


func _disable_contact_damage() -> bool:
	return is_channeling or not impact_events.is_empty()


func _has_forced_velocity() -> bool:
	return is_channeling


func _get_forced_velocity() -> Vector2:
	return Vector2.ZERO


func _start_mage_channel(direction: Vector2) -> void:
	is_channeling = true
	channel_timer = MAGE_CHANNEL_TIME
	cast_cooldown = randf_range(MAGE_CAST_COOLDOWN_MIN, MAGE_CAST_COOLDOWN_MAX)
	knockback_velocity = Vector2.ZERO
	_set_incant_collision_disabled(true)
	_show_incantation_circle()
	_show_cast_projectile()
	_play_attack_animation(direction)


func _show_incantation_circle() -> void:
	if incantation_sprite_node != null:
		incantation_sprite_node.visible = true
		var incant_scale: float = MAGE_INCANTATION_BASE_SCALE * (MAGE_ELITE_INCANTATION_SCALE if is_elite else 1.0)
		incantation_sprite_node.scale = Vector2(incant_scale, incant_scale)
		if incantation_sprite_node.sprite_frames != null and incantation_sprite_node.sprite_frames.has_animation(&"incantation_loop"):
			incantation_sprite_node.play(&"incantation_loop")
	if cast_fire_particles != null:
		cast_fire_particles.visible = true
		cast_fire_particles.emitting = true


func _hide_incantation_circle() -> void:
	if incantation_sprite_node != null:
		incantation_sprite_node.visible = false
	if cast_fire_particles != null:
		cast_fire_particles.emitting = false
		cast_fire_particles.visible = false


func _show_cast_projectile() -> void:
	if cast_projectile_sprite_node != null:
		cast_projectile_sprite_node.visible = true
		cast_projectile_sprite_node.position = Vector2(0.0, -MAGE_PROJECTILE_HEIGHT)
		cast_projectile_sprite_node.scale = Vector2(MAGE_PROJECTILE_BASE_SCALE, MAGE_PROJECTILE_BASE_SCALE)
		if cast_projectile_sprite_node.sprite_frames != null and cast_projectile_sprite_node.sprite_frames.has_animation(&"projectile_loop"):
			cast_projectile_sprite_node.play(&"projectile_loop")


func _hide_cast_projectile() -> void:
	if cast_projectile_sprite_node != null:
		cast_projectile_sprite_node.visible = false


func _schedule_mage_volley() -> void:
	if target_player == null or not is_instance_valid(target_player):
		_hide_cast_projectile()
		return

	for i in range(MAGE_VOLLEY_COUNT):
		var target_pos: Vector2 = _pick_volley_target_position()
		var aoe_radius: float = _get_mage_aoe_radius()
		var telegraph_outer: Polygon2D = Polygon2D.new()
		telegraph_outer.polygon = _build_circle_polygon(aoe_radius, 32)
		telegraph_outer.color = MAGE_TELEGRAPH_COLOR
		telegraph_outer.global_position = target_pos
		telegraph_outer.z_index = -2
		get_parent().add_child(telegraph_outer)

		var telegraph_inner: Polygon2D = Polygon2D.new()
		telegraph_inner.polygon = _build_circle_polygon(aoe_radius * 0.58, 24)
		telegraph_inner.color = MAGE_TELEGRAPH_INNER_COLOR
		telegraph_inner.global_position = target_pos
		telegraph_inner.z_index = -2
		get_parent().add_child(telegraph_inner)
		var telegraph_outline_red: Line2D = Line2D.new()
		telegraph_outline_red.points = telegraph_outer.polygon
		telegraph_outline_red.closed = true
		telegraph_outline_red.width = 1.2
		telegraph_outline_red.default_color = MAGE_TELEGRAPH_OUTLINE_RED
		telegraph_outline_red.joint_mode = Line2D.LINE_JOINT_ROUND
		telegraph_outline_red.begin_cap_mode = Line2D.LINE_CAP_ROUND
		telegraph_outline_red.end_cap_mode = Line2D.LINE_CAP_ROUND
		telegraph_outline_red.global_position = target_pos
		telegraph_outline_red.z_index = 0
		get_parent().add_child(telegraph_outline_red)

		var impact_delay: float = 1.05 + (float(i) * 0.32)
		impact_events.append({
			"time_left": impact_delay,
			"impact_total": impact_delay,
			"target_pos": target_pos,
			"telegraph_outer": telegraph_outer,
			"telegraph_inner": telegraph_inner,
			"telegraph_outline_red": telegraph_outline_red
		})


func _update_mage_impacts(delta: float) -> void:
	if impact_events.is_empty():
		return

	for i in range(impact_events.size() - 1, -1, -1):
		var evt: Dictionary = impact_events[i]
		var time_left: float = max(float(evt.get("time_left", 0.0)) - delta, 0.0)
		evt["time_left"] = time_left
		impact_events[i] = evt

		var telegraph_outer: Polygon2D = evt.get("telegraph_outer", null) as Polygon2D
		var telegraph_inner: Polygon2D = evt.get("telegraph_inner", null) as Polygon2D
		var telegraph_outline_red: Line2D = evt.get("telegraph_outline_red", null) as Line2D
		if telegraph_outer != null:
			var total: float = max(float(evt.get("impact_total", 0.01)), 0.01)
			var progress: float = clamp(1.0 - (time_left / total), 0.0, 1.0)
			var pulse_speed: float = lerp(1.2, 4.0, progress)
			var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed))
			telegraph_outer.modulate.a = lerp(MAGE_TELEGRAPH_ALPHA_MIN, MAGE_TELEGRAPH_ALPHA_MAX, pulse)
			var alpha: float = telegraph_outer.modulate.a
			var ring_scale: float = lerp(0.98, 1.08, pulse * 0.5)
			telegraph_outer.scale = Vector2(ring_scale, ring_scale)
			if telegraph_inner != null:
				telegraph_inner.modulate.a = lerp(MAGE_TELEGRAPH_ALPHA_MIN * 0.8, MAGE_TELEGRAPH_ALPHA_MAX * 0.85, pulse)
				telegraph_inner.scale = Vector2(ring_scale * 1.02, ring_scale * 1.02)
			if telegraph_outline_red != null:
				telegraph_outline_red.default_color = Color(0.58, 0.04, 0.04, clamp(0.22 + alpha, 0.2, 0.82))
				telegraph_outline_red.scale = Vector2(ring_scale, ring_scale)

		if time_left > 0.0:
			continue

		_apply_mage_impact(evt)
		if telegraph_outer != null:
			telegraph_outer.queue_free()
		if telegraph_inner != null:
			telegraph_inner.queue_free()
		if telegraph_outline_red != null:
			telegraph_outline_red.queue_free()
		impact_events.remove_at(i)

	if impact_events.is_empty():
		_hide_cast_projectile()


func _exit_tree() -> void:
	for evt in impact_events:
		var telegraph_outer: Polygon2D = evt.get("telegraph_outer", null) as Polygon2D
		var telegraph_inner: Polygon2D = evt.get("telegraph_inner", null) as Polygon2D
		var telegraph_outline_red: Line2D = evt.get("telegraph_outline_red", null) as Line2D
		if telegraph_outer != null:
			telegraph_outer.queue_free()
		if telegraph_inner != null:
			telegraph_inner.queue_free()
		if telegraph_outline_red != null:
			telegraph_outline_red.queue_free()
	impact_events.clear()


func _apply_mage_impact(evt: Dictionary) -> void:
	var pos: Vector2 = evt.get("target_pos", global_position)
	var aoe_radius: float = _get_mage_aoe_radius()
	_spawn_explosion_vfx(pos, aoe_radius)
	if target_player != null and is_instance_valid(target_player) and target_player.has_method("add_screen_shake"):
		target_player.call("add_screen_shake", 6.0, 0.12)

	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	if target_player.global_position.distance_to(pos) <= aoe_radius:
		var aoe_damage: int = int(round(float(_get_contact_damage()) * MAGE_AOE_DAMAGE_MULT))
		target_player.call("receive_damage", aoe_damage)


func _get_mage_aoe_radius() -> float:
	var elite_mult: float = MAGE_ELITE_AOE_RADIUS_MULT if is_elite else 1.0
	return MAGE_AOE_RADIUS * elite_mult


func _pick_volley_target_position() -> Vector2:
	var fallback: Vector2 = target_player.global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
	var min_separation: float = _get_mage_aoe_radius() * 1.15
	for _attempt in range(8):
		var candidate: Vector2 = target_player.global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
		var overlaps_existing: bool = false
		for evt in impact_events:
			var existing: Vector2 = evt.get("target_pos", candidate)
			if candidate.distance_to(existing) < min_separation:
				overlaps_existing = true
				break
		if not overlaps_existing:
			return candidate
	return fallback


func _spawn_explosion_vfx(world_pos: Vector2, aoe_radius: float) -> void:
	if explosion_sprite_template == null or explosion_sprite_template.sprite_frames == null or get_parent() == null:
		return

	var fx: AnimatedSprite2D = explosion_sprite_template.duplicate() as AnimatedSprite2D
	if fx == null:
		return

	fx.visible = true
	fx.global_position = world_pos + Vector2(0.0, MAGE_EXPLOSION_Y_OFFSET)
	fx.z_index = 2
	var scale_mult: float = clamp(aoe_radius / 100.0, 0.42, 1.15)
	fx.scale = Vector2.ONE * scale_mult
	get_parent().add_child(fx)

	var anim_name: StringName = &"explosion"
	if not fx.sprite_frames.has_animation(anim_name):
		anim_name = fx.animation
	fx.play(anim_name)

	var frame_count: int = fx.sprite_frames.get_frame_count(anim_name)
	var anim_speed: float = max(fx.sprite_frames.get_animation_speed(anim_name), 1.0)
	var lifetime: float = max(float(frame_count) / (anim_speed * max(fx.speed_scale, 0.01)), 0.12)
	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(lifetime + 0.03)
	cleanup_tween.tween_callback(fx.queue_free)


func _setup_cast_fire_particles() -> void:
	cast_fire_particles = CPUParticles2D.new()
	cast_fire_particles.amount = 20
	cast_fire_particles.lifetime = 0.5
	cast_fire_particles.one_shot = false
	cast_fire_particles.explosiveness = 0.0
	cast_fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	cast_fire_particles.emission_ring_radius = 13.0
	cast_fire_particles.emission_ring_inner_radius = 5.0
	cast_fire_particles.direction = Vector2(0, -1)
	cast_fire_particles.spread = 160.0
	cast_fire_particles.gravity = Vector2(0, -10.0)
	cast_fire_particles.initial_velocity_min = 10.0
	cast_fire_particles.initial_velocity_max = 26.0
	cast_fire_particles.scale_amount_min = 0.2
	cast_fire_particles.scale_amount_max = 0.42
	cast_fire_particles.color = Color(1.0, 0.4, 0.15, 0.72)
	cast_fire_particles.position = Vector2(0.0, -10.0)
	cast_fire_particles.z_index = 5
	cast_fire_particles.visible = false
	cast_fire_particles.emitting = false
	add_child(cast_fire_particles)


func _set_incant_collision_disabled(disabled: bool) -> void:
	if body_collision == null:
		return
	if body_collision.disabled == disabled:
		return
	body_collision.set_deferred("disabled", disabled)
