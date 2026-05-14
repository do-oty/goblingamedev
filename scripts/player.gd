extends CharacterBody2D

signal health_changed(current: int, max_health: int)
signal died

@export_category("SFX Wiring")
@export var sfx_attack: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream
@export var sfx_level_up: AudioStream
@export var sfx_pickup: AudioStream

const ATTACK_RANGE: float = 160.0
const INVULNERABILITY_SECONDS: float = 0.45
const AIM_DEADZONE: float = 8.0
const SWORD_KNOCKBACK: float = 95.0
const CURSOR_ATTACK_OFFSET: float = 92.0
const USE_SPRITE_SLASH_VFX: bool = true
const SWORD_CONE_ANGLE_DEGREES: float = 120.0
const SWORD_CLOSE_HIT_RADIUS: float = 34.0
const SLASH_VFX_MIN_SCALE: float = 0.95
const SLASH_VFX_MAX_SCALE: float = 1.55
const DASH_BASE_COOLDOWN: float = 3.2
const DASH_BASE_DURATION: float = 0.16
const DASH_BASE_DISTANCE: float = 165.0
const DASH_IFRAME_BASE: float = 0.18
const DASH_BLUR_SPAWN_INTERVAL: float = 0.035
const DASH_INPUT_BUFFER_WINDOW: float = 0.2
const DASH_SMUDGE_FRAME_HOLD_RATIO: float = 0.72
signal sword_level_changed(level: int, max_level: int)

var last_direction := Vector2.DOWN
var is_attacking := false
var current_health: int = 100
var attack_cooldown: float = 0.0
var invulnerability_cooldown: float = 0.0
var move_speed: float = 150.0
var max_health: int = 100
var pickup_radius: float = 24.0
var magnet_range: float = 90.0
var magnet_strength: float = 220.0
var luck: float = 0.0
var character_data: Dictionary = {}
var sword_level: int = 1
var sword_damage: int = 12
var sword_aoe_radius: float = 80.0
var sword_cooldown: float = 0.65
var sword_max_level: int = 8
var sword_item_data: Dictionary = {}
var talent_damage_multiplier: float = 1.0
var talent_aoe_multiplier: float = 1.0
var talent_attack_speed_multiplier: float = 1.0
var extra_slash_count: int = 0
var talent_extra_slash_count: int = 0
var dash_cooldown_multiplier: float = 1.0
var dash_iframe_bonus: float = 0.0
var dash_distance_bonus: float = 0.0
var dash_cooldown_remaining: float = 0.0
var dash_duration_remaining: float = 0.0
var dash_iframe_remaining: float = 0.0
var dash_blur_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_buffer_remaining: float = 0.0
## When true, a directional `dash_*` clip from SpriteFrames is driving the dash (ghost trail throttled).
var dash_uses_directional_anim: bool = false
var dash_directional_anim_name: StringName = &""
var dash_directional_anim_frame_count: int = 0
var lobby_mode: bool = false
var has_magnet_pulse: bool = false
var magnet_pulse_cooldown: float = 0.0
var bow_level: int = 0
var wand_level: int = 0
var wand_cooldown_timer: float = 0.0
var bow_cooldown_timer: float = 0.0
var launch_velocity: Vector2 = Vector2.ZERO
var launch_timer: float = 0.0
var launch_duration: float = 0.0
var launch_height: float = 0.0
var ground_shadow: Polygon2D = null
var sword_slash_sprite_vfx_scene: PackedScene = preload("res://scenes/vfx/SwordSlashSpriteVfx.tscn")
@export var dash_start_smoke_vfx_scene: PackedScene
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	
	# Setup SFX Player
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "PlayerSFXPlayer"
	add_child(sfx_player)
	_load_character_stats("knight")
	sword_item_data = ItemCatalog.get_item_by_id("sword_slash")
	sword_max_level = sword_item_data.get("max_level", 8)
	_apply_sword_level_stats(sword_level)
	_ensure_ground_shadow()
	
