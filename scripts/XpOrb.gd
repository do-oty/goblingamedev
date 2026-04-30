extends Area2D

signal collected(xp_value: int)

@export var xp_value: int = 1
@export var xp_tier: String = "blue"

var target_player: Node2D = null
var body_sprite: Polygon2D = null
var core_sprite: Polygon2D = null
var visual_time: float = 0.0


func _ready() -> void:
	add_to_group("xp_orbs")
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	body_sprite = $Polygon2D
	core_sprite = $Core


func _physics_process(delta: float) -> void:
	visual_time += delta
	_ensure_visual_nodes()
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player: Vector2 = target_player.global_position - global_position
	var distance: float = to_player.length()
	var pickup_radius: float = target_player.get_pickup_radius() if target_player.has_method("get_pickup_radius") else 20.0
	var magnet_radius: float = target_player.get_magnet_range() if target_player.has_method("get_magnet_range") else 80.0
	var magnet_speed: float = target_player.get_magnet_strength() if target_player.has_method("get_magnet_strength") else 160.0

	if distance <= pickup_radius:
		collected.emit(xp_value)
		queue_free()
		return

	if distance <= magnet_radius and distance > 0.001:
		global_position += to_player.normalized() * magnet_speed * delta

	# Subtle bob/pulse so XP is easier to read.
	var bob: float = sin(visual_time * 5.0) * 1.6
	body_sprite.position.y = bob
	core_sprite.position.y = bob
	var pulse: float = 1.0 + (sin(visual_time * 8.0) * 0.08)
	core_sprite.scale = Vector2.ONE * pulse


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


func _ensure_visual_nodes() -> void:
	if body_sprite == null:
		body_sprite = get_node_or_null("Polygon2D") as Polygon2D
	if core_sprite == null:
		core_sprite = get_node_or_null("Core") as Polygon2D
