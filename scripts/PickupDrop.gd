extends Area2D

signal collected(pickup_type: String, value: int)

@export var pickup_type: String = "coin"
@export var value: int = 1

var target_player: Node2D = null
var body_sprite: Polygon2D = null
var outline_sprite: Polygon2D = null
var ground_shadow: Polygon2D = null
var visual_time: float = 0.0


func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	body_sprite = $Body
	outline_sprite = get_node_or_null("Outline") as Polygon2D
	_ensure_ground_shadow()
	_apply_style()


func _physics_process(delta: float) -> void:
	visual_time += delta
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	var to_player: Vector2 = target_player.global_position - global_position
	var pickup_radius: float = target_player.get_pickup_radius() if target_player.has_method("get_pickup_radius") else 20.0
	if to_player.length() <= pickup_radius:
		collected.emit(pickup_type, value)
		queue_free()
		return
	if body_sprite != null:
		body_sprite.position.y = sin(visual_time * 6.0) * 1.2
	_update_ground_shadow()


func configure(kind: String, amount: int) -> void:
	pickup_type = kind
	value = max(amount, 1)
	_apply_style()


func _apply_style() -> void:
	if body_sprite == null:
		body_sprite = get_node_or_null("Body") as Polygon2D
	if outline_sprite == null:
		outline_sprite = get_node_or_null("Outline") as Polygon2D
	if body_sprite == null:
		return
	var coin_poly: PackedVector2Array = PackedVector2Array([Vector2(0, -7), Vector2(6, -3), Vector2(5, 4), Vector2(0, 7), Vector2(-5, 4), Vector2(-6, -3)])
	var heart_poly: PackedVector2Array = PackedVector2Array([
		Vector2(0, 8),
		Vector2(7, 1),
		Vector2(6, -4),
		Vector2(3, -7),
		Vector2(0, -4),
		Vector2(-3, -7),
		Vector2(-6, -4),
		Vector2(-7, 1)
	])
	match pickup_type:
		"health":
			body_sprite.color = Color(0.95, 0.26, 0.34, 0.95)
			body_sprite.polygon = heart_poly
			body_sprite.scale = Vector2(0.72, 0.72)
		_:
			body_sprite.color = Color(1.0, 0.86, 0.26, 0.95)
			body_sprite.polygon = coin_poly
			body_sprite.scale = Vector2(0.58, 0.58)
	if outline_sprite != null:
		outline_sprite.polygon = body_sprite.polygon
		outline_sprite.scale = body_sprite.scale * Vector2(1.42, 1.42)
		outline_sprite.color = Color(0.0, 0.0, 0.0, 0.92)


func _process(_delta: float) -> void:
	if outline_sprite != null and body_sprite != null:
		outline_sprite.position = body_sprite.position
	if ground_shadow != null and body_sprite != null:
		ground_shadow.position = Vector2(0.0, 8.0)


func _ensure_ground_shadow() -> void:
	if ground_shadow != null:
		return
	ground_shadow = Polygon2D.new()
	ground_shadow.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(6, -2),
		Vector2(7, 1),
		Vector2(0, 4),
		Vector2(-7, 1),
		Vector2(-6, -2)
	])
	ground_shadow.color = Color(0.0, 0.0, 0.0, 0.42)
	ground_shadow.scale = Vector2(1.08, 0.6)
	ground_shadow.position = Vector2(0.0, 8.0)
	ground_shadow.show_behind_parent = true
	ground_shadow.z_index = 0
	add_child(ground_shadow)


func _update_ground_shadow() -> void:
	if ground_shadow == null or body_sprite == null:
		return
	var bob_abs: float = abs(body_sprite.position.y)
	var t: float = clamp(bob_abs / 2.0, 0.0, 1.0)
	ground_shadow.scale = Vector2(lerp(1.08, 0.96, t), lerp(0.6, 0.52, t))
	ground_shadow.modulate.a = lerp(0.42, 0.32, t)