func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	wand_cooldown_timer = max(wand_cooldown_timer - delta, 0.0)
	invulnerability_cooldown = max(invulnerability_cooldown - delta, 0.0)
	dash_cooldown_remaining = max(dash_cooldown_remaining - delta, 0.0)
	dash_iframe_remaining = max(dash_iframe_remaining - delta, 0.0)
	dash_buffer_remaining = max(dash_buffer_remaining - delta, 0.0)
	launch_timer = max(launch_timer - delta, 0.0)
	
	if has_magnet_pulse:
		magnet_pulse_cooldown -= delta
		if magnet_pulse_cooldown <= 0:
			_trigger_magnet_pulse()
			magnet_pulse_cooldown = 4.5
	
	if bow_level > 0:
		bow_cooldown_timer -= delta
		if bow_cooldown_timer <= 0:
			_fire_bow()
			bow_cooldown_timer = _get_bow_cooldown()
			
	if wand_level > 0 and wand_cooldown_timer <= 0:
		_fire_wand()

	_update_aim_from_cursor()

	# Allow movement at all times, including while attacking.
	direction.x = Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left")
	direction.y = Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up")

	if Input.is_action_just_pressed("dash"):
		dash_buffer_remaining = DASH_INPUT_BUFFER_WINDOW

	if dash_buffer_remaining > 0.0:
		if _try_start_dash(direction):
			dash_buffer_remaining = 0.0

	if is_dashing:
		dash_duration_remaining = max(dash_duration_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		global_position += dash_direction * _get_dash_speed() * delta
		if dash_uses_directional_anim:
			_update_dash_directional_anim_progress()
		_spawn_dash_blur_if_needed(delta)
		if dash_duration_remaining <= 0.0:
			is_dashing = false
			dash_direction = Vector2.ZERO
			if dash_uses_directional_anim and not is_attacking:
				play_idle_animation()
			dash_uses_directional_anim = false
			dash_directional_anim_name = &""
			dash_directional_anim_frame_count = 0
			if body_collision != null:
				body_collision.set_deferred("disabled", false)
			_show_dash_rematerialize()
	elif launch_timer > 0.0:
		var launch_progress: float = 1.0 - (launch_timer / max(launch_duration, 0.001))
		var launch_arc: float = sin(launch_progress * PI)
		if body_sprite != null:
			body_sprite.position.y = -launch_height * launch_arc
		velocity = launch_velocity
		launch_velocity = launch_velocity.lerp(Vector2.ZERO, 7.5 * delta)
	elif direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * move_speed
		if not is_attacking:
			play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			play_idle_animation()

	if not is_dashing and body_collision != null and body_collision.disabled:
		body_collision.set_deferred("disabled", false)
	if launch_timer <= 0.0 and body_sprite != null:
		body_sprite.position.y = 0.0
	_update_ground_shadow()

	if not lobby_mode and attack_cooldown <= 0.0 and not is_attacking:
		_try_auto_attack()

	move_and_slide()

# -------------------------
# ANIMATIONS
# -------------------------

func play_walk_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			$AnimatedSprite2D.play("hero_right")
		else:
			$AnimatedSprite2D.play("hero_left")
	else:
		if direction.y > 0:
			$AnimatedSprite2D.play("hero_front")
		else:
			$AnimatedSprite2D.play("hero_back")

func play_idle_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			$AnimatedSprite2D.play("idle_right")
		else:
			$AnimatedSprite2D.play("idle_left")
	else:
		if last_direction.y > 0:
			$AnimatedSprite2D.play("idle_front")
		else:
			$AnimatedSprite2D.play("idle_back")

# -------------------------
# ATTACK SYSTEM
# -------------------------

func start_attack():
	is_attacking = true
	_play_sfx(sfx_attack)
	dash_uses_directional_anim = false
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			$AnimatedSprite2D.play("attack_right")
		else:
			$AnimatedSprite2D.play("attack_left")
	else:
		if last_direction.y > 0:
			$AnimatedSprite2D.play("attack_front")
		else:
			$AnimatedSprite2D.play("attack_back")

	_spawn_slash_effect()

# This function should be called when attack animation finishes
func _on_AnimatedSprite2D_animation_finished():
	var cur: StringName = $AnimatedSprite2D.animation
	if String(cur).begins_with("dash_"):
		return
	if is_attacking:
		is_attacking = false
		play_idle_animation()


# Godot can generate either snake_case or PascalCase signal callback names.
func _on_animated_sprite_2d_animation_finished() -> void:
	_on_AnimatedSprite2D_animation_finished()


func receive_damage(amount: int) -> void:
	if invulnerability_cooldown > 0.0 or dash_iframe_remaining > 0.0 or current_health <= 0:
		return

	# If dash is being held while swarmed, keep a short request alive.
	if Input.is_action_pressed("dash"):
		dash_buffer_remaining = max(dash_buffer_remaining, DASH_INPUT_BUFFER_WINDOW)

	current_health = max(current_health - amount, 0)
	_play_sfx(sfx_hurt)
	invulnerability_cooldown = INVULNERABILITY_SECONDS
	_show_player_hit_feedback()
	GameState.hit_stop(0.12, 0.01)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()


func apply_launch_force(from_world_pos: Vector2, push_strength: float = 280.0, air_height: float = 26.0, duration: float = 0.24) -> void:
	if current_health <= 0 or is_dashing:
		return
	var away: Vector2 = (global_position - from_world_pos).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	launch_velocity = away * max(push_strength, 0.0)
	launch_duration = max(duration, 0.08)
	launch_timer = launch_duration
	launch_height = max(air_height, 0.0)


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func _try_auto_attack() -> void:
	if last_direction == Vector2.ZERO:
		last_direction = Vector2.RIGHT

	start_attack()
	attack_cooldown = sword_cooldown
	var slash_origin: Vector2 = global_position + (last_direction * (CURSOR_ATTACK_OFFSET * 0.45))
	var attack_directions: Array[Vector2] = _get_slash_attack_directions()
	for dir in attack_directions:
		_apply_sword_cone_damage(slash_origin, dir)


func _update_aim_from_cursor() -> void:
	var mouse_world_position: Vector2 = get_global_mouse_position()
	var aim_vector: Vector2 = mouse_world_position - global_position
	if aim_vector.length() >= AIM_DEADZONE:
		last_direction = aim_vector.normalized()


func _spawn_slash_effect() -> void:
	if USE_SPRITE_SLASH_VFX and sword_slash_sprite_vfx_scene != null:
		var base_scale_multiplier: float = max(sword_aoe_radius / 92.0, SLASH_VFX_MIN_SCALE)
		_spawn_single_slash_vfx(0.0, 0.75, base_scale_multiplier)
		if extra_slash_count >= 1:
			_spawn_single_slash_vfx(deg_to_rad(-12.0), 0.73, base_scale_multiplier * 0.94)
		if extra_slash_count >= 2:
			_spawn_single_slash_vfx(deg_to_rad(12.0), 0.77, base_scale_multiplier * 0.94)
		return

	# Fallback procedural arc if sprite VFX is disabled or fails to load.
	var slash := Polygon2D.new()
	slash.polygon = _build_arc_polygon(sword_aoe_radius * 0.55, sword_aoe_radius, deg_to_rad(120.0), 18)
	slash.color = Color(0.95, 0.95, 1.0, 0.9)
	slash.rotation = last_direction.angle()
	add_child(slash)

	var tween: Tween = create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.11)
	tween.parallel().tween_property(slash, "scale", Vector2(1.2, 1.2), 0.11)
	tween.tween_callback(slash.queue_free)


