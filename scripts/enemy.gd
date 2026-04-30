extends CharacterBody2D

signal defeated(world_position: Vector2, xp_value: int, xp_tier: String)

const BASE_SPEED: float = 82.0
const MAX_HEALTH: int = 30
const CONTACT_DAMAGE: int = 9
const CONTACT_COOLDOWN_SECONDS: float = 0.75
const CONTACT_RANGE: float = 40.0
const XP_REWARD: int = 1
const XP_TIER: String = "blue"
const KNOCKBACK_DECAY: float = 14.0
const HORDE_RUN_SPEED: float = 240.0
const HORDE_DESPAWN_DISTANCE: float = 1250.0
const ATTACK_ANIM_DURATION: float = 0.16
const ELITE_SCALE: float = 1.24
const ELITE_HP_MULTIPLIER: float = 3.0
const ELITE_DAMAGE_MULTIPLIER: float = 1.8
const ELITE_SPEED_MULTIPLIER: float = 0.82
const ELITE_XP_MULTIPLIER: int = 6
const ELITE_TINT: Color = Color(0.95, 0.95, 1.0, 1.0)
const ELITE_AURA_ALPHA_MIN: float = 0.20
const ELITE_AURA_ALPHA_MAX: float = 0.34
const ELITE_AURA_COLOR: Color = Color(0.42, 0.72, 1.0, 0.45)
const ELITE_TYPES: Array[String] = ["brute", "blink", "tank"]
const BRUTE_CHARGE_COOLDOWN_MIN: float = 2.1
const BRUTE_CHARGE_COOLDOWN_MAX: float = 3.4
const BRUTE_CHARGE_WINDUP: float = 1.2
const BRUTE_CHARGE_DURATION: float = 1.35
const BRUTE_CHARGE_SPEED_MULTIPLIER: float = 7.4
const BRUTE_CHARGE_LUNGE_SPEED: float = 1180.0
const BRUTE_CHARGE_OVERSHOOT_DISTANCE: float = 125.0
const BRUTE_CHARGE_TARGET_REACHED_DISTANCE: float = 26.0
const BRUTE_CHARGE_DAMAGE_MULTIPLIER: float = 1.45
const BRUTE_CHARGE_CONTACT_COOLDOWN: float = 0.35
const BRUTE_RECOVER_DURATION: float = 1.0
const BRUTE_RECOVER_DAMAGE_TAKEN_MULTIPLIER: float = 1.6
const BRUTE_WINDUP_INDICATOR_LENGTH: float = 120.0
const BRUTE_WINDUP_INDICATOR_WIDTH: float = 44.0
const BRUTE_INDICATOR_BASE_ALPHA: float = 0.08
const BRUTE_INDICATOR_PEAK_ALPHA: float = 0.28
const TANK_ELITE_EXTRA_SCALE: float = 1.22
const BLINK_TP_VFX_SCENE_PATH: String = "res://scenes/vfx/BlinkTeleportVfx.tscn"

var current_health: int = MAX_HEALTH
var target_player: Node2D = null
var contact_cooldown: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_horde_runner: bool = false
var horde_direction: Vector2 = Vector2.RIGHT
var attack_anim_timer: float = 0.0
var is_elite: bool = false
var elite_speed_multiplier: float = 1.0
var elite_damage_multiplier: float = 1.0
var xp_reward: int = XP_REWARD
var xp_tier: String = XP_TIER
var elite_aura_sprite: AnimatedSprite2D = null
var elite_sheen_sprite: AnimatedSprite2D = null
var elite_type: String = ""
var elite_blink_cooldown: float = 0.0
var elite_blink_cooldown_max: float = 3.1
var elite_blink_distance: float = 88.0
var elite_brute_knockback_resist: float = 1.0
var elite_max_health: int = MAX_HEALTH
var brute_charge_cooldown: float = 0.0
var brute_charge_windup_timer: float = 0.0
var brute_charge_timer: float = 0.0
var brute_is_charging: bool = false
var brute_is_winding_up: bool = false
var brute_recover_timer: float = 0.0
var brute_charge_direction: Vector2 = Vector2.RIGHT
var brute_charge_target_position: Vector2 = Vector2.ZERO
var brute_has_hit_during_charge: bool = false
var brute_charge_indicator: Polygon2D = null
var brute_charge_endpoint_indicator: Polygon2D = null
var brute_rest_label: Label = null
var elite_magic_particles: CPUParticles2D = null
var blink_tp_vfx_scene: PackedScene = preload(BLINK_TP_VFX_SCENE_PATH)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enemy")
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	_randomize_anim_phase()


