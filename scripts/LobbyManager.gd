extends Node

@onready var portal_forest: Node2D = $"../PortalForest"
@onready var portal_snow: Node2D = $"../PortalSnow"
@onready var portal_desert: Node2D = $"../PortalDesert"


func _ready() -> void:
	_apply_unlock_state()


func _enter_tree() -> void:
	call_deferred("_apply_unlock_state")


func _apply_unlock_state() -> void:
	_set_portal_locked(portal_forest, false, "Forest")
	_set_portal_locked(portal_snow, not GameState.is_snow_map_unlocked(), "Snow")
	_set_portal_locked(portal_desert, not GameState.is_desert_map_unlocked(), "Desert")


func _set_portal_locked(portal_root: Node2D, is_locked: bool, label_text: String) -> void:
	if portal_root == null:
		return
	var label: Label = portal_root.get_node_or_null("PortalLabel") as Label
	if label != null:
		label.visible = true
		label.z_index = 5 # Ensure it draws above the road (z_index 1)
		if is_locked:
			label.text = "%s (Locked)" % label_text
		else:
			var progress = GameState.get_map_progress(label_text)
			var index = progress.get("index", 0)
			var count = progress.get("count", 0)
			if count > 0:
				label.text = "%s (%d/%d)" % [label_text, index, count]
			else:
				label.text = label_text
		label.modulate = Color(0.68, 0.68, 0.68, 1.0) if is_locked else Color(1.0, 1.0, 1.0, 1.0)
	var ring: CanvasItem = portal_root.get_node_or_null("PortalRing") as CanvasItem
	if ring != null:
		ring.visible = not is_locked
	var portal_area: Area2D = portal_root.get_node_or_null("PortalArea") as Area2D
	if portal_area == null:
		return
	portal_area.monitoring = not is_locked
	portal_area.monitorable = not is_locked
	var collision_shape: CollisionShape2D = portal_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = is_locked