func _spawn_single_slash_vfx(angle_offset: float, offset_factor: float, scale_multiplier: float) -> void:
	var slash_vfx: Node2D = sword_slash_sprite_vfx_scene.instantiate() as Node2D
	if slash_vfx == null:
		return
	var facing_angle: float = last_direction.angle() + angle_offset
	var forward_dir: Vector2 = Vector2.RIGHT.rotated(facing_angle)
	slash_vfx.position = forward_dir * (CURSOR_ATTACK_OFFSET * offset_factor)
	slash_vfx.z_index = 30
	add_child(slash_vfx)
	if slash_vfx.has_method("play_slash"):
		slash_vfx.call("play_slash", max(scale_multiplier, SLASH_VFX_MIN_SCALE), facing_angle)


func can_upgrade_sword() -> bool:
	return sword_level < sword_max_level


func upgrade_sword() -> void:
	if not can_upgrade_sword():
		return

	sword_level += 1
	_apply_sword_level_stats(sword_level)


func _apply_sword_level_stats(level: int) -> void:
	var stats_by_level: Array = sword_item_data.get("stats_by_level", [])
	if stats_by_level.is_empty():
		return

	var idx: int = clamp(level - 1, 0, stats_by_level.size() - 1)
	var stats: Dictionary = stats_by_level[idx]
	var base_damage: int = int(stats.get("damage", 12))
	var base_aoe_radius: float = float(stats.get("aoe_radius", 80.0))
	var base_cooldown: float = float(stats.get("cooldown", 0.65))

	sword_damage = int(round(base_damage * talent_damage_multiplier))
	sword_aoe_radius = base_aoe_radius * talent_aoe_multiplier
	sword_cooldown = base_cooldown / max(talent_attack_speed_multiplier, 0.01)
	_recompute_extra_slashes()
	sword_level_changed.emit(sword_level, sword_max_level)