func _physics_process(delta: float) -> void:
	contact_cooldown = max(contact_cooldown - delta, 0.0)
	elite_blink_cooldown = max(elite_blink_cooldown - delta, 0.0)
	brute_charge_cooldown = max(brute_charge_cooldown - delta, 0.0)
	if brute_is_winding_up:
		brute_charge_windup_timer = max(brute_charge_windup_timer - delta, 0.0)
		_update_brute_charge_indicator_visual()
		if brute_charge_windup_timer <= 0.0:
			brute_is_winding_up = false
			brute_has_hit_during_charge = false
			# Charge path is locked at windup start; don't retarget at release.
			brute_charge_timer = BRUTE_CHARGE_DURATION
			brute_is_charging = true
			_hide_brute_rest_indicator()
			_hide_brute_charge_indicator()
			$AnimatedSprite2D.modulate = Color(1.35, 0.65, 0.65, 1.0)
	if brute_is_charging:
		brute_charge_timer = max(brute_charge_timer - delta, 0.0)
		if brute_charge_timer <= 0.0:
			brute_is_charging = false
			brute_recover_timer = BRUTE_RECOVER_DURATION
			$AnimatedSprite2D.modulate = Color(0.95, 0.55, 0.55, 1.0)
			_show_brute_rest_indicator()
	if brute_recover_timer > 0.0:
		brute_recover_timer = max(brute_recover_timer - delta, 0.0)
		if brute_recover_timer <= 0.0:
			_hide_brute_rest_indicator()
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	attack_anim_timer = max(attack_anim_timer - delta, 0.0)

	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	if is_horde_runner:
		velocity = (horde_direction * HORDE_RUN_SPEED * elite_speed_multiplier) + knockback_velocity
		move_and_slide()
		if attack_anim_timer <= 0.0:
			_play_walk_animation(horde_direction)
		var horde_distance_to_player: float = global_position.distance_to(target_player.global_position)
		if horde_distance_to_player > HORDE_DESPAWN_DISTANCE:
			queue_free()
			return
		if horde_distance_to_player <= _get_contact_range() and contact_cooldown <= 0.0 and target_player.has_method("receive_damage"):
			target_player.call("receive_damage", _get_contact_damage())
			_on_elite_contact_hit()
			_play_attack_animation(horde_direction)
			contact_cooldown = _get_contact_cooldown()
		return

	if _is_brute_charging():
		# Force lunge movement; bypass chase steering so charge is unmistakable.
		var dist_to_target: float = global_position.distance_to(brute_charge_target_position)
		if dist_to_target <= BRUTE_CHARGE_TARGET_REACHED_DISTANCE:
			brute_is_charging = false
			brute_recover_timer = BRUTE_RECOVER_DURATION
			$AnimatedSprite2D.modulate = Color(0.95, 0.55, 0.55, 1.0)
		else:
			knockback_velocity = Vector2.ZERO
			global_position += brute_charge_direction * BRUTE_CHARGE_LUNGE_SPEED * delta
			_apply_brute_charge_hitbox_damage()
			if attack_anim_timer <= 0.0:
				_play_walk_animation(brute_charge_direction)
		return

	var to_player: Vector2 = target_player.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.ZERO
	_update_archetype_behavior(delta, direction, distance)
	if is_elite:
		_update_elite_ability(direction, distance)

	var move_direction: Vector2 = direction
	var move_speed_multiplier: float = elite_speed_multiplier
	if _should_hold_position():
		move_direction = Vector2.ZERO
		move_speed_multiplier = 0.0
		knockback_velocity = Vector2.ZERO
	elif _is_brute_charge_windup():
		# Brute should visibly stop before a charge.
		move_direction = Vector2.ZERO
		move_speed_multiplier = 0.0
		knockback_velocity = Vector2.ZERO
	elif _is_brute_recovering():
		move_direction = Vector2.ZERO
		move_speed_multiplier = 0.0
	elif _is_brute_charging():
		# Force charge vector so chase/knockback can't override it.
		move_direction = brute_charge_direction
		move_speed_multiplier *= BRUTE_CHARGE_SPEED_MULTIPLIER
		knockback_velocity = Vector2.ZERO
	if _has_forced_velocity():
		velocity = _get_forced_velocity()
	else:
		velocity = (move_direction * BASE_SPEED * move_speed_multiplier)
		if not (_is_brute_charge_windup() or _is_brute_charging()):
			velocity += knockback_velocity
	move_and_slide()
	if attack_anim_timer <= 0.0 and not _is_brute_charge_windup():
		_play_walk_animation(move_direction)

	if not _disable_contact_damage() and distance <= _get_contact_range() and contact_cooldown <= 0.0 and target_player.has_method("receive_damage"):
		target_player.call("receive_damage", _get_contact_damage())
		_on_elite_contact_hit()
		_play_attack_animation(direction)
		contact_cooldown = _get_contact_cooldown()


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if _is_brute_recovering():
		amount = int(round(float(amount) * BRUTE_RECOVER_DAMAGE_TAKEN_MULTIPLIER))
	current_health = max(current_health - amount, 0)
	_show_hit_feedback(amount)
	if knockback_force > 0.0 and source_position != Vector2.ZERO:
		# Don't let knockback cancel brute windup/charge behavior.
		if not (elite_type == "brute" and (_is_brute_charge_windup() or _is_brute_charging())):
			var kb_dir: Vector2 = (global_position - source_position).normalized()
			if kb_dir != Vector2.ZERO:
				knockback_velocity = kb_dir * knockback_force * elite_brute_knockback_resist

	if current_health <= 0:
		if is_elite:
			_spawn_elite_death_effect()
		defeated.emit(global_position, xp_reward, xp_tier)
		queue_free()


