extends CharacterBody2D

signal defeated(world_position: Vector2, xp_value: int, xp_tier: String)

@export_category("SFX Wiring")
@export var sfx_enemy_attack: AudioStream
@export var sfx_enemy_hurt: AudioStream
@export var sfx_enemy_die: AudioStream

const BASE_SPEED: float = 34.0
const MAX_HEALTH: int = 30
const CONTACT_DAMAGE: int = 9
const CONTACT_COOLDOWN_SECONDS: float = 0.75
const CONTACT_RANGE: float = 40.0
const XP_REWARD: int = 1
const XP_TIER: String = "blue"
const KNOCKBACK_DECAY: float = 14.0
const HORDE_RUN_SPEED: float = 90.0
const HORDE_DESPAWN_DISTANCE: float = 1250.0
const ATTACK_ANIM_DURATION: float = 0.16
const ELITE_SCALE: float = 1.10
const ELITE_HP_MULTIPLIER: float = 3.0
const ELITE_DAMAGE_MULTIPLIER: float = 1.8
const ELITE_SPEED_MULTIPLIER: float = 0.82
const ELITE_XP_MULTIPLIER: int = 6
const ELITE_TINT: Color = Color(0.95, 0.95, 1.0, 1.0)
const ELITE_AURA_ALPHA_MIN: float = 0.20
const ELITE_AURA_ALPHA_MAX: float = 0.34
const ELITE_AURA_COLOR: Color = Color(0.42, 0.72, 1.0, 0.45)
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
const BRUTE_INDICATOR_PEAK_ALPHA: float = 0.24
const TANK_ELITE_EXTRA_SCALE: float = 1.08
const BLINK_TP_VFX_SCENE_PATH: String = "res://scenes/vfx/BlinkTeleportVfx.tscn"

var current_health: int = MAX_HEALTH
var target_player: Node2D = null
var contact_cooldown: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_horde_runner: bool = false
var horde_direction: Vector2 = Vector2.RIGHT
var horde_swarm_phase: float = 0.0
var horde_swarm_amplitude: float = 0.0
var horde_swarm_frequency: float = 0.0
var horde_despawn_grace_timer: float = 0.0
var external_launch_velocity: Vector2 = Vector2.ZERO
var external_launch_timer: float = 0.0
var external_launch_duration: float = 0.0
var external_launch_height: float = 0.0
var base_sprite_local_y: float = 0.0
var ground_shadow: Polygon2D = null
var attack_anim_timer: float = 0.0
var is_elite: bool = false
## Charger archetype (former brute elite); driven only by dedicated scripts, not roll tables.
var brute_mode: bool = false
## Teleporter archetype (former blink elite).
var blink_mode: bool = false
var elite_speed_multiplier: float = 1.0
var elite_damage_multiplier: float = 1.0
var xp_reward: int = XP_REWARD
var xp_tier: String = XP_TIER
var elite_aura_sprite: AnimatedSprite2D = null
var elite_sheen_sprite: AnimatedSprite2D = null
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
var brute_charge_indicator_fill: Polygon2D = null
var brute_charge_indicator_inner: Polygon2D = null
var brute_charge_indicator_tip: Polygon2D = null
var brute_charge_outline_red: Line2D = null
var brute_rest_label: Label = null
var elite_magic_particles: CPUParticles2D = null
var elite_fx_phase: float = 0.0
var blink_tp_vfx_scene: PackedScene = preload(BLINK_TP_VFX_SCENE_PATH)
@export var brute_charge_start_smoke_vfx_scene: PackedScene
var death_vfx_scene: PackedScene = preload("res://scenes/vfx/DashStartSmokeVfx.tscn")


func _ready() -> void:
	add_to_group("enemies")
	
	# Setup SFX Player
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "EnemySFXPlayer"
	add_child(sfx_player)
	add_to_group("enemy")
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	# Avoid atlas bleed/line artifacts at sprite edges.
	$AnimatedSprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_sprite_local_y = $AnimatedSprite2D.position.y
	_ensure_ground_shadow()
	_update_render_priority()
	_randomize_anim_phase()
	if blink_mode:
		_ensure_blink_archetype_particles()