func _apply_sword_cone_damage(cone_origin: Vector2, attack_direction: Vector2) -> void:
	var half_cone_radians: float = deg_to_rad(SWORD_CONE_ANGLE_DEGREES * 0.5)
	var effective_range: float = sword_aoe_radius * 1.18
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		if not (enemy_node is Node2D):
			continue
		if not enemy_node.has_method("take_damage"):
			continue

		var enemy_2d: Node2D = enemy_node as Node2D
		var to_enemy_from_player: Vector2 = enemy_2d.global_position - global_position
		if to_enemy_from_player.length() <= SWORD_CLOSE_HIT_RADIUS:
			enemy_node.call("take_damage", sword_damage, global_position, SWORD_KNOCKBACK)
			continue

		var to_enemy: Vector2 = enemy_2d.global_position - cone_origin
		var distance: float = to_enemy.length()
		if distance > effective_range or distance <= 0.001:
			continue

		var angle_to_enemy: float = attack_direction.angle_to(to_enemy.normalized())
		if abs(angle_to_enemy) <= half_cone_radians:
			enemy_node.call("take_damage", sword_damage, global_position, SWORD_KNOCKBACK)


func _build_arc_polygon(inner_radius: float, outer_radius: float, arc_angle_radians: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half_arc: float = arc_angle_radians * 0.5

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerp(-half_arc, half_arc, t)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)

	for j in range(segments, -1, -1):
		var t_inner: float = float(j) / float(segments)
		var angle_inner: float = lerp(-half_arc, half_arc, t_inner)
		points.append(Vector2(cos(angle_inner), sin(angle_inner)) * inner_radius)

	return points


func _spawn_slash_hit_indicator(origin_position: Vector2, attack_direction: Vector2) -> void:
	# Ground indicator to show exactly where slash AOE is applied.
	var indicator := Polygon2D.new()
	indicator.polygon = _build_arc_polygon(
		0.0,
		sword_aoe_radius,
		deg_to_rad(SWORD_CONE_ANGLE_DEGREES),
		20
	)
	indicator.color = Color(1.0, 0.22, 0.22, 0.3)
	indicator.global_position = origin_position
	indicator.rotation = attack_direction.angle()
	indicator.z_index = -1
	get_parent().add_child(indicator)

	var tween: Tween = create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(indicator, "scale", Vector2(1.05, 1.05), 0.16)
	tween.tween_callback(indicator.queue_free)


func apply_talent_effects(damage_mult: float, aoe_mult: float, attack_speed_mult: float) -> void:
	talent_damage_multiplier *= damage_mult
	talent_aoe_multiplier *= aoe_mult
	talent_attack_speed_multiplier *= attack_speed_mult
	_apply_sword_level_stats(sword_level)