func _play_walk_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			$AnimatedSprite2D.play("enemy_right")
		else:
			$AnimatedSprite2D.play("enemy_left")
	else:
		if direction.y > 0:
			$AnimatedSprite2D.play("enemy_front")
		else:
			$AnimatedSprite2D.play("enemy_back")
	_sync_elite_aura_anim()


func _show_hit_feedback(damage: int) -> void:
	$AnimatedSprite2D.modulate = Color(3.2, 3.2, 3.2, 1.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property($AnimatedSprite2D, "modulate", _get_base_sprite_modulate(), 0.12)

	var damage_label: Label = Label.new()
	damage_label.text = str(damage)
	damage_label.modulate = Color(1.0, 0.95, 0.95, 1.0)
	damage_label.position = Vector2(-8, -30)
	var label_settings: LabelSettings = LabelSettings.new()
	label_settings.font = ThemeDB.fallback_font
	label_settings.font_size = 11
	damage_label.label_settings = label_settings
	add_child(damage_label)
	var dmg_tween: Tween = create_tween()
	dmg_tween.tween_property(damage_label, "position:y", -52.0, 0.24)
	dmg_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.24)
	dmg_tween.tween_callback(damage_label.queue_free)

func _play_attack_animation(direction: Vector2) -> void:
	attack_anim_timer = ATTACK_ANIM_DURATION
	if abs(direction.x) > abs(direction.y):
		if direction.x >= 0.0:
			$AnimatedSprite2D.play("right_attack")
		else:
			$AnimatedSprite2D.play("left_attack")
	else:
		$AnimatedSprite2D.play("front_attack")
	_sync_elite_aura_anim()


