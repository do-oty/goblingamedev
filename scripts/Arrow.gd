extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 680.0
var damage: int = 14
var lifetime: float = 4.0
var hit_enemies: Array[Node2D] = []
var bow_level: int = 1
var pierce_count: int = 1

func _ready() -> void:
	pierce_count = (bow_level * 2)
	z_index = 10
	
	if not has_node("Visual") and not has_node("Sprite2D"):
		_setup_procedural_arrow()
	
	collision_layer = 0
	collision_mask = 3
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	# ABSOLUTE CLEANUP TIMER
	var death_timer := Timer.new()
	death_timer.wait_time = lifetime + 2.0
	death_timer.one_shot = true
	death_timer.autostart = true
	death_timer.timeout.connect(queue_free)
	add_child(death_timer)


func _setup_procedural_arrow() -> void:
	# 1. Shadow (Grounded)
	var shadow := Polygon2D.new()
	shadow.name = "ArrowShadow"
	shadow.color = Color(0, 0, 0, 0.45)
	shadow.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(10, 1), Vector2(8, 2), Vector2(-8, 2)])
	shadow.top_level = true
	shadow.z_as_relative = false
	shadow.z_index = 1
	add_child(shadow)
	
	# 2. Visual
	var poly := Polygon2D.new()
	poly.name = "CoreVisual"
	poly.color = Color(0.95, 0.95, 0.85, 1.0)
	poly.polygon = PackedVector2Array([Vector2(-8, -1), Vector2(4, -1), Vector2(10, 0), Vector2(4, 1), Vector2(-8, 1)])
	add_child(poly)
	
	var tail := Polygon2D.new()
	tail.color = Color(0.6, 0.4, 0.2, 1.0)
	tail.polygon = PackedVector2Array([Vector2(-8, -3), Vector2(-4, -1), Vector2(-4, 1), Vector2(-8, 3)])
	poly.add_child(tail)

	# 3. Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 16)
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation = direction.angle()
	
	if has_node("ArrowShadow"):
		var s = get_node("ArrowShadow")
		s.global_position = global_position + Vector2(0, 18)
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and not body in hit_enemies:
		hit_enemies.append(body)
		
		if body.has_method("take_damage"):
			body.call("take_damage", damage, global_position, 55.0)
		
		_spawn_hit_vfx(global_position)
		
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()


func _spawn_hit_vfx(pos: Vector2) -> void:
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([Vector2(-2,-2), Vector2(2,-2), Vector2(2,2), Vector2(-2,2)])
	spark.color = Color(1.0, 1.0, 0.9, 0.9)
	spark.global_position = pos
	get_parent().add_child.call_deferred(spark)
	
	var t := spark.create_tween()
	t.tween_property(spark, "scale", Vector2(3.0, 3.0), 0.1)
	t.parallel().tween_property(spark, "modulate:a", 0.0, 0.1)
	t.tween_callback(spark.queue_free)