func debug_increase_sword_aoe(amount: float = 12.0) -> void:
	sword_aoe_radius += max(amount, 1.0)


func add_multi_slash(count: int = 1) -> void:
	talent_extra_slash_count = clamp(talent_extra_slash_count + count, 0, 2)
	_recompute_extra_slashes()


func _get_slash_attack_directions() -> Array[Vector2]:
	var dirs: Array[Vector2] = [last_direction.normalized()]
	if extra_slash_count >= 1:
		dirs.append(last_direction.rotated(deg_to_rad(-12.0)).normalized())
	if extra_slash_count >= 2:
		dirs.append(last_direction.rotated(deg_to_rad(12.0)).normalized())
	return dirs


func _recompute_extra_slashes() -> void:
	# Weapon dupes unlock special slash milestones:
	# Lv5 => +1 angled slash, Lv8 => +2 angled slashes.
	var milestone_slashes: int = 0
	if sword_level >= 8:
		milestone_slashes = 2
	elif sword_level >= 5:
		milestone_slashes = 1
	extra_slash_count = clamp(max(milestone_slashes, talent_extra_slash_count), 0, 2)


func get_pickup_radius() -> float:
	return pickup_radius


func get_magnet_range() -> float:
	return magnet_range


func get_magnet_strength() -> float:
	return magnet_strength


func get_luck() -> float:
	return luck


func add_screen_shake(amplitude: float = 10.0, duration: float = 0.18) -> void:
	var camera: Camera2D = $Camera2D
	if camera == null:
		return
	var base_offset: Vector2 = camera.offset
	camera.offset = base_offset + Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(camera, "offset", base_offset, max(duration, 0.01))


func _load_character_stats(character_id: String) -> void:
	character_data = CharacterCatalog.get_character(character_id)
	var base_stats: Dictionary = character_data.get("base_stats", {})
	var permanent_bonus: Dictionary = character_data.get("permanent_bonus", {})
	var global_bonus: Dictionary = GameState.get_total_permanent_bonus()

	move_speed = float(base_stats.get("move_speed", 150.0)) + float(permanent_bonus.get("move_speed", 0.0)) + float(global_bonus.get("move_speed", 0.0))
	max_health = int(base_stats.get("max_health", 100)) + int(permanent_bonus.get("max_health", 0)) + int(global_bonus.get("max_health", 0))
	pickup_radius = float(base_stats.get("pickup_radius", 24.0)) + float(permanent_bonus.get("pickup_radius", 0.0))
	magnet_range = float(base_stats.get("magnet_range", 90.0)) + float(permanent_bonus.get("magnet_range", 0.0))
	magnet_strength = float(base_stats.get("magnet_strength", 220.0)) + float(permanent_bonus.get("magnet_strength", 0.0))
	luck = float(base_stats.get("luck", 0.0)) + float(permanent_bonus.get("luck", 0.0)) + float(global_bonus.get("luck", 0.0))
	dash_cooldown_multiplier *= max(0.25, 1.0 - (float(permanent_bonus.get("dash_cooldown_reduction", 0.0)) + float(global_bonus.get("dash_cooldown_reduction", 0.0))))
	dash_iframe_bonus += float(permanent_bonus.get("dash_iframe_bonus", 0.0))
	dash_distance_bonus += float(permanent_bonus.get("dash_distance_bonus", 0.0))
	current_health = max_health


func _show_player_hit_feedback() -> void:
	$AnimatedSprite2D.modulate = Color(5.0, 0.45, 0.45, 1.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property($AnimatedSprite2D, "modulate", Color(1, 1, 1, 1), 0.24)

	add_screen_shake(18.0, 0.22)

	# Quick blood-like droplets to make collision hits feel impactful.
	for i in range(8):
		var droplet: Polygon2D = Polygon2D.new()
		droplet.polygon = PackedVector2Array([
			Vector2(0, -3),
			Vector2(3, 0),
			Vector2(0, 3),
			Vector2(-3, 0)
		])
		droplet.color = Color(0.85, 0.08, 0.08, 0.85)
		droplet.position = Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 3.0))
		add_child(droplet)

		var drift: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 34.0)
		var bleed_tween: Tween = create_tween()
		bleed_tween.tween_property(droplet, "position", droplet.position + drift, 0.28)
		bleed_tween.parallel().tween_property(droplet, "modulate:a", 0.0, 0.28)
		bleed_tween.tween_callback(droplet.queue_free)