func _physics_process(delta: float) -> void:
	contact_cooldown = max(contact_cooldown - delta, 0.0)
	if blink_mode:
		elite_blink_cooldown = max(elite_blink_cooldown - delta, 0.0)
	if brute_mode:
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
				$AnimatedSprite2D.modulate = _get_base_sprite_modulate()
				_play_brute_charge_animation(brute_charge_direction)
		if brute_is_charging:
			brute_charge_timer = max(brute_charge_timer - delta, 0.0)
			if brute_charge_timer <= 0.0:
				brute_is_charging = false
				brute_recover_timer = BRUTE_RECOVER_DURATION
				$AnimatedSprite2D.modulate = _get_base_sprite_modulate()
				_show_brute_rest_indicator()
		if brute_recover_timer > 0.0:
			brute_recover_timer = max(brute_recover_timer - delta, 0.0)
			if brute_recover_timer <= 0.0:
				_hide_brute_rest_indicator()
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	external_launch_timer = max(external_launch_timer - delta, 0.0)
	if external_launch_timer > 0.0:
		var launch_progress: float = 1.0 - (external_launch_timer / max(external_launch_duration, 0.001))
		var launch_arc: float = sin(launch_progress * PI)
		$AnimatedSprite2D.position.y = base_sprite_local_y - (external_launch_height * launch_arc)
	else:
		$AnimatedSprite2D.position.y = base_sprite_local_y
	_update_ground_shadow()
	attack_anim_timer = max(attack_anim_timer - delta, 0.0)

	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	if is_horde_runner:
		horde_despawn_grace_timer = max(horde_despawn_grace_timer - delta, 0.0)
		if horde_despawn_grace_timer <= 0.0 and _is_offscreen_from_player():
			queue_free()
			return
		var horde_side: Vector2 = horde_direction.orthogonal()
		var swarm_wave: float = sin((Time.get_ticks_msec() * 0.001 * horde_swarm_frequency) + horde_swarm_phase) * horde_swarm_amplitude
		var horde_velocity: Vector2 = (horde_direction * HORDE_RUN_SPEED * elite_speed_multiplier) + (horde_side * swarm_wave)
		if external_launch_timer > 0.0:
			horde_velocity += external_launch_velocity
			external_launch_velocity = external_launch_velocity.lerp(Vector2.ZERO, 7.0 * delta)
		velocity = horde_velocity + knockback_velocity
		move_and_slide()
		if attack_anim_timer <= 0.0:
			_play_walk_animation(horde_direction)
	var dist_sq: float = global_position.distance_squared_to(target_player.global_position)
	var contact_range_sq: float = _get_contact_range() * _get_contact_range()

	if is_horde_runner:
		horde_despawn_grace_timer = max(horde_despawn_grace_timer - delta, 0.0)
		if horde_despawn_grace_timer <= 0.0 and _is_offscreen_from_player():
			queue_free()
			return
		var horde_side: Vector2 = horde_direction.orthogonal()
		var swarm_wave: float = sin((Time.get_ticks_msec() * 0.001 * horde_swarm_frequency) + horde_swarm_phase) * horde_swarm_amplitude
		var horde_velocity: Vector2 = (horde_direction * HORDE_RUN_SPEED * elite_speed_multiplier) + (horde_side * swarm_wave)
		if external_launch_timer > 0.0:
			horde_velocity += external_launch_velocity
			external_launch_velocity = external_launch_velocity.lerp(Vector2.ZERO, 7.0 * delta)
		velocity = horde_velocity + knockback_velocity
		move_and_slide()
		if attack_anim_timer <= 0.0:
			_play_walk_animation(horde_direction)
		
		if dist_sq > (HORDE_DESPAWN_DISTANCE * HORDE_DESPAWN_DISTANCE):
			queue_free()
			return
		if dist_sq <= contact_range_sq and contact_cooldown <= 0.0 and target_player.has_method("receive_damage"):
			target_player.call("receive_damage", _get_contact_damage())
			if target_player.has_method("apply_launch_force"):
				target_player.call("apply_launch_force", global_position, 300.0, 24.0, 0.22)
			_on_elite_contact_hit()
			_play_attack_animation(horde_direction)
			contact_cooldown = _get_contact_cooldown()
		return

	if _is_brute_charging():
		var dist_to_target_sq: float = global_position.distance_squared_to(brute_charge_target_position)
		if dist_to_target_sq <= (BRUTE_CHARGE_TARGET_REACHED_DISTANCE * BRUTE_CHARGE_TARGET_REACHED_DISTANCE):
			brute_is_charging = false
			brute_recover_timer = BRUTE_RECOVER_DURATION
			$AnimatedSprite2D.modulate = Color(0.95, 0.55, 0.55, 1.0)
		else:
			knockback_velocity = Vector2.ZERO
			global_position += brute_charge_direction * BRUTE_CHARGE_LUNGE_SPEED * delta
			_apply_brute_charge_hitbox_damage()
			if attack_anim_timer <= 0.0:
				_play_brute_charge_animation(brute_charge_direction)
		return

	var distance: float = sqrt(dist_sq)
	var direction: Vector2 = (target_player.global_position - global_position).normalized() if dist_sq > 1.0 else Vector2.ZERO
	_update_archetype_behavior(delta, direction, distance)
	if blink_mode:
		_update_blink_teleport_logic(direction, distance)
	if brute_mode:
		_update_brute_charge_logic(direction, distance)

	var move_direction: Vector2 = direction
	var move_speed_multiplier: float = elite_speed_multiplier
	if _should_hold_position() or _is_brute_charge_windup() or _is_brute_recovering():
		move_direction = Vector2.ZERO
		move_speed_multiplier = 0.0
		knockback_velocity = Vector2.ZERO
	
	velocity = (move_direction * BASE_SPEED * move_speed_multiplier)
	if not (_is_brute_charge_windup() or _is_brute_charging()):
		velocity += knockback_velocity
		
	if velocity.length_squared() > 1.0:
		move_and_slide()
		
	if dist_sq < 360000: # Within 600px
		_update_ground_shadow()
		if attack_anim_timer <= 0.0:
			if is_horde_runner:
				_play_walk_animation(horde_direction)
			else:
				_play_walk_animation(move_direction)
	
	if not _disable_contact_damage() and dist_sq <= contact_range_sq and contact_cooldown <= 0.0 and target_player.has_method("receive_damage"):
		target_player.call("receive_damage", _get_contact_damage())
		_on_elite_contact_hit()
		_play_attack_animation(direction)
		contact_cooldown = _get_contact_cooldown()


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if _is_brute_recovering():
		amount = int(round(float(amount) * BRUTE_RECOVER_DAMAGE_TAKEN_MULTIPLIER))
	current_health = max(current_health - amount, 0)
	_show_hit_feedback(amount)
	_play_sfx(sfx_enemy_hurt)
	if amount >= 15:
		GameState.hit_stop(0.06, 0.02)
	elif amount >= 5:
		GameState.hit_stop(0.03, 0.05)
	if knockback_force > 0.0 and source_position != Vector2.ZERO:
		# Don't let knockback cancel brute windup/charge behavior.
		if not (brute_mode and (_is_brute_charge_windup() or _is_brute_charging())):
			var kb_dir: Vector2 = (global_position - source_position).normalized()
			if kb_dir != Vector2.ZERO:
				knockback_velocity = kb_dir * knockback_force * elite_brute_knockback_resist

	if current_health <= 0:
		if is_elite:
			_spawn_elite_death_effect()
		_spawn_death_vfx()
		_play_sfx(sfx_enemy_die)
		defeated.emit(global_position, xp_reward, xp_tier)
		queue_free()


