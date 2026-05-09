extends Node

const KILLS_TO_WIN: int = 20
const LOBBY_MAP_PATH: String = "res://scenes/maps/LobbyMap.tscn"

var kill_count: int = 0
var objective_complete: bool = false
var message_open: bool = false

var enemies_root: Node = null
var canvas_layer: CanvasLayer = null
var objective_label: Label = null
var message_panel: PanelContainer = null
var message_label: Label = null

func _ready() -> void:
	await get_tree().process_frame

	enemies_root = get_node_or_null("../Enemies")
	canvas_layer = get_node_or_null("../CanvasLayer")
	_connect_existing_enemies()

	if enemies_root != null:
		enemies_root.child_entered_tree.connect(_on_enemy_added)

	_create_objective_ui()
	_update_display()


func _on_enemy_added(node: Node) -> void:
	await get_tree().process_frame
	if node != null and node.has_signal("defeated"):
		if not node.defeated.is_connected(_on_enemy_killed):
			node.defeated.connect(_on_enemy_killed)


func _connect_existing_enemies() -> void:
	if enemies_root == null:
		return
	for enemy in enemies_root.get_children():
		if enemy.has_signal("defeated"):
			if not enemy.defeated.is_connected(_on_enemy_killed):
				enemy.defeated.connect(_on_enemy_killed)


func _on_enemy_killed(_world_position: Vector2, _xp_value: int, _xp_tier: String) -> void:
	if objective_complete:
		return

	kill_count += 1
	_update_display()

	if kill_count >= KILLS_TO_WIN:
		objective_complete = true
		_trigger_complete()


func _update_display() -> void:
	if objective_label != null:
		objective_label.text = "Map 2 Objective: Kills %d / %d" % [kill_count, KILLS_TO_WIN]


func _trigger_complete() -> void:
	GameState.unlock_map("desert")
	_show_unlock_message()


func _unhandled_input(event: InputEvent) -> void:
	if not message_open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		var vp: Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		message_open = false
		if message_panel != null:
			message_panel.visible = false
		get_tree().change_scene_to_file(LOBBY_MAP_PATH)


func _create_objective_ui() -> void:
	if canvas_layer == null:
		return
	objective_label = Label.new()
	objective_label.position = Vector2(14, 16)
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	canvas_layer.add_child(objective_label)
	message_panel = PanelContainer.new()
	message_panel.visible = false
	message_panel.set_anchors_preset(Control.PRESET_CENTER)
	message_panel.size = Vector2(620, 110)
	message_panel.position = Vector2(-310, -55)
	message_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	message_panel.add_child(margin)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(message_label)
	canvas_layer.add_child(message_panel)


func _show_unlock_message() -> void:
	if message_panel == null or message_label == null:
		get_tree().change_scene_to_file(LOBBY_MAP_PATH)
		return
	message_open = true
	message_panel.visible = true
	message_panel.move_to_front()
	message_label.text = "Snow objective cleared! Desert region unlocked.\nPress Enter/Esc to return to Lobby."