func configure_as_horde_runner(direction: Vector2) -> void:
	is_horde_runner = true
	horde_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_randomize_anim_phase()


func configure_as_elite(progress_ratio: float = 0.0, forced_type: String = "") -> void:
	if is_elite:
		return
	is_elite = true

	var progress_bonus: float = clamp(progress_ratio, 0.0, 1.0)
	var hp_mult: float = ELITE_HP_MULTIPLIER + (progress_bonus * 1.3)
	current_health = int(round(float(MAX_HEALTH) * hp_mult))
	elite_max_health = current_health
	elite_speed_multiplier = ELITE_SPEED_MULTIPLIER + (progress_bonus * 0.12)
	elite_damage_multiplier = ELITE_DAMAGE_MULTIPLIER + (progress_bonus * 0.35)
	xp_reward = XP_REWARD * ELITE_XP_MULTIPLIER
	xp_tier = "red"

	var anim: AnimatedSprite2D = $AnimatedSprite2D
	anim.scale *= ELITE_SCALE
	elite_type = _resolve_elite_type_with_rules(forced_type)
	anim.modulate = _get_elite_sprite_tint()
	_apply_elite_variant_modifiers()
	_create_elite_aura_sprite()
	_create_elite_sheen_sprite()
	_create_elite_magic_particles()
	_start_elite_aura_tween()
	_start_elite_sheen_tween()
	_randomize_anim_phase()


func _randomize_anim_phase() -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	anim.speed_scale = randf_range(0.85, 1.2)
	if anim.sprite_frames != null:
		var current_anim: StringName = anim.animation
		var frame_count: int = anim.sprite_frames.get_frame_count(current_anim)
		if frame_count > 0:
			anim.frame = randi() % frame_count
			anim.frame_progress = randf()


func _create_elite_aura_sprite() -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	elite_aura_sprite = AnimatedSprite2D.new()
	elite_aura_sprite.sprite_frames = anim.sprite_frames
	elite_aura_sprite.animation = anim.animation
	elite_aura_sprite.frame = anim.frame
	elite_aura_sprite.frame_progress = anim.frame_progress
	elite_aura_sprite.position = anim.position
	elite_aura_sprite.scale = anim.scale * 1.12
	elite_aura_sprite.modulate = _get_elite_aura_color()
	elite_aura_sprite.z_index = -1
	elite_aura_sprite.speed_scale = anim.speed_scale
	add_child(elite_aura_sprite)


func _create_elite_sheen_sprite() -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if elite_type == "blink":
		# Blink elites use glow + particles instead of sheen tint to avoid muddy colors.
		return
	elite_sheen_sprite = AnimatedSprite2D.new()
	elite_sheen_sprite.sprite_frames = anim.sprite_frames
	elite_sheen_sprite.animation = anim.animation
	elite_sheen_sprite.frame = anim.frame
	elite_sheen_sprite.frame_progress = anim.frame_progress
	elite_sheen_sprite.position = anim.position + Vector2(-1.0, -2.0)
	elite_sheen_sprite.scale = anim.scale * 0.98
	var sheen: Color = _get_elite_sheen_color()
	elite_sheen_sprite.modulate = Color(sheen.r, sheen.g, sheen.b, 0.28)
	elite_sheen_sprite.z_index = 2
	elite_sheen_sprite.speed_scale = anim.speed_scale
	add_child(elite_sheen_sprite)


