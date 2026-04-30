extends "res://scripts/enemy.gd"

const ELEC_HP_MULT: float = 1.2
const ELEC_SPEED_MULT: float = 0.92
const ELEC_DAMAGE_MULT: float = 1.12
const ELEC_CAST_COOLDOWN_MIN: float = 3.2
const ELEC_CAST_COOLDOWN_MAX: float = 4.6
const ELEC_CHANNEL_TIME: float = 1.55
const ELEC_MIN_CAST_RANGE: float = 150.0
const ELEC_MAX_CAST_RANGE: float = 560.0
const ELEC_CHASE_DISTANCE: float = 260.0
const ELEC_LINE_SEGMENT_COUNT: int = 7
const ELEC_SEGMENT_LENGTH: float = 72.0
const ELEC_SEGMENT_HALF_WIDTH: float = 24.0
const ELEC_SEGMENT_DAMAGE_MULT: float = 1.15
const ELEC_VISUAL_SCALE: float = 1.22
const ELEC_INCANT_SCALE: float = 0.58
const ELEC_PROJECTILE_SCALE: float = 0.26
const ELEC_PROJECTILE_HEIGHT: float = 44.0
const ELEC_EXPLOSION_Y_OFFSET: float = 8.0
const ELEC_STRIKE_DROP_HEIGHT: float = 120.0
const ELEC_STRIKE_DROP_TIME: float = 0.08

var cast_cooldown: float = 0.0
var channel_timer: float = 0.0
var is_channeling: bool = false
var should_chase_player: bool = true
var impact_events: Array[Dictionary] = []
var cast_particles: CPUParticles2D = null
var ambient_electric_particles: CPUParticles2D = null
@onready var incantation_sprite_node: AnimatedSprite2D = get_node_or_null("IncantationSprite") as AnimatedSprite2D
@onready var cast_projectile_sprite_node: AnimatedSprite2D = get_node_or_null("CastProjectileSprite") as AnimatedSprite2D
@onready var explosion_sprite_template: AnimatedSprite2D = get_node_or_null("ExplosionSprite") as AnimatedSprite2D
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	super._ready()
	current_health = int(round(float(current_health) * ELEC_HP_MULT))
	elite_max_health = current_health
	elite_speed_multiplier *= ELEC_SPEED_MULT
	elite_damage_multiplier *= ELEC_DAMAGE_MULT
	xp_reward = max(xp_reward + 1, 2)
	xp_tier = "green"
	$AnimatedSprite2D.scale *= ELEC_VISUAL_SCALE
	$AnimatedSprite2D.modulate = Color(0.62, 0.86, 1.0, 1.0)
	cast_cooldown = randf_range(0.9, 1.9)
	_setup_cast_particles()
	_setup_ambient_particles()


func get_enemy_archetype() -> String:
	return "electric_mage"


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
		super._play_attack_animation(direction)
		return
	_sync_elite_aura_anim()


func _update_archetype_behavior(delta: float, direction: Vector2, distance: float) -> void:
	cast_cooldown = max(cast_cooldown - delta, 0.0)
	_update_electric_impacts(delta)
	should_chase_player = distance > ELEC_CHASE_DISTANCE
	_set_incant_collision_disabled(is_channeling)

	if is_channeling:
		channel_timer = max(channel_timer - delta, 0.0)
		if attack_anim_timer <= 0.0:
			_play_attack_animation(direction)
		if channel_timer <= 0.0:
			is_channeling = false
			_set_incant_collision_disabled(false)
			_hide_incantation()
			_schedule_electric_line(direction)
		return

	if impact_events.is_empty() and cast_cooldown <= 0.0 and distance >= ELEC_MIN_CAST_RANGE and distance <= ELEC_MAX_CAST_RANGE:
		_start_channel(direction)


func _should_hold_position() -> bool:
	return is_channeling or not impact_events.is_empty() or not should_chase_player


func _disable_contact_damage() -> bool:
	return is_channeling or not impact_events.is_empty()


func _has_forced_velocity() -> bool:
	return is_channeling


func _get_forced_velocity() -> Vector2:
	return Vector2.ZERO


func _start_channel(direction: Vector2) -> void:
	is_channeling = true
	channel_timer = ELEC_CHANNEL_TIME
	cast_cooldown = randf_range(ELEC_CAST_COOLDOWN_MIN, ELEC_CAST_COOLDOWN_MAX)
	knockback_velocity = Vector2.ZERO
	_set_incant_collision_disabled(true)
	_show_incantation()
	_show_cast_projectile()
	_play_attack_animation(direction)


func _show_incantation() -> void:
	if incantation_sprite_node != null:
		incantation_sprite_node.visible = true
		incantation_sprite_node.scale = Vector2(ELEC_INCANT_SCALE, ELEC_INCANT_SCALE)
		if incantation_sprite_node.sprite_frames != null and incantation_sprite_node.sprite_frames.has_animation(&"incantation_loop"):
			incantation_sprite_node.play(&"incantation_loop")
	if cast_particles != null:
		cast_particles.visible = true
		cast_particles.emitting = true


