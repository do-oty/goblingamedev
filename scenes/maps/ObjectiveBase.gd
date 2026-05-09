extends Node

const GOLDEN_KEY_TYPE: String = "golden_key"
const PICKUP_DROP_SCENE: PackedScene = preload("res://scenes/PickupDrop.tscn")
const LOBBY_SCENE_PATH: String = "res://scenes/maps/LobbyMap.tscn"
const BRUTE_SCENE: PackedScene = preload("res://assets/characters/bruteChampion.tscn")

@export var kills_required: int = 10
@export var objective_name: String = "Map"
@export var unlock_map_id: String = ""

@export_category("SFX Wiring")
@export var sfx_step_complete: AudioStream
@export var sfx_all_complete: AudioStream
@export var sfx_enemy_match: AudioStream
@export var sfx_boss_spawn: AudioStream

var kill_count: int = 0
var objective_complete: bool = false
var objectives_finished: bool = false
var key_spawned: bool = false
var key_pickup: Area2D = null
var completion_panel_open: bool = false
var player_died: bool = false

# New multi-objective system
var objectives: Array = [
	{"type": "kill", "target": "any", "required": 15, "count": 0, "desc": "Defeat any goblins"},
	{"type": "kill", "target": "brute", "required": 2, "count": 0, "desc": "Defeat Brute Champions"},
	{"type": "kill", "target": "mage", "required": 3, "count": 0, "desc": "Defeat Goblin Mages"}
]
var current_objective_index: int = 0

var enemies_root: Node2D = null
var drops_root: Node2D = null
var player: CharacterBody2D = null
var canvas_layer: CanvasLayer = null

var objective_label: Label = null
var banner_label: Label = null
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

	# Setup SFX Player
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "ObjectiveSFXPlayer"
	add_child(sfx_player)

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
	
	# Load progress
	var progress = GameState.get_map_progress(objective_name)
	current_objective_index = progress.get("index", 0)
	if current_objective_index < objectives.size():
		objectives[current_objective_index]["count"] = progress.get("count", 0)
		
	_update_objective_label()
	await get_tree().process_frame
	_apply_difficulty()


func _process(_delta: float) -> void:
	_update_key_arrow()


func _unhandled_input(event: InputEvent) -> void:
	# Debug skip objective (F2 key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_cheat_complete_objective()
		return

	if not completion_panel_open:
		return
	if event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		completion_panel_open = false
		if completion_panel != null:
			completion_panel.visible = false
		get_tree().paused = false
		process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _on_enemy_added(node: Node) -> void:
	await get_tree().process_frame
	if is_instance_valid(node):
		_try_connect_enemy(node)


func _connect_existing_enemies() -> void:
	if enemies_root == null:
		return
	for enemy in enemies_root.get_children():
		_try_connect_enemy(enemy)


