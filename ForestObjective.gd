extends Node

const KILLS_TO_WIN: int = 10
const LOBBY_MAP_PATH: String = "res://scenes/maps/LobbyMap.tscn"
const KEY_PICKUP_TYPE: String = "golden_key"
const OVERLAY_SCRIPT: Script = preload("res://scripts/ui/ForestObjectiveOverlay.gd")

var goblin_kill_count: int = 0
var objective_complete: bool = false
var key_dropped: bool = false
var key_collected: bool = false
var message_open: bool = false
var player_dead: bool = false

var enemies_root: Node = null
var canvas_layer: CanvasLayer = null
var drops_root: Node = null
var player: CharacterBody2D = null
var objective_label: Label = null
var message_panel: PanelContainer = null
var message_label: Label = null
var golden_key_node: Node2D = null
var objective_overlay: Control = null

func _ready() -> void:
	await get_tree().process_frame

	enemies_root = get_node_or_null("../Enemies")
	canvas_layer = get_node_or_null("../CanvasLayer")
	drops_root = get_node_or_null("../Drops")
	player = get_node_or_null("../Player") as CharacterBody2D

	_connect_existing_enemies()
	if enemies_root != null:
		enemies_root.child_entered_tree.connect(_on_enemy_added)
	if drops_root != null:
		drops_root.child_entered_tree.connect(_on_drop_added)
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)

	_create_overlay()
	_create_objective_ui()
	_update_display()


func _on_enemy_added(node: Node) -> void:
	await get_tree().process_frame
	if node != null and node.has_signal("defeated"):
		if not node.defeated.is_connected(_on_goblin_killed):
			node.defeated.connect(_on_goblin_killed)


func _connect_existing_enemies() -> void:
	if enemies_root == null:
		return
	for enemy in enemies_root.get_children():
		if enemy.has_signal("defeated"):
			if not enemy.defeated.is_connected(_on_goblin_killed):
				enemy.defeated.connect(_on_goblin_killed)


func _on_goblin_killed(_world_position: Vector2, _xp_value: int, _xp_tier: String) -> void:
	if objective_complete or key_dropped:
		return

	goblin_kill_count += 1
	_update_display()

	if goblin_kill_count >= KILLS_TO_WIN:
		key_dropped = true
		var root: Node = get_node_or_null("..")
		if root != null and root.has_method("spawn_objective_pickup"):
			root.call("spawn_objective_pickup", _world_position, KEY_PICKUP_TYPE, 1)
		if objective_overlay != null and objective_overlay.has_method("set_portal_locked"):
			objective_overlay.call("set_portal_locked", true)
		_update_display()


func _update_display() -> void:
	if objective_label == null:
		return
	if key_collected:
		objective_label.text = "Map 1 Objective Complete"
	elif key_dropped:
		objective_label.text = "Golden Key dropped! Pick it up."
	else:
		objective_label.text = "Map 1 Objective: Goblins %d / %d" % [goblin_kill_count, KILLS_TO_WIN]


func _on_drop_added(node: Node) -> void:
	await get_tree().process_frame
	if node == null or not node.has_signal("collected"):
		return
	if String(node.get("pickup_type")) == KEY_PICKUP_TYPE and node is Node2D:
		golden_key_node = node as Node2D
	if not node.collected.is_connected(_on_drop_collected):
		node.collected.connect(_on_drop_collected)


func _on_drop_collected(pickup_type: String, _value: int) -> void:
	if pickup_type != KEY_PICKUP_TYPE or key_collected:
		return
	key_collected = true
	objective_complete = true
	GameState.unlock_map("snow")
	golden_key_node = null
	if objective_overlay != null and objective_overlay.has_method("set_key_guidance"):
		objective_overlay.call("set_key_guidance", false, Vector2.ZERO, Vector2.ZERO)
	if objective_overlay != null and objective_overlay.has_method("set_portal_locked"):
		objective_overlay.call("set_portal_locked", false)
	_update_display()
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


func _process(_delta: float) -> void:
	if objective_overlay == null or not objective_overlay.has_method("set_key_guidance"):
		return
	if player_dead or key_collected:
		objective_overlay.call("set_key_guidance", false, Vector2.ZERO, Vector2.ZERO)
		return
	if key_dropped and golden_key_node != null and is_instance_valid(golden_key_node) and player != null:
		objective_overlay.call("set_key_guidance", true, golden_key_node.global_position, player.global_position)
	else:
		objective_overlay.call("set_key_guidance", false, Vector2.ZERO, Vector2.ZERO)


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
	message_panel.size = Vector2(640, 120)
	message_panel.position = Vector2(-320, -60)
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


func _create_overlay() -> void:
	if canvas_layer == null:
		return
	objective_overlay = Control.new()
	objective_overlay.set_script(OVERLAY_SCRIPT)
	objective_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.add_child(objective_overlay)
	if objective_overlay.has_signal("retry_pressed"):
		objective_overlay.retry_pressed.connect(_on_retry_pressed)
	if objective_overlay.has_signal("lobby_pressed"):
		objective_overlay.lobby_pressed.connect(_on_lobby_pressed)
	if objective_overlay.has_method("set_portal_locked"):
		objective_overlay.call("set_portal_locked", true)


func _show_unlock_message() -> void:
	if message_panel == null or message_label == null:
		get_tree().change_scene_to_file(LOBBY_MAP_PATH)
		return
	message_open = true
	message_panel.visible = true
	message_panel.move_to_front()
	message_label.text = "You obtained the Golden Key! The snow region is now unlocked.\nPress Enter/Esc to continue."


func _on_player_died() -> void:
	if player_dead:
		return
	player_dead = true
	var existing_game_over: CanvasItem = get_node_or_null("../CanvasLayer/HUD/GameOverPanel") as CanvasItem
	if existing_game_over != null:
		existing_game_over.visible = false
	get_tree().paused = true
	if objective_overlay != null and objective_overlay.has_method("show_death_screen"):
		objective_overlay.call("show_death_screen", goblin_kill_count, KILLS_TO_WIN, "Grass Region")


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_lobby_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LOBBY_MAP_PATH)