func _hide_incantation() -> void:
	if incantation_sprite_node != null:
		incantation_sprite_node.visible = false
	if cast_particles != null:
		cast_particles.emitting = false
		cast_particles.visible = false


func _show_cast_projectile() -> void:
	if cast_projectile_sprite_node != null:
		cast_projectile_sprite_node.visible = true
		cast_projectile_sprite_node.position = Vector2(0.0, -ELEC_PROJECTILE_HEIGHT)
		cast_projectile_sprite_node.scale = Vector2(ELEC_PROJECTILE_SCALE, ELEC_PROJECTILE_SCALE)
		if cast_projectile_sprite_node.sprite_frames != null and cast_projectile_sprite_node.sprite_frames.has_animation(&"projectile_loop"):
			cast_projectile_sprite_node.play(&"projectile_loop")


func _hide_cast_projectile() -> void:
	if cast_projectile_sprite_node != null:
		cast_projectile_sprite_node.visible = false


func _schedule_electric_line(direction: Vector2) -> void:
	if target_player == null or not is_instance_valid(target_player):
		_hide_cast_projectile()
		return
	var base_dir: Vector2 = direction if direction != Vector2.ZERO else (target_player.global_position - global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var start_pos: Vector2 = global_position + (base_dir * 46.0)
	for i in range(ELEC_LINE_SEGMENT_COUNT):
		var segment_center: Vector2 = start_pos + (base_dir * (ELEC_SEGMENT_LENGTH * float(i)))
		var telegraph_outer: Polygon2D = Polygon2D.new()
		telegraph_outer.polygon = _build_circle_polygon(ELEC_SEGMENT_HALF_WIDTH, 26)
		telegraph_outer.color = Color(1.0, 0.18, 0.18, 0.16)
		telegraph_outer.global_position = segment_center
		telegraph_outer.z_index = -1
		get_parent().add_child(telegraph_outer)

		var telegraph_inner: Polygon2D = Polygon2D.new()
		telegraph_inner.polygon = _build_circle_polygon(ELEC_SEGMENT_HALF_WIDTH * 0.58, 20)
		telegraph_inner.color = Color(1.0, 0.28, 0.28, 0.14)
		telegraph_inner.global_position = segment_center
		telegraph_inner.z_index = -1
		get_parent().add_child(telegraph_inner)
		var impact_delay: float = 0.38 + (float(i) * 0.24)
		impact_events.append({
			"time_left": impact_delay,
			"impact_total": impact_delay,
			"segment_center": segment_center,
			"segment_dir": base_dir,
			"telegraph_outer": telegraph_outer,
			"telegraph_inner": telegraph_inner
		})


func _update_electric_impacts(delta: float) -> void:
	if impact_events.is_empty():
		return
	for i in range(impact_events.size() - 1, -1, -1):
		var evt: Dictionary = impact_events[i]
		var time_left: float = max(float(evt.get("time_left", 0.0)) - delta, 0.0)
		evt["time_left"] = time_left
		impact_events[i] = evt
		var telegraph_outer: Polygon2D = evt.get("telegraph_outer", null) as Polygon2D
		var telegraph_inner: Polygon2D = evt.get("telegraph_inner", null) as Polygon2D
		if telegraph_outer != null:
			var total: float = max(float(evt.get("impact_total", 0.01)), 0.01)
			var progress: float = clamp(1.0 - (time_left / total), 0.0, 1.0)
			var pulse_speed: float = lerp(2.0, 16.0, progress)
			var pulse: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed))
			telegraph_outer.modulate.a = lerp(0.12, 0.68, pulse)
			var ring_scale: float = lerp(0.98, 1.08, pulse * 0.5)
			telegraph_outer.scale = Vector2(ring_scale, ring_scale)
			if telegraph_inner != null:
				telegraph_inner.modulate.a = lerp(0.1, 0.56, pulse)
				telegraph_inner.scale = Vector2(ring_scale * 1.02, ring_scale * 1.02)
		if time_left > 0.0:
			continue
		_apply_electric_segment_hit(evt)
		if telegraph_outer != null:
			telegraph_outer.queue_free()
		if telegraph_inner != null:
			telegraph_inner.queue_free()
		impact_events.remove_at(i)
	if impact_events.is_empty():
		_hide_cast_projectile()


func _apply_electric_segment_hit(evt: Dictionary) -> void:
	var center: Vector2 = evt.get("segment_center", global_position)
	var dir: Vector2 = evt.get("segment_dir", Vector2.RIGHT).normalized()
	_spawn_explosion_vfx(center, dir)
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	var player_pos: Vector2 = target_player.global_position
	var a: Vector2 = center - (dir * (ELEC_SEGMENT_LENGTH * 0.5))
	var b: Vector2 = center + (dir * (ELEC_SEGMENT_LENGTH * 0.5))
	var dist: float = _distance_point_to_segment(player_pos, a, b)
	if dist <= ELEC_SEGMENT_HALF_WIDTH:
		var dmg: int = int(round(float(_get_contact_damage()) * ELEC_SEGMENT_DAMAGE_MULT))
		target_player.call("receive_damage", dmg)