func _spawn_death_vfx() -> void:
	if death_vfx_scene == null or get_parent() == null:
		return
	var vfx: Node2D = death_vfx_scene.instantiate() as Node2D
	vfx.global_position = global_position
	vfx.scale = Vector2(0.85, 0.85)
	if is_elite:
		vfx.scale *= 1.5
		vfx.modulate = Color(1.2, 1.2, 1.5, 1.0)
	get_parent().add_child(vfx)
	if vfx.has_method("play_smoke"):
		vfx.call("play_smoke")


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


func _play_brute_charge_animation(direction: Vector2) -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if anim == null:
		return
	var suffix: String = "right"
	if abs(direction.x) > abs(direction.y):
		suffix = "right" if direction.x >= 0.0 else "left"
	else:
		suffix = "front" if direction.y >= 0.0 else "back"
	var primary_anim: StringName = StringName("charge_%s" % suffix)
	var fallback_anim: StringName = StringName("brute_charge_%s" % suffix)
	var dash_anim: StringName = StringName("dash_%s" % suffix)
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(primary_anim):
		anim.play(primary_anim)
		_sync_elite_aura_anim()
		return
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(fallback_anim):
		anim.play(fallback_anim)
		_sync_elite_aura_anim()
		return
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(dash_anim):
		anim.play(dash_anim)
		_sync_elite_aura_anim()
		return
	_play_walk_animation(direction)