func _create_elite_magic_particles() -> void:
	if elite_type != "blink":
		return
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	elite_magic_particles = CPUParticles2D.new()
	elite_magic_particles.amount = 18
	elite_magic_particles.lifetime = 0.74
	elite_magic_particles.one_shot = false
	elite_magic_particles.explosiveness = 0.08
	elite_magic_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	elite_magic_particles.emission_ring_radius = 11.0
	elite_magic_particles.emission_ring_inner_radius = 4.0
	elite_magic_particles.direction = Vector2(0, -1)
	elite_magic_particles.spread = 180.0
	elite_magic_particles.gravity = Vector2.ZERO
	elite_magic_particles.initial_velocity_min = 6.0
	elite_magic_particles.initial_velocity_max = 14.0
	elite_magic_particles.scale_amount_min = 0.28
	elite_magic_particles.scale_amount_max = 0.54
	elite_magic_particles.color = Color(0.58, 0.32, 0.95, 0.72)
	elite_magic_particles.position = anim.position + Vector2(0.0, 4.0)
	elite_magic_particles.z_index = 1
	add_child(elite_magic_particles)
	elite_magic_particles.emitting = true


func _start_elite_aura_tween() -> void:
	if elite_aura_sprite == null:
		return
	var pulse: Tween = create_tween()
	pulse.set_loops()
	pulse.tween_property(elite_aura_sprite, "modulate:a", ELITE_AURA_ALPHA_MAX, 0.55)
	pulse.parallel().tween_property(elite_aura_sprite, "scale", elite_aura_sprite.scale * 1.04, 0.55)
	pulse.tween_property(elite_aura_sprite, "modulate:a", ELITE_AURA_ALPHA_MIN, 0.55)
	pulse.parallel().tween_property(elite_aura_sprite, "scale", elite_aura_sprite.scale, 0.55)


func _start_elite_sheen_tween() -> void:
	if elite_sheen_sprite == null:
		return
	var sheen_pulse: Tween = create_tween()
	sheen_pulse.set_loops()
	sheen_pulse.tween_property(elite_sheen_sprite, "modulate:a", 0.32, 0.7)
	sheen_pulse.parallel().tween_property(elite_sheen_sprite, "position:x", elite_sheen_sprite.position.x + 0.6, 0.7)
	sheen_pulse.tween_property(elite_sheen_sprite, "modulate:a", 0.22, 0.8)
	sheen_pulse.parallel().tween_property(elite_sheen_sprite, "position:x", elite_sheen_sprite.position.x - 0.6, 0.8)


func _get_contact_damage() -> int:
	return int(round(float(CONTACT_DAMAGE) * elite_damage_multiplier))


func _sync_elite_aura_anim() -> void:
	if elite_aura_sprite == null:
		return
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	elite_aura_sprite.play(anim.animation)
	elite_aura_sprite.frame = anim.frame
	elite_aura_sprite.frame_progress = anim.frame_progress
	elite_aura_sprite.speed_scale = anim.speed_scale
	if elite_sheen_sprite != null:
		elite_sheen_sprite.play(anim.animation)
		elite_sheen_sprite.frame = anim.frame
		elite_sheen_sprite.frame_progress = anim.frame_progress
		elite_sheen_sprite.speed_scale = anim.speed_scale


func _apply_elite_variant_modifiers() -> void:
	match elite_type:
		"brute":
			elite_brute_knockback_resist = 0.35
			elite_damage_multiplier *= 1.15
			current_health = int(round(float(current_health) * 1.35))
			elite_max_health = current_health
			brute_charge_cooldown = randf_range(BRUTE_CHARGE_COOLDOWN_MIN, BRUTE_CHARGE_COOLDOWN_MAX)
		"blink":
			elite_speed_multiplier *= 0.92
			elite_blink_cooldown = randf_range(1.2, 2.4)
		"tank":
			elite_speed_multiplier *= 0.74
			elite_damage_multiplier *= 0.95
			current_health = int(round(float(current_health) * 1.85))
			elite_max_health = current_health
			var anim: AnimatedSprite2D = $AnimatedSprite2D
			anim.scale *= TANK_ELITE_EXTRA_SCALE
		_:
			pass


