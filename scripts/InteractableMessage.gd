extends Area2D
class_name InteractableMessage


@export var message_text: String = "Don't come back until the job's done!"
@export var display_duration: float = 2.0
@export var color: Color = Color(1, 0.4, 0.4)
@export var label_offset: Vector2 = Vector2(0, -60)
@export var jump_height: float = 15.0

var label: Label
var current_tween: Tween

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 
	
	# Try to find an existing Label child (placed by user in editor)
	label = get_node_or_null("Label") as Label
	
	if label == null:
		# Fallback: Create dynamic label if user hasn't added one manually
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		label.size = Vector2(400, 30)
		label.position = label_offset - Vector2(200, 0)
		add_child(label)
	
	# Apply consistent styling to either dynamic or manual label
	label.text = message_text
	label.add_theme_font_size_override("font_size", 14) # Slightly smaller default
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 1)
	
	label.visible = false
	label.z_index = 50
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_show_message()
		if body.has_method("apply_launch_force"):
			body.call("apply_launch_force", global_position, 350.0, 30.0, 0.3)
		else:
			var push_dir = (body.global_position - global_position).normalized()
			if push_dir == Vector2.ZERO: push_dir = Vector2(0, 1)
			body.global_position += push_dir * 80.0

func _show_message() -> void:
	if current_tween:
		current_tween.kill()
		
	label.visible = true
	label.modulate.a = 1.0
	label.text = message_text
	
	var base_y = label.position.y
	var target_y = base_y - jump_height
	
	current_tween = create_tween()
	current_tween.tween_property(label, "position:y", target_y, 0.2).from(base_y).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	current_tween.tween_property(label, "modulate:a", 0.0, display_duration).set_delay(0.5)
	current_tween.tween_callback(func(): label.visible = false; label.position.y = base_y)