func _show_hit_feedback(damage: int) -> void:
	$AnimatedSprite2D.modulate = Color(4.4, 4.4, 4.4, 1.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property($AnimatedSprite2D, "modulate", _get_base_sprite_modulate(), 0.2)

	var damage_label: Label = Label.new()
	damage_label.text = str(damage)
	damage_label.modulate = Color(1.0, 0.95, 0.95, 1.0)
	damage_label.position = Vector2(-8, -30)
	var label_settings: LabelSettings = LabelSettings.new()
	label_settings.font = ThemeDB.fallback_font
	label_settings.font_size = 15
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0.0, 0.0, 0.0, 0.96)
	damage_label.label_settings = label_settings
	add_child(damage_label)
	
	var drift_x: float = randf_range(-25.0, 25.0)
	var drift_y: float = randf_range(-45.0, -65.0)
	var dmg_tween: Tween = create_tween()
	dmg_tween.tween_property(damage_label, "position", damage_label.position + Vector2(drift_x, drift_y), 0.32)
	dmg_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.32)
	dmg_tween.parallel().tween_property(damage_label, "scale", Vector2(1.2, 1.2), 0.1)
	dmg_tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.1)
	dmg_tween.tween_callback(damage_label.queue_free)

func _play_attack_animation(direction: Vector2) -> void:
	attack_anim_timer = ATTACK_ANIM_DURATION
	_play_sfx(sfx_enemy_attack)
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
	horde_despawn_grace_timer = 10.0
	# Hordes ignore body collisions with each other to avoid expensive clump stalls,
	# but we keep the shape enabled so projectiles can still hit them.
	collision_layer = 2 # Stay on enemy layer
	collision_mask = 0  # But don't collide with anything
	# Use per-unit lateral wave so they still read as a flowing swarm.
	horde_swarm_phase = randf() * TAU
	horde_swarm_amplitude = randf_range(10.0, 34.0)
	horde_swarm_frequency = randf_range(2.4, 4.6)
	_randomize_anim_phase()


func is_horde_runner_unit() -> bool:
	return is_horde_runner


func _is_offscreen_from_player() -> bool:
	if target_player == null or not is_instance_valid(target_player):
		return true
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var camera: Camera2D = target_player.get_node_or_null("Camera2D") as Camera2D
	var zoom_value: float = camera.zoom.x if camera != null else 1.0
	var half_screen_world: Vector2 = (viewport_size * 0.5) * zoom_value
	var rel: Vector2 = global_position - target_player.global_position
	return abs(rel.x) > half_screen_world.x or abs(rel.y) > half_screen_world.y


func apply_external_knockback(from_world_pos: Vector2, force: float) -> void:
	if from_world_pos == Vector2.ZERO or force <= 0.0:
		return
	var kb_dir: Vector2 = (global_position - from_world_pos).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2.RIGHT.rotated(randf() * TAU)
	knockback_velocity = kb_dir * force


func apply_external_launch(from_world_pos: Vector2, force: float, launch_height: float = 20.0, duration: float = 0.2) -> void:
	if from_world_pos == Vector2.ZERO or force <= 0.0:
		return
	var kb_dir: Vector2 = (global_position - from_world_pos).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2.RIGHT.rotated(randf() * TAU)
	external_launch_velocity = kb_dir * force
	external_launch_duration = max(duration, 0.08)
	external_launch_timer = external_launch_duration
	external_launch_height = max(launch_height, 0.0)
	knockback_velocity = kb_dir * force * 0.45


