extends Area2D

const EXPLOSION_DAMAGE: int = 38
const EXPLOSION_RADIUS: float = 72.0
const EXPLOSION_KNOCKBACK: float = 140.0

var triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Visual idle pulse
	var t := create_tween().set_loops()
	t.tween_property($Visual, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property($Visual, "scale", Vector2(0.9, 0.9), 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if body.is_in_group("player") or body.is_in_group("enemy"):
		_explode()


func _explode() -> void:
	triggered = true
	set_deferred("monitoring", false)
	
	# Visuals
	var explosion := Polygon2D.new()
	explosion.polygon = _build_circle_polygon(1.0, 24)
	explosion.color = Color(1.0, 0.45, 0.1, 0.7)
	explosion.global_position = global_position
	explosion.z_index = 5
	get_parent().add_child(explosion)
	
	var t := create_tween()
	t.tween_property(explosion, "scale", Vector2(EXPLOSION_RADIUS, EXPLOSION_RADIUS), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(explosion, "modulate:a", 0.0, 0.24)
	t.tween_callback(explosion.queue_free)
	
	# Shake
	if get_tree().get_first_node_in_group("player").has_method("add_screen_shake"):
		var dist = global_position.distance_to(get_tree().get_first_node_in_group("player").global_position)
		if dist < 400:
			get_tree().get_first_node_in_group("player").add_screen_shake(8.0 * (1.0 - dist/400.0), 0.15)
	
	# Logic: Damage nearby
	var units = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemy")
	for unit in units:
		if unit is Node2D:
			var dist = global_position.distance_to(unit.global_position)
			if dist <= EXPLOSION_RADIUS:
				_deal_damage(unit)
				_apply_knockback(unit)
				
	queue_free()


func _deal_damage(unit: Node2D) -> void:
	if unit.has_method("receive_damage"):
		unit.call("receive_damage", EXPLOSION_DAMAGE)
	elif unit.has_method("take_damage"):
		unit.call("take_damage", EXPLOSION_DAMAGE)


func _apply_knockback(unit: Node2D) -> void:
	if unit.has_method("apply_launch_force"):
		unit.call("apply_launch_force", global_position, EXPLOSION_KNOCKBACK, 20.0, 0.2)
	elif unit.has_method("apply_external_launch"):
		unit.call("apply_external_launch", global_position, EXPLOSION_KNOCKBACK, 20.0, 0.2)


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
