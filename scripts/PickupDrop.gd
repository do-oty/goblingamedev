extends Area2D

signal collected(pickup_type: String, value: int)

@export var pickup_type: String = "coin"
@export var value: int = 1

var target_player: Node2D = null
var body_sprite: Polygon2D = null
var visual_time: float = 0.0


func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	body_sprite = $Body
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


func configure(kind: String, amount: int) -> void:
	pickup_type = kind
	value = max(amount, 1)
	_apply_style()


func _apply_style() -> void:
	if body_sprite == null:
		body_sprite = get_node_or_null("Body") as Polygon2D
	if body_sprite == null:
		return
	match pickup_type:
		"health":
			body_sprite.color = Color(0.95, 0.26, 0.34, 0.95)
			body_sprite.scale = Vector2(1.1, 1.1)
		_:
			body_sprite.color = Color(1.0, 0.86, 0.26, 0.95)
			body_sprite.scale = Vector2.ONE
