extends Area2D

signal collected(xp_value: int)

@export var xp_value: int = 1
@export var xp_tier: String = "blue"

var target_player: Node2D = null
var body_sprite: Polygon2D = null
var core_sprite: Polygon2D = null
var outline_sprite: Polygon2D = null
var ground_shadow: Polygon2D = null
var visual_time: float = 0.0
var core_base_scale: Vector2 = Vector2(0.72, 0.72)
var age_seconds: float = 0.0
## Squared distance beyond which bob/pulse visuals are skipped (still magnet when in range).
const VISUAL_LOD_DIST_SQ: float = 640000.0 # 800^2


func set_target_player(p: Node2D) -> void:
	target_player = p


func _ready() -> void:
	add_to_group("xp_orbs")
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
	body_sprite = $Polygon2D
	core_sprite = $Core
	outline_sprite = get_node_or_null("Outline") as Polygon2D
	_ensure_ground_shadow()


func _physics_process(delta: float) -> void:
	age_seconds += delta
	_ensure_visual_nodes()
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player: Vector2 = target_player.global_position - global_position
	var distance: float = to_player.length()
	var dist_sq: float = to_player.length_squared()
	var pickup_radius: float = target_player.get_pickup_radius() if target_player.has_method("get_pickup_radius") else 20.0
	var magnet_radius: float = target_player.get_magnet_range() if target_player.has_method("get_magnet_range") else 80.0
	var magnet_speed: float = target_player.get_magnet_strength() if target_player.has_method("get_magnet_strength") else 160.0

	if distance <= pickup_radius:
		collected.emit(xp_value)
		queue_free()
		return

	if distance <= magnet_radius and distance > 0.001:
		global_position += to_player.normalized() * magnet_speed * delta

	if dist_sq < VISUAL_LOD_DIST_SQ:
		visual_time += delta
		# Subtle bob/pulse so XP is easier to read.
		var bob: float = sin(visual_time * 5.0) * 1.6
		body_sprite.position.y = bob
		core_sprite.position.y = bob
		if outline_sprite != null:
			outline_sprite.position.y = bob
		_update_ground_shadow(bob)
		var pulse: float = 1.0 + (sin(visual_time * 8.0) * 0.08)
		core_sprite.scale = core_base_scale * pulse
	elif body_sprite != null and core_sprite != null:
		body_sprite.position.y = 0.0
		core_sprite.position.y = 0.0
		if outline_sprite != null:
			outline_sprite.position.y = 0.0
		core_sprite.scale = core_base_scale
		_update_ground_shadow(0.0)


func configure_drop(value: int, tier: String) -> void:
	xp_value = value
	xp_tier = tier
	_ensure_visual_nodes()
	if body_sprite == null or core_sprite == null:
		return

	match xp_tier:
		"blue":
			body_sprite.color = Color(0.35, 0.7, 1.0, 0.95)
			core_sprite.color = Color(0.85, 0.94, 1.0, 0.98)
		"green":
			body_sprite.color = Color(0.35, 1.0, 0.45, 0.95)
			core_sprite.color = Color(0.86, 1.0, 0.86, 0.98)
		"red":
			body_sprite.color = Color(1.0, 0.35, 0.35, 0.95)
			core_sprite.color = Color(1.0, 0.84, 0.84, 0.98)
		"rainbow":
			body_sprite.color = Color(1.0, 0.85, 0.35, 0.98)
			core_sprite.color = Color(1.0, 1.0, 0.9, 1.0)
		_:
			body_sprite.color = Color(0.7, 0.8, 1.0, 0.95)
			core_sprite.color = Color(0.95, 0.96, 1.0, 0.98)
	var size_boost: float = clamp(sqrt(float(max(xp_value, 1))) * 0.028, 0.0, 0.22)
	body_sprite.scale = Vector2(0.66, 0.66) * (1.0 + size_boost)
	core_base_scale = Vector2(0.54, 0.54) * (1.0 + size_boost)
	core_sprite.scale = core_base_scale
	if outline_sprite != null:
		outline_sprite.polygon = body_sprite.polygon
		outline_sprite.scale = Vector2(0.98, 0.98)
		outline_sprite.color = Color(0.0, 0.0, 0.0, 0.92)


func get_merge_xp_value() -> int:
	return xp_value


func get_age_seconds() -> float:
	return age_seconds


static func tier_for_total_xp(total: int) -> String:
	if total >= 30:
		return "rainbow"
	if total >= 14:
		return "red"
	if total >= 6:
		return "green"
	return "blue"


## Merge `other` into this orb (keeps target_player wiring on this node).
func absorb_merge_from(other: Node2D) -> void:
	if other == null or other == self:
		return
	if not other.has_method("get_merge_xp_value"):
		return
	xp_value += int(other.call("get_merge_xp_value"))
	global_position = global_position.lerp((other as Node2D).global_position, 0.5)
	other.queue_free()
	configure_drop(xp_value, tier_for_total_xp(xp_value))


func _ensure_visual_nodes() -> void:
	if body_sprite == null:
		body_sprite = get_node_or_null("Polygon2D") as Polygon2D
	if core_sprite == null:
		core_sprite = get_node_or_null("Core") as Polygon2D
	if outline_sprite == null:
		outline_sprite = get_node_or_null("Outline") as Polygon2D


func _ensure_ground_shadow() -> void:
	if ground_shadow != null:
		return
	ground_shadow = Polygon2D.new()
	ground_shadow.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(5, -2),
		Vector2(6, 0),
		Vector2(5, 2),
		Vector2(0, 4),
		Vector2(-5, 2),
		Vector2(-6, 0),
		Vector2(-5, -2)
	])
	ground_shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	ground_shadow.scale = Vector2(1.0, 0.58)
	ground_shadow.position = Vector2(0.0, 7.0)
	ground_shadow.show_behind_parent = true
	ground_shadow.z_index = 0
	add_child(ground_shadow)


func _update_ground_shadow(bob: float) -> void:
	if ground_shadow == null:
		return
	var t: float = clamp(abs(bob) / 1.8, 0.0, 1.0)
	ground_shadow.position = Vector2(0.0, 7.0)
	ground_shadow.scale = Vector2(lerp(1.0, 0.9, t), lerp(0.58, 0.5, t))
	ground_shadow.modulate.a = lerp(0.4, 0.3, t)
