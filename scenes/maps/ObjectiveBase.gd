extends Node

const GOLDEN_KEY_TYPE: String = "golden_key"
const PICKUP_DROP_SCENE: PackedScene = preload("res://scenes/PickupDrop.tscn")
const LOBBY_SCENE_PATH: String = "res://scenes/maps/LobbyMap.tscn"

@export var kills_required: int = 10
@export var objective_name: String = "Map"
@export var unlock_map_id: String = ""

var kill_count: int = 0
var objective_complete: bool = false
var key_spawned: bool = false
var key_pickup: Area2D = null
var completion_panel_open: bool = false
var player_died: bool = false

var enemies_root: Node2D = null
var drops_root: Node2D = null
var player: CharacterBody2D = null
var canvas_layer: CanvasLayer = null

var objective_label: Label = null
var key_arrow_label: Label = null
var completion_panel: PanelContainer = null
var completion_title_label: Label = null
var completion_stats_label: Label = null
var completion_hint_label: Label = null


func _ready() -> void:
	enemies_root = get_node_or_null("../Enemies") as Node2D
	drops_root = get_node_or_null("../Drops") as Node2D
	player = get_node_or_null("../Player") as CharacterBody2D
	canvas_layer = get_node_or_null("../CanvasLayer") as CanvasLayer

	_connect_existing_enemies()
	if enemies_root != null:
		if not enemies_root.child_entered_tree.is_connected(_on_enemy_added):
			enemies_root.child_entered_tree.connect(_on_enemy_added)
	if drops_root != null:
		if not drops_root.child_entered_tree.is_connected(_on_drop_added):
			drops_root.child_entered_tree.connect(_on_drop_added)
	if player != null and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

	_create_ui()
	_update_objective_label()
	await get_tree().process_frame
	_apply_difficulty()


func _process(_delta: float) -> void:
	_update_key_arrow()


func _unhandled_input(event: InputEvent) -> void:
	if not completion_panel_open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		completion_panel_open = false
		if completion_panel != null:
			completion_panel.visible = false
		get_tree().paused = false
		process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _on_enemy_added(node: Node) -> void:
	await get_tree().process_frame
	_try_connect_enemy(node)


func _connect_existing_enemies() -> void:
	if enemies_root == null:
		return
	for enemy in enemies_root.get_children():
		_try_connect_enemy(enemy)


func _try_connect_enemy(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("defeated"):
		return
	if enemy.defeated.is_connected(_on_enemy_defeated):
		return
	enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(world_position: Vector2, _xp_value: int, _xp_tier: String) -> void:
	if objective_complete:
		return
	kill_count += 1
	_update_objective_label()
	if kill_count >= kills_required and not key_spawned:
		_spawn_golden_key_deferred.call_deferred(world_position)


func _spawn_golden_key_deferred(world_position: Vector2) -> void:
	if key_spawned or drops_root == null:
		return
	key_spawned = true
	var pickup: Area2D = PICKUP_DROP_SCENE.instantiate() as Area2D
	if pickup == null:
		return
	pickup.global_position = world_position
	if pickup.has_method("configure"):
		pickup.call("configure", GOLDEN_KEY_TYPE, 1)
	if player != null and pickup.has_method("set_target_player"):
		pickup.call("set_target_player", player)
	if pickup.has_signal("collected") and not pickup.collected.is_connected(_on_pickup_collected):
		pickup.collected.connect(_on_pickup_collected)
	drops_root.add_child(pickup)
	key_pickup = pickup
	_update_objective_label()


func _on_drop_added(node: Node) -> void:
	await get_tree().process_frame
	if node == null or not node.has_signal("collected"):
		return
	if not node.collected.is_connected(_on_pickup_collected):
		node.collected.connect(_on_pickup_collected)


func _on_pickup_collected(pickup_type: String, _value: int) -> void:
	if objective_complete or pickup_type != GOLDEN_KEY_TYPE:
		return
	objective_complete = true
	_unlock_next_map()
	_update_objective_label()
	_update_key_arrow()
	_show_completion_panel("Map Complete!", "Goblins Defeated: %d / %d" % [kill_count, kills_required])


func _unlock_next_map() -> void:
	var map_id: String = unlock_map_id.to_lower()
	if map_id.is_empty():
		return
	if GameState.has_method("unlock_map"):
		GameState.unlock_map(map_id)
		return
	if map_id == "snow" and GameState.has_method("set_snow_map_unlocked"):
		GameState.set_snow_map_unlocked(true)
	elif map_id == "desert" and GameState.has_method("set_desert_map_unlocked"):
		GameState.set_desert_map_unlocked(true)


func _create_ui() -> void:
	if canvas_layer == null:
		return
	objective_label = Label.new()
	objective_label.position = Vector2(14.0, 14.0)
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.z_index = 90
	canvas_layer.add_child(objective_label)

	key_arrow_label = Label.new()
	key_arrow_label.visible = false
	key_arrow_label.text = ">"
	key_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_arrow_label.size = Vector2(28.0, 28.0)
	key_arrow_label.pivot_offset = key_arrow_label.size * 0.5
	key_arrow_label.add_theme_font_size_override("font_size", 30)
	key_arrow_label.z_index = 130
	canvas_layer.add_child(key_arrow_label)

	completion_panel = PanelContainer.new()
	completion_panel.visible = false
	completion_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	completion_panel.z_index = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.86)
	completion_panel.add_theme_stylebox_override("panel", style)
	canvas_layer.add_child(completion_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_panel.add_child(center)
	var text_vbox := VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 16)
	text_vbox.custom_minimum_size = Vector2(860.0, 260.0)
	center.add_child(text_vbox)

	completion_title_label = Label.new()
	completion_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title_label.add_theme_font_size_override("font_size", 64)
	completion_title_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	text_vbox.add_child(completion_title_label)

	completion_stats_label = Label.new()
	completion_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_stats_label.add_theme_font_size_override("font_size", 30)
	text_vbox.add_child(completion_stats_label)

	completion_hint_label = Label.new()
	completion_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_hint_label.add_theme_font_size_override("font_size", 24)
	completion_hint_label.text = "Press Enter or Esc to return to Lobby"
	completion_hint_label.modulate = Color(0.92, 0.92, 0.92, 1.0)
	text_vbox.add_child(completion_hint_label)