func _try_start_dash(move_input_direction: Vector2) -> bool:
	if is_dashing or dash_cooldown_remaining > 0.0:
		return false

	var desired_direction: Vector2 = move_input_direction.normalized()
	if desired_direction == Vector2.ZERO:
		desired_direction = last_direction.normalized()
	if desired_direction == Vector2.ZERO:
		desired_direction = Vector2.RIGHT

	dash_direction = desired_direction
	# Cancel an in-flight melee state so looping dash clips cannot strand `is_attacking`.
	if is_attacking:
		is_attacking = false
	is_dashing = true
	_play_sfx(sfx_dash)
	dash_duration_remaining = DASH_BASE_DURATION
	dash_iframe_remaining = max(0.01, DASH_IFRAME_BASE + dash_iframe_bonus)
	dash_blur_timer = 0.0
	dash_cooldown_remaining = _get_dash_cooldown()
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	_spawn_dash_start_smoke()
	dash_uses_directional_anim = _try_play_dash_directional_anim(dash_direction)
	if not dash_uses_directional_anim:
		_spawn_dash_blur()
	return true


func _get_dash_cooldown() -> float:
	return DASH_BASE_COOLDOWN * max(0.25, dash_cooldown_multiplier)


func _get_dash_speed() -> float:
	var dash_distance: float = DASH_BASE_DISTANCE + dash_distance_bonus
	return max(120.0, dash_distance / max(DASH_BASE_DURATION, 0.01))


func _spawn_dash_blur_if_needed(delta: float) -> void:
	if dash_uses_directional_anim:
		return
	dash_blur_timer -= delta
	if dash_blur_timer > 0.0:
		return
	dash_blur_timer = DASH_BLUR_SPAWN_INTERVAL
	_spawn_dash_blur()


func _try_play_dash_directional_anim(direction: Vector2) -> bool:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return false
	var anim_name: StringName = _dash_animation_name_for_direction(direction)
	if not body_sprite.sprite_frames.has_animation(anim_name):
		return false
	dash_directional_anim_name = anim_name
	dash_directional_anim_frame_count = body_sprite.sprite_frames.get_frame_count(anim_name)
	body_sprite.play(anim_name)
	return true


func _dash_animation_name_for_direction(direction: Vector2) -> StringName:
	var dir: Vector2 = direction
	if dir == Vector2.ZERO:
		dir = last_direction
	if abs(dir.x) > abs(dir.y):
		return &"dash_right" if dir.x > 0.0 else &"dash_left"
	return &"dash_front" if dir.y > 0.0 else &"dash_back"


func _update_dash_directional_anim_progress() -> void:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return
	if dash_directional_anim_name == &"" or dash_directional_anim_frame_count <= 0:
		return
	if body_sprite.animation != dash_directional_anim_name:
		body_sprite.play(dash_directional_anim_name)
	var duration_total: float = max(DASH_BASE_DURATION, 0.001)
	var elapsed_ratio: float = clamp(1.0 - (dash_duration_remaining / duration_total), 0.0, 1.0)
	# Reach the last frame early and hold it so the smudge reads clearly.
	var held_ratio: float = clamp(elapsed_ratio / max(DASH_SMUDGE_FRAME_HOLD_RATIO, 0.05), 0.0, 1.0)
	var target_frame: int = int(round(held_ratio * float(max(dash_directional_anim_frame_count - 1, 0))))
	body_sprite.frame = clamp(target_frame, 0, max(dash_directional_anim_frame_count - 1, 0))
	body_sprite.frame_progress = 0.0