func _push_nearby_enemies(center: Vector2, radius: float, force: float, launch_height: float = 0.0, launch_duration: float = 0.18) -> void:
	if get_parent() == null:
		return
	for node in get_parent().get_children():
		if node == self:
			continue
		if not (node is CharacterBody2D):
			continue
		var other_enemy: CharacterBody2D = node as CharacterBody2D
		if other_enemy.global_position.distance_to(center) > radius:
			continue
		if launch_height > 0.0 and other_enemy.has_method("apply_external_launch"):
			other_enemy.call("apply_external_launch", center, force, launch_height, launch_duration)
		elif other_enemy.has_method("apply_external_knockback"):
			other_enemy.call("apply_external_knockback", center, force)


func configure_as_elite(progress_ratio: float = 0.0, _unused_legacy_elite_param: String = "") -> void:
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
	anim.modulate = _get_elite_sprite_tint()
	_apply_elite_variant_modifiers()
	_update_render_priority()
	_create_elite_aura_sprite()
	_create_elite_sheen_sprite()
	elite_fx_phase = randf() * TAU
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
	elite_aura_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(elite_aura_sprite)


func _create_elite_sheen_sprite() -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if blink_mode:
		# Blink stalkers use ring particles instead of sheen to keep silhouette readable.
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
	elite_sheen_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(elite_sheen_sprite)


func _ensure_blink_archetype_particles() -> void:
	if not blink_mode or elite_magic_particles != null:
		return
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	elite_magic_particles = CPUParticles2D.new()
	elite_magic_particles.amount = 14
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


func _process(delta: float) -> void:
	if not is_elite:
		return
	elite_fx_phase += delta
	_apply_elite_decor_visuals()


## Aura/sheen track the main AnimatedSprite2D transform every frame (elites + large hobgoblins).
func _apply_elite_decor_visuals() -> void:
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if anim == null:
		return
	if elite_aura_sprite != null:
		var aura_wave: float = 0.5 + 0.5 * sin(elite_fx_phase * 2.85)
		elite_aura_sprite.position = anim.position
		elite_aura_sprite.modulate.a = lerpf(ELITE_AURA_ALPHA_MIN, ELITE_AURA_ALPHA_MAX, aura_wave)
		var aura_scale_mult: float = 1.10 * lerpf(1.0, 1.03, aura_wave)
		elite_aura_sprite.scale = anim.scale * aura_scale_mult
	if elite_sheen_sprite != null:
		var sheen_wave: float = 0.5 + 0.5 * sin(elite_fx_phase * 1.75 + 1.05)
		var wx: float = sin(elite_fx_phase * 3.25) * 0.6
		elite_sheen_sprite.position = anim.position + Vector2(-1.0 + wx, -2.0)
		elite_sheen_sprite.modulate.a = lerpf(0.22, 0.32, sheen_wave)
		elite_sheen_sprite.scale = anim.scale * 0.98
	if elite_magic_particles != null:
		elite_magic_particles.position = anim.position + Vector2(0.0, 4.0)


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
	# All elites use the former "tank" combat footprint: chunky silhouette + aura/sheen + hp.
	elite_speed_multiplier *= 0.74
	elite_damage_multiplier *= 0.95
	current_health = int(round(float(current_health) * 1.85))
	elite_max_health = current_health
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	anim.scale *= TANK_ELITE_EXTRA_SCALE


func _update_blink_teleport_logic(direction: Vector2, distance: float) -> void:
	if elite_blink_cooldown <= 0.0 and distance > CONTACT_RANGE * 1.6:
		var blink_from: Vector2 = global_position
		global_position += direction * elite_blink_distance
		var blink_to: Vector2 = global_position
		_play_blink_teleport_effect(blink_from, blink_to)
		elite_blink_cooldown = elite_blink_cooldown_max
		if elite_aura_sprite != null:
			elite_aura_sprite.modulate.a = ELITE_AURA_ALPHA_MAX


func _update_brute_charge_logic(direction: Vector2, _distance: float) -> void:
	if not brute_mode:
		return
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
		_spawn_brute_charge_start_smoke()
		_show_brute_charge_indicator()
		_play_brute_charge_animation(brute_charge_direction)
		$AnimatedSprite2D.modulate = _get_base_sprite_modulate()