func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + (ab * t)
	return point.distance_to(closest)


func _spawn_explosion_vfx(world_pos: Vector2, _dir: Vector2) -> void:
	if explosion_sprite_template == null or explosion_sprite_template.sprite_frames == null or get_parent() == null:
		return
	var fx: AnimatedSprite2D = explosion_sprite_template.duplicate() as AnimatedSprite2D
	if fx == null:
		return
	fx.visible = true
	var anim_name: StringName = &"explosion"
	if not fx.sprite_frames.has_animation(anim_name):
		anim_name = fx.animation
	fx.z_index = 2
	# Keep it vertical (no rotation) for the lightning-from-heaven look.
	fx.rotation = 0.0
	fx.scale = Vector2(0.42, 0.7)
	var ground_tip: Vector2 = world_pos + Vector2(0.0, ELEC_EXPLOSION_Y_OFFSET)
	var center_offset: float = _get_explosion_center_offset_y(fx, anim_name)
	var ground_pos: Vector2 = ground_tip + Vector2(0.0, -center_offset)
	# var start_pos: Vector2 = ground_pos + Vector2(0.0, -ELEC_STRIKE_DROP_HEIGHT)
	# fx.global_position = start_pos
	fx.global_position = ground_pos
	get_parent().add_child(fx)
	# Drop-from-above preview disabled for now:
	# var drop_tween: Tween = create_tween()
	# drop_tween.tween_property(fx, "global_position", ground_pos, ELEC_STRIKE_DROP_TIME)
	# drop_tween.tween_callback(func() -> void:
	# 	if is_instance_valid(fx):
	# 		fx.play(anim_name)
	# )
	fx.play(anim_name)
	var frame_count: int = fx.sprite_frames.get_frame_count(anim_name)
	var anim_speed: float = max(fx.sprite_frames.get_animation_speed(anim_name), 1.0)
	var lifetime: float = max(float(frame_count) / (anim_speed * max(fx.speed_scale, 0.01)), 0.12)
	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(lifetime + 0.03)
	cleanup_tween.tween_callback(fx.queue_free)


func _get_explosion_center_offset_y(fx: AnimatedSprite2D, anim_name: StringName) -> float:
	if fx == null or fx.sprite_frames == null:
		return 0.0
	var tex: Texture2D = fx.sprite_frames.get_frame_texture(anim_name, 0)
	if tex == null:
		return 0.0
	var h: float = tex.get_size().y * fx.scale.y
	# AnimatedSprite2D is centered by default, so center sits half-height above the tip.
	return h * 0.5


func _setup_cast_particles() -> void:
	cast_particles = CPUParticles2D.new()
	cast_particles.amount = 18
	cast_particles.lifetime = 0.6
	cast_particles.one_shot = false
	cast_particles.explosiveness = 0.0
	cast_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	cast_particles.emission_ring_radius = 12.0
	cast_particles.emission_ring_inner_radius = 5.0
	cast_particles.direction = Vector2(0, -1)
	cast_particles.spread = 180.0
	cast_particles.gravity = Vector2(0, -8.0)
	cast_particles.initial_velocity_min = 8.0
	cast_particles.initial_velocity_max = 20.0
	cast_particles.scale_amount_min = 0.22
	cast_particles.scale_amount_max = 0.44
	cast_particles.color = Color(0.42, 0.82, 1.0, 0.72)
	cast_particles.position = Vector2(0.0, -10.0)
	cast_particles.z_index = 5
	cast_particles.visible = false
	cast_particles.emitting = false
	add_child(cast_particles)


func _setup_ambient_particles() -> void:
	ambient_electric_particles = CPUParticles2D.new()
	ambient_electric_particles.amount = 14
	ambient_electric_particles.lifetime = 0.95
	ambient_electric_particles.one_shot = false
	ambient_electric_particles.explosiveness = 0.06
	ambient_electric_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	ambient_electric_particles.emission_ring_radius = 13.0
	ambient_electric_particles.emission_ring_inner_radius = 6.0
	ambient_electric_particles.direction = Vector2(0.0, -1.0)
	ambient_electric_particles.spread = 180.0
	ambient_electric_particles.gravity = Vector2.ZERO
	ambient_electric_particles.initial_velocity_min = 5.0
	ambient_electric_particles.initial_velocity_max = 14.0
	ambient_electric_particles.scale_amount_min = 0.2
	ambient_electric_particles.scale_amount_max = 0.38
	ambient_electric_particles.color = Color(0.58, 0.9, 1.0, 0.55)
	ambient_electric_particles.position = Vector2(0.0, -6.0)
	ambient_electric_particles.z_index = 4
	add_child(ambient_electric_particles)
	ambient_electric_particles.emitting = true


func _set_incant_collision_disabled(disabled: bool) -> void:
	if body_collision == null:
		return
	if body_collision.disabled == disabled:
		return
	body_collision.set_deferred("disabled", disabled)