func _update_elite_ability(direction: Vector2, distance: float) -> void:
	match elite_type:
		"brute":
			_update_brute_charge_logic(direction, distance)
		"blink":
			if elite_blink_cooldown <= 0.0 and distance > CONTACT_RANGE * 1.6:
				var blink_from: Vector2 = global_position
				global_position += direction * elite_blink_distance
				var blink_to: Vector2 = global_position
				_play_blink_teleport_effect(blink_from, blink_to)
				elite_blink_cooldown = elite_blink_cooldown_max
				if elite_aura_sprite != null:
					elite_aura_sprite.modulate.a = ELITE_AURA_ALPHA_MAX
		_:
			pass


func _update_brute_charge_logic(direction: Vector2, _distance: float) -> void:
	if _is_brute_charging():
		return
	if _is_brute_charge_windup():
		return
	if brute_charge_cooldown <= 0.0:
		brute_charge_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
		brute_charge_target_position = target_player.global_position + (brute_charge_direction * BRUTE_CHARGE_OVERSHOOT_DISTANCE)
		brute_charge_windup_timer = BRUTE_CHARGE_WINDUP
		brute_is_charging = false
		brute_is_winding_up = true
		brute_charge_cooldown = randf_range(BRUTE_CHARGE_COOLDOWN_MIN, BRUTE_CHARGE_COOLDOWN_MAX)
		_show_brute_charge_indicator()
		$AnimatedSprite2D.modulate = Color(1.18, 0.78, 0.78, 1.0)


func _show_brute_charge_indicator() -> void:
	if brute_charge_indicator == null:
		brute_charge_indicator = Polygon2D.new()
		brute_charge_indicator.color = Color(1.0, 0.25, 0.25, BRUTE_INDICATOR_BASE_ALPHA)
		brute_charge_indicator.z_index = -2
		add_child(brute_charge_indicator)
	if brute_charge_endpoint_indicator == null:
		brute_charge_endpoint_indicator = Polygon2D.new()
		brute_charge_endpoint_indicator.polygon = _build_circle_polygon(14.0, 14)
		brute_charge_endpoint_indicator.color = Color(1.0, 0.35, 0.35, BRUTE_INDICATOR_BASE_ALPHA + 0.06)
		brute_charge_endpoint_indicator.z_index = -2
		add_child(brute_charge_endpoint_indicator)
	var to_target: Vector2 = brute_charge_target_position - global_position
	var dir: Vector2 = to_target.normalized() if to_target != Vector2.ZERO else brute_charge_direction.normalized()
	var lane_length: float = max(to_target.length(), BRUTE_WINDUP_INDICATOR_LENGTH)
	var right: Vector2 = dir.orthogonal()
	var half_width: float = BRUTE_WINDUP_INDICATOR_WIDTH * 0.5
	var end_half_width: float = half_width * 0.58
	var p1: Vector2 = right * -half_width
	var p2: Vector2 = right * half_width
	var p3: Vector2 = (dir * lane_length) + right * end_half_width
	var p4: Vector2 = (dir * lane_length) + right * -end_half_width
	brute_charge_indicator.polygon = PackedVector2Array([p1, p2, p3, p4])
	brute_charge_indicator.visible = true
	brute_charge_endpoint_indicator.position = dir * lane_length
	brute_charge_endpoint_indicator.visible = true
	_update_brute_charge_indicator_visual()


func _hide_brute_charge_indicator() -> void:
	if brute_charge_indicator != null:
		brute_charge_indicator.visible = false
	if brute_charge_endpoint_indicator != null:
		brute_charge_endpoint_indicator.visible = false


