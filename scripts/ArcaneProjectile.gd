extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 320.0
var damage: int = 12
var lifetime: float = 5.0
var homing_strength: float = 4.2
var target: Node2D = null
var wand_level: int = 1

var player_ref: Node2D = null
var mode: String = "ORBIT" 
var orbit_angle: float = 0.0
var orbit_radius: float = 50.0
var orbit_speed: float = 7.5
var orbit_timer: float = 1.2

func _ready() -> void:
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	z_index = 10
	
	if player_ref == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0]
	
	orbit_timer = 1.0 + (wand_level * 0.15)
	orbit_radius = 42.0 + (wand_level * 2.5)
	
	if not has_node("Visual") and not has_node("Sprite2D"):
		_setup_procedural_wand()
	
	collision_layer = 0
	collision_mask = 3
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	# ABSOLUTE CLEANUP TIMER (Failsafe)
	var death_timer := Timer.new()
	death_timer.wait_time = lifetime + orbit_timer + 2.0
	death_timer.one_shot = true
	death_timer.autostart = true
	death_timer.timeout.connect(queue_free)
	add_child(death_timer)


func _setup_procedural_wand() -> void:
	# 1. Shadow (Grounded)
	var shadow := Polygon2D.new()
	shadow.name = "WandShadow"
	shadow.color = Color(0, 0, 0, 0.45)
	shadow.polygon = _build_circle(7.5, 10)
	shadow.scale.y = 0.4
	shadow.top_level = true # Independent of parent rotation
	shadow.z_as_relative = false
	shadow.z_index = 1 # Above floor (0), below player (5)
	add_child(shadow)

	# 2. Visual
	var poly := Polygon2D.new()
	poly.name = "CoreVisual"
	poly.color = Color(0.1, 0.4, 0.9, 0.95)
	poly.polygon = _build_circle(6.0, 12)
	add_child(poly)
	
	var glow := Polygon2D.new()
	glow.color = Color(0.3, 0.6, 1.0, 0.25)
	glow.polygon = _build_circle(14.0, 12)
	add_child(glow)

	# 3. Collision
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	if mode == "ORBIT":
		_process_orbit(delta)
	else:
		_process_fire(delta)
		
	if has_node("WandShadow"):
		var s = get_node("WandShadow")
		s.global_position = global_position + Vector2(0, 18)
	
	lifetime -= delta
	if lifetime <= 0 and mode == "FIRE":
		queue_free()


func _process_orbit(delta: float) -> void:
	if not is_instance_valid(player_ref):
		mode = "FIRE"
		return
		
	orbit_angle += orbit_speed * delta
	var offset = Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	global_position = player_ref.global_position + offset
	
	orbit_timer -= delta
	if orbit_timer <= 0:
		mode = "FIRE"
		_find_initial_target()


func _find_initial_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	if not enemies.is_empty():
		var nearest = enemies[0]
		var min_dist = global_position.distance_to(nearest.global_position)
		for e in enemies:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
		target = nearest
		direction = (target.global_position - global_position).normalized()
	else:
		direction = Vector2.UP.rotated(orbit_angle)


func _process_fire(delta: float) -> void:
	if is_instance_valid(target):
		var target_dir = (target.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, delta * homing_strength).normalized()
	
	global_position += direction * speed * delta
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.call("take_damage", damage, global_position, 35.0)
		
		_spawn_hit_vfx(global_position)
		queue_free()


func _spawn_hit_vfx(pos: Vector2) -> void:
	var splash := Polygon2D.new()
	splash.polygon = _build_circle(5.0, 8)
	splash.color = Color(1.0, 1.0, 1.0, 0.9)
	splash.global_position = pos
	get_parent().add_child.call_deferred(splash)
	
	var t := splash.create_tween()
	t.tween_property(splash, "scale", Vector2(4.0, 4.0), 0.15)
	t.parallel().tween_property(splash, "modulate:a", 0.0, 0.15)
	t.tween_callback(splash.queue_free)


func _build_circle(radius: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var angle = float(i) / steps * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points