func _show_brute_charge_indicator() -> void:
	if brute_charge_indicator_fill == null:
		brute_charge_indicator_fill = Polygon2D.new()
		brute_charge_indicator_fill.color = Color(0.58, 0.04, 0.04, BRUTE_INDICATOR_BASE_ALPHA)
		brute_charge_indicator_fill.z_index = -2
		add_child(brute_charge_indicator_fill)
	if brute_charge_indicator_inner == null:
		brute_charge_indicator_inner = Polygon2D.new()
		brute_charge_indicator_inner.color = Color(0.74, 0.13, 0.13, BRUTE_INDICATOR_BASE_ALPHA * 0.82)
		brute_charge_indicator_inner.z_index = -2
		add_child(brute_charge_indicator_inner)
	if brute_charge_indicator_tip == null:
		brute_charge_indicator_tip = Polygon2D.new()
		brute_charge_indicator_tip.color = Color(1.0, 0.5, 0.5, BRUTE_INDICATOR_BASE_ALPHA * 0.78)
		brute_charge_indicator_tip.z_index = -2
		add_child(brute_charge_indicator_tip)
	if brute_charge_outline_red == null:
		brute_charge_outline_red = Line2D.new()
		brute_charge_outline_red.width = 1.1
		brute_charge_outline_red.closed = true
		brute_charge_outline_red.default_color = Color(0.58, 0.04, 0.04, 0.78)
		brute_charge_outline_red.joint_mode = Line2D.LINE_JOINT_ROUND
		brute_charge_outline_red.begin_cap_mode = Line2D.LINE_CAP_ROUND
		brute_charge_outline_red.end_cap_mode = Line2D.LINE_CAP_ROUND
		brute_charge_outline_red.z_index = 0
		add_child(brute_charge_outline_red)
	var to_target: Vector2 = brute_charge_target_position - global_position
	var dir: Vector2 = to_target.normalized() if to_target != Vector2.ZERO else brute_charge_direction.normalized()
	var lane_length: float = max(to_target.length(), BRUTE_WINDUP_INDICATOR_LENGTH)
	var right: Vector2 = dir.orthogonal()
	var half_width: float = BRUTE_WINDUP_INDICATOR_WIDTH * 0.5
	var end_half_width: float = half_width * 0.5
	var tip_radius: float = end_half_width + 10.0
	var p1: Vector2 = right * -half_width
	var p2: Vector2 = right * half_width
	var p3: Vector2 = (dir * lane_length) + right * end_half_width
	var p4: Vector2 = (dir * lane_length) + right * -end_half_width
	var tip_center: Vector2 = (dir * lane_length) + (dir * tip_radius * 0.34)
	var fill_poly: PackedVector2Array = PackedVector2Array([p1, p2, p3, p4])
	var inner_half_width: float = half_width * 0.56
	var inner_end_half_width: float = end_half_width * 0.56
	var inner_start_offset: float = 10.0
	var inner_end_offset: float = 8.0
	var ip1: Vector2 = (dir * inner_start_offset) + (right * -inner_half_width)
	var ip2: Vector2 = (dir * inner_start_offset) + (right * inner_half_width)
	var ip3: Vector2 = (dir * (lane_length - inner_end_offset)) + (right * inner_end_half_width)
	var ip4: Vector2 = (dir * (lane_length - inner_end_offset)) + (right * -inner_end_half_width)
	var inner_poly: PackedVector2Array = PackedVector2Array([ip1, ip2, ip3, ip4])
	brute_charge_indicator_fill.polygon = fill_poly
	brute_charge_indicator_inner.polygon = inner_poly
	brute_charge_indicator_tip.polygon = _build_circle_polygon(tip_radius, 18)
	brute_charge_indicator_tip.position = tip_center
	brute_charge_outline_red.points = fill_poly
	brute_charge_indicator_fill.visible = true
	brute_charge_indicator_inner.visible = true
	brute_charge_indicator_tip.visible = true
	brute_charge_outline_red.visible = true
	_update_brute_charge_indicator_visual()