func _update_brute_charge_indicator_visual() -> void:
	if brute_charge_indicator == null or not brute_charge_indicator.visible:
		return
	var progress: float = clamp(1.0 - (brute_charge_windup_timer / max(BRUTE_CHARGE_WINDUP, 0.001)), 0.0, 1.0)
	var pulse_speed: float = lerp(4.0, 40.0, progress)
	var pulse_wave: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed))
	var alpha: float = lerp(BRUTE_INDICATOR_BASE_ALPHA, BRUTE_INDICATOR_PEAK_ALPHA, pulse_wave)
	brute_charge_indicator.modulate.a = alpha
	if brute_charge_endpoint_indicator != null and brute_charge_endpoint_indicator.visible:
		brute_charge_endpoint_indicator.modulate.a = min(alpha + 0.1, 0.45)
		var endpoint_scale: float = lerp(0.88, 1.26, pulse_wave)
		brute_charge_endpoint_indicator.scale = Vector2(endpoint_scale, endpoint_scale)


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _show_brute_rest_indicator() -> void:
	if brute_rest_label == null:
		brute_rest_label = Label.new()
		brute_rest_label.text = "REST"
		brute_rest_label.position = Vector2(-18.0, -40.0)
		brute_rest_label.z_index = 8
		brute_rest_label.modulate = Color(1.0, 0.45, 0.45, 0.95)
		var settings: LabelSettings = LabelSettings.new()
		settings.font = ThemeDB.fallback_font
		settings.font_size = 13
		brute_rest_label.label_settings = settings
		add_child(brute_rest_label)
	brute_rest_label.visible = true


func _hide_brute_rest_indicator() -> void:
	if brute_rest_label != null:
		brute_rest_label.visible = false


func _get_elite_aura_color() -> Color:
	match elite_type:
		"brute":
			return Color(1.0, 0.34, 0.34, 0.45)
		"blink":
			return Color(0.44, 0.22, 0.9, 0.6)
		"tank":
			return Color(0.34, 0.62, 1.0, 0.48)
		_:
			return ELITE_AURA_COLOR


func _get_elite_sheen_color() -> Color:
	match elite_type:
		"brute":
			return Color(1.0, 0.72, 0.5, 1.0)
		"blink":
			return Color(0.72, 0.62, 1.0, 1.0)
		"tank":
			return Color(0.55, 1.0, 0.96, 1.0)
		_:
			return Color(0.9, 0.95, 1.0, 1.0)


func _get_elite_sprite_tint() -> Color:
	match elite_type:
		"blink":
			return Color(0.6, 0.36, 0.9, 1.0)
		_:
			return ELITE_TINT


func _get_base_sprite_modulate() -> Color:
	if not is_elite:
		return Color(1, 1, 1, 1)
	return _get_elite_sprite_tint()


func _on_elite_contact_hit() -> void:
	pass


func _apply_brute_charge_hitbox_damage() -> void:
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	if brute_has_hit_during_charge:
		return
	var to_player: Vector2 = target_player.global_position - global_position
	if to_player.length() > CONTACT_RANGE * 1.2:
		return
	var charge_damage: int = int(round(float(_get_contact_damage()) * BRUTE_CHARGE_DAMAGE_MULTIPLIER))
	target_player.call("receive_damage", charge_damage)
	_play_attack_animation(brute_charge_direction)
	contact_cooldown = BRUTE_CHARGE_CONTACT_COOLDOWN
	brute_has_hit_during_charge = true


func _is_brute_charge_windup() -> bool:
	return elite_type == "brute" and brute_is_winding_up


func _is_brute_charging() -> bool:
	return elite_type == "brute" and brute_is_charging


func _is_brute_recovering() -> bool:
	return elite_type == "brute" and brute_recover_timer > 0.0


func get_debug_snapshot() -> Dictionary:
	var brute_state: String = "none"
	if elite_type == "brute":
		if _is_brute_charging():
			brute_state = "charge"
		elif _is_brute_recovering():
			brute_state = "recover"
		elif _is_brute_charge_windup():
			brute_state = "windup"
		else:
			brute_state = "idle"
	return {
		"is_elite": is_elite,
		"elite_type": elite_type,
		"archetype": get_enemy_archetype(),
		"brute_state": brute_state,
		"hp": current_health
	}