func _spawn_dash_blur() -> void:
	var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return

	var texture: Texture2D = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if texture == null:
		return

	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = texture
	ghost.global_position = anim_sprite.global_position
	ghost.rotation = anim_sprite.global_rotation
	ghost.scale = anim_sprite.global_scale
	ghost.flip_h = anim_sprite.flip_h
	ghost.flip_v = anim_sprite.flip_v
	ghost.modulate = Color(0.82, 0.94, 1.0, 0.58)
	# Keep dash trail readable above world actors/effects on map scenes.
	ghost.z_as_relative = false
	ghost.z_index = 45
	get_parent().add_child(ghost)

	var ghost_tween: Tween = create_tween()
	ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	ghost_tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.9, 0.2)
	ghost_tween.tween_callback(ghost.queue_free)


func _spawn_dash_start_smoke() -> void:
	if dash_start_smoke_vfx_scene == null or get_parent() == null:
		return
	var smoke: Node2D = dash_start_smoke_vfx_scene.instantiate() as Node2D
	if smoke == null:
		return
	smoke.global_position = global_position + Vector2(0.0, 6.0)
	smoke.z_index = 42
	smoke.scale = Vector2(0.72, 0.72)
	get_parent().add_child(smoke)
	if smoke.has_method("play_smoke"):
		smoke.call("play_smoke")
	if smoke is AnimatedSprite2D:
		(smoke as AnimatedSprite2D).play()