func _update_objective_label() -> void:
	if objective_label == null:
		return
	if objective_complete:
		objective_label.text = "%s Objective Complete" % objective_name
	elif key_spawned:
		objective_label.text = "Golden key dropped! Pick it up."
	else:
		objective_label.text = "%s Objective: Defeat goblins %d / %d" % [objective_name, kill_count, kills_required]


func _update_key_arrow() -> void:
	if key_arrow_label == null:
		return
	if objective_complete or player == null or not key_spawned or key_pickup == null or not is_instance_valid(key_pickup):
		key_arrow_label.visible = false
		return
	var key_world_pos: Vector2 = key_pickup.global_position
	var to_key: Vector2 = key_world_pos - player.global_position
	if to_key.length_squared() <= 1.0:
		key_arrow_label.visible = false
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = viewport_size * 0.5
	var direction: Vector2 = to_key.normalized()
	var edge_radius: float = min(viewport_size.x, viewport_size.y) * 0.38
	key_arrow_label.position = center + (direction * edge_radius) - (key_arrow_label.size * 0.5)
	key_arrow_label.rotation = direction.angle()
	key_arrow_label.visible = true


func _show_completion_panel(title: String, stats_text: String) -> void:
	if completion_panel == null:
		get_tree().change_scene_to_file(LOBBY_SCENE_PATH)
		return
	completion_panel_open = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	completion_panel.visible = true
	completion_panel.move_to_front()
	if completion_title_label != null:
		completion_title_label.text = title
	if completion_stats_label != null:
		completion_stats_label.text = stats_text
	get_tree().paused = true


func _on_player_died() -> void:
	if player_died:
		return
	player_died = true
	call_deferred("_inject_death_progress_text")


func _apply_difficulty() -> void:
	pass


func _inject_death_progress_text() -> void:
	await get_tree().process_frame
	var progress_text: String = "You died - Progress: %d / %d goblins killed" % [kill_count, kills_required]
	var game_over_description: Label = get_node_or_null("../CanvasLayer/HUD/GameOverPanel/Margin/RootRow/SummaryPanel/SummaryMargin/SummaryVBox/Description") as Label
	if game_over_description != null and not game_over_description.text.contains(progress_text):
		game_over_description.text = "%s\n%s" % [game_over_description.text, progress_text]
	var death_summary: Label = get_node_or_null("../CanvasLayer/HUD/DeathMenu/CenterContainer/Card/RootRow/SummaryVBox/SummaryText") as Label
	if death_summary != null and not death_summary.text.contains(progress_text):
		death_summary.text = "%s\n%s" % [death_summary.text, progress_text]