func _hide_brute_charge_indicator() -> void:
	if brute_charge_indicator_fill != null:
		brute_charge_indicator_fill.visible = false
	if brute_charge_indicator_inner != null:
		brute_charge_indicator_inner.visible = false
	if brute_charge_indicator_tip != null:
		brute_charge_indicator_tip.visible = false
	if brute_charge_outline_red != null:
		brute_charge_outline_red.visible = false


func _update_brute_charge_indicator_visual() -> void:
	if brute_charge_indicator_fill == null or not brute_charge_indicator_fill.visible:
		return
	var progress: float = clamp(1.0 - (brute_charge_windup_timer / max(BRUTE_CHARGE_WINDUP, 0.001)), 0.0, 1.0)
	var pulse_speed: float = lerp(4.0, 40.0, progress)
	pulse_speed = lerp(2.0, 8.0, progress)
	var pulse_wave: float = 0.5 + (0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed))
	var alpha: float = lerp(BRUTE_INDICATOR_BASE_ALPHA, BRUTE_INDICATOR_PEAK_ALPHA, pulse_wave)
	var inner_alpha: float = min(alpha * 0.9, 0.6)
	if brute_charge_indicator_fill != null:
		brute_charge_indicator_fill.modulate.a = alpha
	if brute_charge_indicator_inner != null:
		brute_charge_indicator_inner.modulate.a = inner_alpha
	if brute_charge_indicator_tip != null:
		brute_charge_indicator_tip.modulate.a = alpha
	if brute_charge_outline_red != null:
		brute_charge_outline_red.default_color = Color(0.58, 0.04, 0.04, clamp(alpha + 0.2, 0.16, 0.82))


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _ensure_ground_shadow() -> void:
	if ground_shadow != null:
		return
	ground_shadow = Polygon2D.new()
	ground_shadow.polygon = _build_circle_polygon(9.5, 12)
	ground_shadow.color = Color(0.0, 0.0, 0.0, 0.46)
	ground_shadow.position = Vector2(0.0, 11.0)
	ground_shadow.scale = Vector2(1.28, 0.52)
	ground_shadow.show_behind_parent = true
	ground_shadow.z_index = 0
	add_child(ground_shadow)


func _update_ground_shadow() -> void:
	if ground_shadow == null:
		return
	var sprite_node: AnimatedSprite2D = $AnimatedSprite2D
	if sprite_node == null:
		return
	var air_offset: float = max(base_sprite_local_y - sprite_node.position.y, 0.0)
	var arc: float = clamp(air_offset / max(external_launch_height, 1.0), 0.0, 1.0)
	var sprite_scale_factor: float = max(abs(sprite_node.scale.x), abs(sprite_node.scale.y))
	sprite_scale_factor = clamp(sprite_scale_factor, 0.85, 3.0)
	var archetype: String = get_enemy_archetype()
	var big_unit_bonus: float = max(sprite_scale_factor - 1.0, 0.0)
	var extra_y: float = 0.0
	var width_mult: float = 1.0
	var alpha_boost: float = 0.0
	var base_y: float = 13.0
	if archetype == "hobgoblin":
		# Hobgoblin is tall/wide, so push shadow farther down and wider.
		base_y = 35.0
		extra_y += 10.0
		width_mult = 1.76
		alpha_boost = 0.16
	elif big_unit_bonus > 0.0:
		extra_y += big_unit_bonus * 5.0
		width_mult = 1.0 + (big_unit_bonus * 0.2)
		alpha_boost = min(big_unit_bonus * 0.05, 0.06)
	ground_shadow.position = Vector2(0.0, base_y + extra_y)
	var base_scale: Vector2 = Vector2(lerp(1.28, 0.82, arc), lerp(0.52, 0.32, arc))
	base_scale.x *= width_mult
	ground_shadow.scale = base_scale * sprite_scale_factor
	ground_shadow.modulate.a = clamp(lerp(0.46, 0.2, arc) + alpha_boost, 0.18, 0.72)