func _show_dash_rematerialize() -> void:
	var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
	if anim_sprite == null:
		return

	anim_sprite.modulate = Color(1.45, 1.45, 1.55, 1.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_remaining


func get_dash_cooldown_total() -> float:
	return _get_dash_cooldown()


func get_dash_iframe_time() -> float:
	return max(0.01, DASH_IFRAME_BASE + dash_iframe_bonus)


func apply_dash_talent(cooldown_reduction: float, iframe_bonus: float, distance_bonus: float) -> void:
	dash_cooldown_multiplier *= max(0.25, 1.0 - cooldown_reduction)
	dash_iframe_bonus += iframe_bonus
	dash_distance_bonus += distance_bonus


func set_lobby_mode(enabled: bool) -> void:
	lobby_mode = enabled
	is_attacking = false


func _ensure_ground_shadow() -> void:
	if ground_shadow != null:
		return
	ground_shadow = Polygon2D.new()
	ground_shadow.polygon = _build_circle_polygon(11.0, 14)
	ground_shadow.color = Color(0.0, 0.0, 0.0, 0.52)
	ground_shadow.position = Vector2(0.0, 14.0)
	ground_shadow.scale = Vector2(1.42, 0.62)
	ground_shadow.show_behind_parent = true
	ground_shadow.z_index = 0
	add_child(ground_shadow)


func _update_ground_shadow() -> void:
	if ground_shadow == null or body_sprite == null:
		return
	var arc: float = clamp(-body_sprite.position.y / max(launch_height, 1.0), 0.0, 1.0)
	ground_shadow.position = Vector2(0.0, 14.0)
	ground_shadow.scale = Vector2(lerp(1.42, 0.9, arc), lerp(0.62, 0.38, arc))
	ground_shadow.modulate.a = lerp(0.52, 0.24, arc)


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _trigger_magnet_pulse() -> void:
	# Visual effect
	var pulse := Polygon2D.new()
	pulse.polygon = _build_circle_polygon(1.0, 32)
	pulse.color = Color(0.4, 0.7, 1.0, 0.4)
	pulse.z_index = -1
	add_child(pulse)
	
	var pulse_radius: float = 380.0
	var tween: Tween = create_tween()
	tween.tween_property(pulse, "scale", Vector2(pulse_radius, pulse_radius), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.45)
	tween.tween_callback(pulse.queue_free)
	
	# Mechanic logic: push all orbs in range toward player
	var orbs: Array[Node] = get_tree().get_nodes_in_group("xp_orbs")
	for orb in orbs:
		if orb is Node2D:
			var dist: float = global_position.distance_to(orb.global_position)
			if dist <= pulse_radius:
				if orb.has_method("magnet_pulse_pull"):
					orb.call("magnet_pulse_pull", global_position)
				elif orb.has_method("set_target_player"):
					# Fallback: force magnet mode if it exists
					orb.call("set_target_player", self)


func activate_magnet_pulse() -> void:
	has_magnet_pulse = true
	magnet_pulse_cooldown = 0.5


func upgrade_wand() -> void:
	wand_level = min(wand_level + 1, 8)
	# Reusing or placeholder signal
	# bow_level_changed.emit(wand_level, 8)


func _fire_wand() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
		
	var nearest = _get_nearest_enemy(enemies)
	if nearest == null:
		return
		
	var stats = ItemCatalog.get_item_by_id("wand_placeholder").get("stats_by_level", [])
	var level_stats = stats[wand_level-1] if wand_level <= stats.size() else {}
	
	var wand_scene = load("res://scenes/vfx/ArcaneOrb.tscn")
	var wand_script = load("res://scripts/ArcaneProjectile.gd")
	
	var count = level_stats.get("projectiles", 1)
	var base_damage = level_stats.get("damage", 16)
	var final_damage = int(base_damage * talent_damage_multiplier)
	
	for i in range(count):
		var orb: Area2D
		if wand_scene:
			orb = wand_scene.instantiate()
		else:
			orb = Area2D.new()
			orb.set_script(wand_script)
			
		orb.global_position = global_position
		
		var dir = (nearest.global_position - global_position).normalized()
		if count > 1:
			dir = dir.rotated(randf_range(-0.4, 0.4))
			
		orb.direction = dir
		orb.damage = final_damage
		orb.target = nearest
		orb.player_ref = self # Set player for orbiting
		if orb.has_method("set"):
			orb.set("wand_level", wand_level)
		
		get_parent().add_child(orb)
	
	wand_cooldown_timer = level_stats.get("cooldown", 1.5) * (1.0 / max(talent_attack_speed_multiplier, 0.01))


func _get_nearest_enemy(enemies: Array) -> Node2D:
	var nearest: Node2D = null
	var min_dist = INF
	for e in enemies:
		if e is Node2D:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest


func upgrade_bow() -> void:
	bow_level = min(bow_level + 1, 8)
	if bow_level == 1:
		bow_cooldown_timer = 0.5


func _get_bow_cooldown() -> float:
	var stats = ItemCatalog.get_item_by_id("bow_placeholder").get("stats_by_level", [])
	if bow_level > 0 and bow_level <= stats.size():
		return stats[bow_level-1].get("cooldown", 1.0)
	return 1.0


func _fire_bow() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	
	var nearest = _get_nearest_enemy(enemies)
	if nearest == null:
		return
		
	var stats = ItemCatalog.get_item_by_id("bow_placeholder").get("stats_by_level", [])
	var level_stats = stats[bow_level-1] if bow_level <= stats.size() else {}
	
	var arrow_scene = load("res://scenes/vfx/HunterArrow.tscn")
	var arrow_script = load("res://scripts/Arrow.gd")
	
	var count = level_stats.get("projectiles", 1)
	var base_damage = level_stats.get("damage", 12)
	var final_damage = int(base_damage * talent_damage_multiplier)
	
	for i in range(count):
		var arrow: Area2D
		if arrow_scene:
			arrow = arrow_scene.instantiate()
		else:
			arrow = Area2D.new()
			arrow.set_script(arrow_script)
			
		arrow.global_position = global_position
		# Spread logic
		var spread = 0.0
		if count > 1:
			spread = deg_to_rad(randf_range(-12.0, 12.0))
		
		var dir = (nearest.global_position - global_position).normalized()
		arrow.direction = dir.rotated(spread)
		arrow.damage = final_damage
		if arrow.has_method("set"):
			arrow.set("bow_level", bow_level) # Arrow handles its own pierce scaling
		get_parent().add_child(arrow)
	
	bow_cooldown_timer = level_stats.get("cooldown", 1.0) * (1.0 / max(talent_attack_speed_multiplier, 0.01))


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player = get_node_or_null("PlayerSFXPlayer") as AudioStreamPlayer
	if player != null:
		player.stream = stream
		player.volume_db = -15.0
		player.play()