func _try_connect_enemy(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("defeated"):
		return
	# Use bound callable and check against the same callable to avoid duplicate connects.
	var callback: Callable = Callable(self, "_on_enemy_defeated").bind(enemy)
	if not enemy.defeated.is_connected(callback):
		enemy.defeated.connect(callback)


func _on_enemy_defeated(world_position: Vector2, _xp_value: int, _xp_tier: String, enemy: Node) -> void:
	if objective_complete or objectives_finished or current_objective_index >= objectives.size():
		return
		
	kill_count += 1
	var current_obj = objectives[current_objective_index]
	var match_found = false
	var target: String = str(current_obj.get("target", "")).to_lower()
	var archetype: String = ""
	if enemy != null and enemy.has_method("get_enemy_archetype"):
		archetype = str(enemy.call("get_enemy_archetype")).to_lower()
	var enemy_name: String = enemy.name.to_lower() if enemy != null else ""
	
	if target == "any":
		match_found = true
	elif target == "brute" and ("brute" in archetype or "brute" in enemy_name):
		match_found = true
	elif target == "mage" and ("mage" in archetype or "mage" in enemy_name):
		match_found = true
	elif target == "sword" and ("sword" in archetype or "sword" in enemy_name):
		match_found = true
		
	if match_found:
		current_obj["count"] += 1
		objectives[current_objective_index] = current_obj
		_update_objective_label()
		# Save progress
		GameState.save_map_progress(objective_name, current_objective_index, current_obj["count"])
		_play_sfx(sfx_enemy_match)
		
		if current_obj["count"] >= current_obj["required"]:
			_complete_current_objective(world_position)

func _complete_current_objective(drop_pos: Vector2) -> void:
	current_objective_index += 1
	# Save progress
	GameState.save_map_progress(objective_name, current_objective_index, 0)
	
	# Play SFX
	if current_objective_index >= objectives.size():
		_play_sfx(sfx_all_complete)
	else:
		_play_sfx(sfx_step_complete)
	
	# Show banner
	_show_objective_complete_banner()
	
	# Give reward
	GameState.add_coins(50)
	
	if current_objective_index >= objectives.size():
		objectives_finished = true
		GameState.add_coins(150) # Bonus for full completion
		if not key_spawned and objective_name != "Desert":
			_spawn_golden_key_deferred.call_deferred(drop_pos)
			
		# Trigger boss if Desert map
		if objective_name == "Desert":
			var game_root = get_tree().current_scene
			if game_root != null and game_root.has_method("_try_spawn_king_goblin_boss"):
				game_root.call_deferred("_try_spawn_king_goblin_boss")
				_play_sfx(sfx_boss_spawn)
	else:
		_update_objective_label()
		# Spawn mini-boss on step 3 (index 2)
		if current_objective_index == 2:
			_spawn_mini_boss(drop_pos)

func _show_objective_complete_banner() -> void:
	if banner_label == null:
		return
	banner_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(banner_label, "modulate:a", 0.0, 2.0).set_delay(1.0)

func _spawn_mini_boss(pos: Vector2) -> void:
	if BRUTE_SCENE == null or enemies_root == null:
		return
	var brute = BRUTE_SCENE.instantiate() as CharacterBody2D
	brute.global_position = pos
	enemies_root.add_child(brute)
	brute.scale = Vector2(1.5, 1.5)
	brute.name = "MiniBoss_Brute"

func _cheat_complete_objective() -> void:
	# Skip ALL objectives
	current_objective_index = objectives.size() - 1
	var current_obj = objectives[current_objective_index]
	current_obj["count"] = current_obj["required"]
	_complete_current_objective(player.global_position if player else Vector2.ZERO)
	print("Debug: Skipped ALL objectives.")


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
	if objective_complete or not objectives_finished or pickup_type != GOLDEN_KEY_TYPE:
		return
	objective_complete = true
	_unlock_next_map()
	_update_objective_label()
	_update_key_arrow()
	var objectives_cleared: int = objectives.size()
	_show_completion_panel(
		"Map Complete!",
		"Total Kills: %d\nObjectives Cleared: %d" % [kill_count, objectives_cleared]
	)


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
	_clear_stale_objective_ui()
	# Background Panel for Quest Tracker
	var tracker_bg = ColorRect.new()
	tracker_bg.name = "ObjectiveUI_TrackerBg"
	tracker_bg.color = Color(0, 0, 0, 0.4) # Semi-transparent black
	tracker_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tracker_bg.offset_left = -420
	tracker_bg.offset_top = 110
	tracker_bg.offset_right = -4
	tracker_bg.offset_bottom = 230
	tracker_bg.z_index = 89
	canvas_layer.add_child(tracker_bg)

	objective_label = Label.new()
	objective_label.name = "ObjectiveUI_TrackerLabel"
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.offset_left = -400
	objective_label.offset_top = 120
	objective_label.offset_right = -14
	objective_label.offset_bottom = 220
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.z_index = 90
	canvas_layer.add_child(objective_label)
	
	# Banner Label for Objective Complete
	banner_label = Label.new()
	banner_label.name = "ObjectiveUI_BannerLabel"
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 36)
	banner_label.text = "OBJECTIVE COMPLETE!"
	banner_label.modulate.a = 0.0 # Start invisible
	banner_label.z_index = 100
	canvas_layer.add_child(banner_label)

	key_arrow_label = Label.new()
	key_arrow_label.name = "ObjectiveUI_KeyArrow"
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
	completion_panel.name = "ObjectiveUI_CompletionPanel"
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
	completion_hint_label.text = "Tap or press any key to return to Lobby"
	completion_hint_label.modulate = Color(0.92, 0.92, 0.92, 1.0)
	text_vbox.add_child(completion_hint_label)


func _clear_stale_objective_ui() -> void:
	if canvas_layer == null:
		return
	for child in canvas_layer.get_children():
		if child == null:
			continue
		if String(child.name).begins_with("ObjectiveUI_"):
			child.queue_free()
			continue
		# Cleanup legacy leaked nodes created before naming was added.
		if child is Label:
			var label := child as Label
			var text_value: String = label.text
			if "Objective Complete!" in text_value or "Obj (" in text_value or text_value == ">":
				label.queue_free()
		elif child is ColorRect:
			var rect := child as ColorRect
			if abs(rect.offset_left + 420.0) < 0.1 and abs(rect.offset_top - 110.0) < 0.1 and abs(rect.offset_bottom - 230.0) < 0.1:
				rect.queue_free()


func _update_objective_label() -> void:
	if objective_label == null:
		return
	if objective_complete:
		objective_label.text = "%s Objective Complete!" % objective_name
	elif key_spawned:
		objective_label.text = "Golden key dropped! Pick it up."
	elif current_objective_index < objectives.size():
		var current_obj = objectives[current_objective_index]
		objective_label.text = "%s Obj (%d/%d): %s (%d/%d)" % [
			objective_name, 
			current_objective_index + 1, 
			objectives.size(),
			current_obj["desc"],
			current_obj["count"],
			current_obj["required"]
		]
	else:
		objective_label.text = "%s Objective: Defeat goblins %d / %d" % [objective_name, kill_count, kills_required]


func get_current_objective_desc() -> String:
	if objective_complete:
		return "All Objectives Complete!"
	if current_objective_index < objectives.size():
		var obj = objectives[current_objective_index]
		return obj["desc"] + " (" + str(obj["count"]) + "/" + str(obj["required"]) + ")"
	return "No Objectives"


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


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player = get_node_or_null("ObjectiveSFXPlayer") as AudioStreamPlayer
	if player != null:
		player.stream = stream
		player.play()