func _cleanup_runtime_indicators() -> void:
	if brute_charge_indicator_fill != null:
		brute_charge_indicator_fill.queue_free()
		brute_charge_indicator_fill = null
	if brute_charge_indicator_inner != null:
		brute_charge_indicator_inner.queue_free()
		brute_charge_indicator_inner = null
	if brute_charge_indicator_tip != null:
		brute_charge_indicator_tip.queue_free()
		brute_charge_indicator_tip = null
	if brute_charge_outline_red != null:
		brute_charge_outline_red.queue_free()
		brute_charge_outline_red = null
	if brute_rest_label != null:
		brute_rest_label.queue_free()
		brute_rest_label = null


func _exit_tree() -> void:
	_cleanup_runtime_indicators()


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
	return ELITE_AURA_COLOR


func _get_elite_sheen_color() -> Color:
	return Color(0.55, 1.0, 0.96, 1.0)


func _get_elite_sprite_tint() -> Color:
	return ELITE_TINT


func _get_base_sprite_modulate() -> Color:
	if not is_elite:
		return Color(1, 1, 1, 1)
	return _get_elite_sprite_tint()


func _on_elite_contact_hit() -> void:
	pass


func _apply_brute_charge_hitbox_damage() -> void:
	_push_nearby_enemies(global_position, CONTACT_RANGE * 1.7, 280.0, 24.0, 0.2)
	if target_player == null or not is_instance_valid(target_player) or not target_player.has_method("receive_damage"):
		return
	if brute_has_hit_during_charge:
		return
	var to_player: Vector2 = target_player.global_position - global_position
	if to_player.length() > CONTACT_RANGE * 1.2:
		return
	var charge_damage: int = int(round(float(_get_contact_damage()) * BRUTE_CHARGE_DAMAGE_MULTIPLIER))
	target_player.call("receive_damage", charge_damage)
	if target_player.has_method("apply_launch_force"):
		target_player.call("apply_launch_force", global_position, 420.0, 32.0, 0.28)
	_push_nearby_enemies(global_position, CONTACT_RANGE * 1.7, 340.0, 30.0, 0.24)
	_play_attack_animation(brute_charge_direction)
	contact_cooldown = BRUTE_CHARGE_CONTACT_COOLDOWN
	brute_has_hit_during_charge = true


func _is_brute_charge_windup() -> bool:
	return brute_mode and brute_is_winding_up


func _is_brute_charging() -> bool:
	return brute_mode and brute_is_charging


func _is_brute_recovering() -> bool:
	return brute_mode and brute_recover_timer > 0.0


func get_debug_snapshot() -> Dictionary:
	var brute_state: String = "none"
	if brute_mode:
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
		"brute_mode": brute_mode,
		"blink_mode": blink_mode,
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


func _update_render_priority() -> void:
	var archetype: String = get_enemy_archetype()
	var base_priority: int = 0
	match archetype:
		"grunt":
			base_priority = 0
		"sword":
			base_priority = 1
		"mage", "electric_mage":
			base_priority = 2
		"hobgoblin":
			base_priority = 3
		"king_goblin":
			base_priority = 5
		_:
			base_priority = 1
	if is_elite:
		base_priority += 3
	z_index = base_priority


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


func _spawn_brute_charge_start_smoke() -> void:
	var smoke_pos: Vector2 = global_position + Vector2(0.0, 6.0)
	_spawn_world_vfx_scene(brute_charge_start_smoke_vfx_scene, smoke_pos, 4, Vector2(0.9, 0.9))


func _spawn_world_vfx_scene(scene: PackedScene, world_pos: Vector2, vfx_z: int = 0, vfx_scale: Vector2 = Vector2.ONE) -> Node2D:
	if scene == null or get_parent() == null:
		return null
	var vfx: Node2D = scene.instantiate() as Node2D
	if vfx == null:
		return null
	vfx.global_position = world_pos
	vfx.z_index = vfx_z
	vfx.scale = vfx_scale
	get_parent().add_child(vfx)
	if vfx.has_method("play_smoke"):
		vfx.call("play_smoke")
	if vfx is AnimatedSprite2D:
		(vfx as AnimatedSprite2D).play()
	return vfx


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player = get_node_or_null("EnemySFXPlayer") as AudioStreamPlayer
	if player != null:
		player.stream = stream
		player.volume_db = -15.0
		player.play()