func _spawn_elite_death_effect() -> void:
	# Quick neutral burst so elite kills feel distinct.
	for i in range(12):
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -3),
			Vector2(2, 0),
			Vector2(0, 3),
			Vector2(-2, 0)
		])
		shard.color = Color(0.82, 0.9, 1.0, 0.95)
		shard.position = Vector2.ZERO
		shard.z_index = 8
		add_child(shard)

		var drift: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(28.0, 62.0)
		var tween: Tween = create_tween()
		tween.tween_property(shard, "position", shard.position + drift, 0.32)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.32)
		tween.parallel().tween_property(shard, "scale", Vector2(1.4, 1.4), 0.32)
		tween.tween_callback(shard.queue_free)


func get_enemy_archetype() -> String:
	return "grunt"


func _resolve_elite_type_with_rules(forced_type: String) -> String:
	var allowed: Array[String] = _get_allowed_elite_types_for_archetype()
	if forced_type != "" and allowed.has(forced_type):
		return forced_type
	if allowed.is_empty():
		return ELITE_TYPES[randi() % ELITE_TYPES.size()]
	return allowed[randi() % allowed.size()]


func _get_allowed_elite_types_for_archetype() -> Array[String]:
	var archetype: String = get_enemy_archetype()
	match archetype:
		"mage", "electric_mage":
			# Enforced readability rule: mage elites are Tank-only.
			# (No brute/blink mages.)
			return ["tank"]
		"sword", "grunt":
			return ELITE_TYPES
		_:
			return ELITE_TYPES


func _update_archetype_behavior(_delta: float, _direction: Vector2, _distance: float) -> void:
	pass


func _should_hold_position() -> bool:
	return false


func _disable_contact_damage() -> bool:
	return false


func _get_contact_range() -> float:
	return CONTACT_RANGE


func _get_contact_cooldown() -> float:
	return CONTACT_COOLDOWN_SECONDS


func _has_forced_velocity() -> bool:
	return false


func _get_forced_velocity() -> Vector2:
	return Vector2.ZERO


func _play_blink_teleport_effect(from_pos: Vector2, to_pos: Vector2) -> void:
	# Preferred path: sprite VFX scene (you only need to add frames there).
	if blink_tp_vfx_scene != null:
		_spawn_blink_tp_scene(from_pos)
		_spawn_blink_tp_scene(to_pos)
		return

	# Fallback: procedural bursts if scene fails to load.
	_spawn_blink_burst_at(from_pos, Color(0.72, 0.9, 1.0, 0.52))
	_spawn_blink_burst_at(to_pos, Color(0.86, 0.98, 1.0, 0.66))


func _spawn_blink_tp_scene(world_pos: Vector2) -> void:
	if blink_tp_vfx_scene == null or get_parent() == null:
		return
	var vfx: Node2D = blink_tp_vfx_scene.instantiate() as Node2D
	if vfx == null:
		return
	vfx.global_position = world_pos
	vfx.scale = Vector2(0.14, 0.14)
	vfx.z_index = 7
	get_parent().add_child(vfx)
	if vfx.has_method("play_tp"):
		vfx.call("play_tp")


func _spawn_blink_burst_at(world_pos: Vector2, burst_color: Color) -> void:
	var burst: Polygon2D = Polygon2D.new()
	burst.polygon = _build_circle_polygon(18.0, 16)
	burst.color = burst_color
	burst.global_position = world_pos
	burst.z_index = 5
	get_parent().add_child(burst)

	var burst_tween: Tween = create_tween()
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.16)
	burst_tween.parallel().tween_property(burst, "scale", Vector2(1.7, 1.7), 0.16)
	burst_tween.tween_callback(burst.queue_free)
