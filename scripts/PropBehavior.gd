extends Node2D
# Attach this script to any Node2D or Sprite2D prop (Tree, Rock, etc.) 
# to automatically generate a coded collision and a drop shadow.

@export_group("Physics")
@export var radius: float = 14.0
@export var enable_collision: bool = true

@export_group("Visuals")
@export var enable_shadow: bool = true
@export var shadow_offset: Vector2 = Vector2(0, 4)
@export var shadow_opacity: float = 0.3
@export var shadow_scale_x: float = 1.1
@export var shadow_scale_y: float = 0.5


func _ready() -> void:
	if enable_shadow:
		_add_shadow()
	if enable_collision:
		_add_collision()


func _add_shadow() -> void:
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	var steps := 12
	for i in range(steps):
		var angle = float(i) / steps * TAU
		points.append(Vector2(cos(angle) * radius * shadow_scale_x, sin(angle) * radius * shadow_scale_y))
	
	shadow.name = "AutoShadow"
	shadow.polygon = points
	shadow.color = Color(0, 0, 0, shadow_opacity)
	shadow.position = shadow_offset
	shadow.z_index = -1
	add_child(shadow)
	# Ensure shadow is behind the sprite
	move_child(shadow, 0)


func _add_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "AutoCollision"
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.8 # Slightly smaller than visual for better feel
	col.shape = shape
	
	body.add_child(col)
	add_child(body)
