extends Node2D

const FOREST_SCENE_PATH: String = "res://scenes/maps/ForestMap.tscn"
const DESERT_SCENE_PATH: String = "res://scenes/maps/DesertMap.tscn"
const SNOW_SCENE_PATH: String = "res://scenes/maps/SnowMap.tscn"

@onready var player: CharacterBody2D = $Player
@onready var global_hud: Control = $"CanvasLayer/HUD"
@onready var forest_portal_area: Area2D = $PortalForest/PortalArea
@onready var desert_portal_area: Area2D = $PortalDesert/PortalArea
@onready var snow_portal_area: Area2D = $PortalSnow/PortalArea
@onready var npc_area: Area2D = $UpgradeNpc/NpcArea
@onready var coin_label: Label = $"CanvasLayer/HUD/CoinLabel"
@onready var hint_label: Label = $"CanvasLayer/HUD/HintLabel"
@onready var panel: PanelContainer = $"CanvasLayer/HUD/UpgradePanel"
@onready var panel_title: Label = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/Title"
@onready var button_hp: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/HpButton"
@onready var button_speed: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/SpeedButton"
@onready var button_luck: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/LuckButton"
@onready var button_dash: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/DashButton"
@onready var vbox: VBoxContainer = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox"
@onready var building_trigger: Area2D = get_node_or_null("BuildingTrigger")

var player_in_npc_range: bool = false
var button_damage: Button
var button_atk_speed: Button
var stats_label: Label


func _ready() -> void:
	get_tree().paused = false
	
	# Delete Historian NPC if it exists
	var historian = get_node_or_null("HistorianNpc")
	if historian:
		historian.queue_free()
		
	if global_hud != null and global_hud.has_method("set_ui_mode"):
		global_hud.call("set_ui_mode", "lobby")
	if global_hud != null and global_hud.has_method("set_lobby_last_run_text"):
		global_hud.call("set_lobby_last_run_text", GameState.get_last_run_summary_text())
	if player != null and player.has_method("set_lobby_mode"):
		player.call("set_lobby_mode", true)
	panel.visible = false
	hint_label.visible = false
	forest_portal_area.body_entered.connect(_on_portal_body_entered.bind(FOREST_SCENE_PATH))
	desert_portal_area.body_entered.connect(_on_portal_body_entered.bind(DESERT_SCENE_PATH))
	snow_portal_area.body_entered.connect(_on_portal_body_entered.bind(SNOW_SCENE_PATH))
	npc_area.body_entered.connect(_on_npc_body_entered)
	npc_area.body_exited.connect(_on_npc_body_exited)
	
	button_hp.pressed.connect(_on_hp_upgrade_pressed)
	button_speed.pressed.connect(_on_speed_upgrade_pressed)
	button_luck.pressed.connect(_on_luck_upgrade_pressed)
	button_dash.pressed.connect(_on_dash_upgrade_pressed)
	
	# Create dynamic UI elements
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	vbox.move_child(stats_label, 1) # Put it after title
	
	# Create a GridContainer for upgrades
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 40)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	
	# Reparent existing buttons to grid
	vbox.remove_child(button_hp)
	grid.add_child(button_hp)
	vbox.remove_child(button_speed)
	grid.add_child(button_speed)
	vbox.remove_child(button_luck)
	grid.add_child(button_luck)
	vbox.remove_child(button_dash)
	grid.add_child(button_dash)
	
	button_damage = Button.new()
	button_damage.name = "DamageButton"
	grid.add_child(button_damage)
	_style_web_button(button_damage)
	button_damage.pressed.connect(func(): _try_buy_upgrade("damage", 30, 10))
	
	button_atk_speed = Button.new()
	button_atk_speed.name = "AtkSpeedButton"
	grid.add_child(button_atk_speed)
	_style_web_button(button_atk_speed)
	button_atk_speed.pressed.connect(func(): _try_buy_upgrade("attack_speed", 28, 10))
	
	var button_close := Button.new()
	button_close.text = "Close"
	vbox.add_child(button_close)
	_style_web_button(button_close)
	button_close.pressed.connect(func(): _set_upgrade_panel_visible(false))
	
	for btn in [button_hp, button_speed, button_luck, button_dash, button_damage, button_atk_speed]:
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(300, 100) # Card size
		
	_refresh_ui()
	
	if building_trigger:
		building_trigger.body_entered.connect(_on_building_trigger_body_entered)
		print("Using scene BuildingTrigger at: ", building_trigger.global_position)
		
		# Ensure it has a collision shape
		var has_shape := false
		for child in building_trigger.get_children():
			if child is CollisionShape2D:
				has_shape = true
				break
				
		var shape_size := Vector2(200, 200)
		if not has_shape:
			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = shape_size
			collision.shape = shape
			building_trigger.add_child(collision)
			print("Added fallback collision shape to scene BuildingTrigger.")
			
		# Add visual helper
		var visual = ColorRect.new()
		visual.color = Color(0, 0.8, 0.2, 0.6) # Bright green
		visual.size = shape_size
		visual.position = -shape_size / 2
		building_trigger.add_child(visual)
		print("Added green visual helper to scene BuildingTrigger.")
	else:
		_setup_building_trigger()


func _process(_delta: float) -> void:
	if player_in_npc_range and not panel.visible:
		hint_label.visible = true
		hint_label.text = "Press E to talk"
	else:
		hint_label.visible = false
	_refresh_coins()
	_refresh_lobby_dash_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_E and player_in_npc_range:
		_set_upgrade_panel_visible(not panel.visible)
		get_viewport().set_input_as_handled()


func _on_portal_body_entered(body: Node, destination_scene: String) -> void:
	if body != player:
		return
	_set_upgrade_panel_visible(false)
	call_deferred("_deferred_change_scene", destination_scene)


func _on_npc_body_entered(body: Node) -> void:
	if body != player:
		return
	player_in_npc_range = true


func _on_npc_body_exited(body: Node) -> void:
	if body != player:
		return
	player_in_npc_range = false
	_set_upgrade_panel_visible(false)


func _setup_building_trigger() -> void:
	var bldg_area = Area2D.new()
	bldg_area.name = "BuildingTrigger"
	add_child(bldg_area)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200) # Bigger
	collision.shape = shape
	bldg_area.add_child(collision)
	
	# Position it in the lobby (closer to spawn)
	bldg_area.position = Vector2(0, -150) 
	
	# Visual helper
	var visual = ColorRect.new()
	visual.color = Color(1, 0, 0, 0.7) # Brighter
	visual.size = shape.size
	visual.position = -shape.size / 2
	bldg_area.add_child(visual)
	
	print("Fallback BuildingTrigger created at: ", bldg_area.position)
	
	bldg_area.body_entered.connect(_on_building_trigger_body_entered)


func _on_building_trigger_body_entered(body: Node) -> void:
	if body == player:
		# Push player (real knockback)
		var trigger_node = get_node_or_null("BuildingTrigger")
		var trigger_pos = trigger_node.global_position if trigger_node else Vector2.ZERO
		
		if player.has_method("apply_launch_force"):
			# Push with strength 350, height 30, duration 0.3
			player.call("apply_launch_force", trigger_pos, 350.0, 30.0, 0.3)
		else:
			# Fallback if method doesn't exist
			var push_dir = (player.global_position - trigger_pos).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = Vector2(0, 1)
			player.global_position += push_dir * 80.0
		
		# Show message
		hint_label.visible = true
		hint_label.text = "Dont come back until the hob's done!"
		# Hide after delay
		get_tree().create_timer(2.0).timeout.connect(func():
			hint_label.visible = false
		)


func _refresh_stats_label() -> void:
	if stats_label == null: return
	var hp_lv = GameState.get_upgrade_level("max_health")
	var spd_lv = GameState.get_upgrade_level("move_speed")
	var lck_lv = GameState.get_upgrade_level("luck")
	var dsh_lv = GameState.get_upgrade_level("dash_mastery")
	var dmg_lv = GameState.get_upgrade_level("damage")
	var atk_lv = GameState.get_upgrade_level("attack_speed")
	
	stats_label.text = "Current Base Stats\nVitality: Lv %d | Swiftness: Lv %d\nFortune: Lv %d | Agility: Lv %d\nStrength: Lv %d | Haste: Lv %d" % [hp_lv, spd_lv, lck_lv, dsh_lv, dmg_lv, atk_lv]


func _on_hp_upgrade_pressed() -> void:
	_try_buy_upgrade("max_health", 22, 10)


func _on_speed_upgrade_pressed() -> void:
	_try_buy_upgrade("move_speed", 24, 10)


func _on_luck_upgrade_pressed() -> void:
	_try_buy_upgrade("luck", 26, 8)


func _on_dash_upgrade_pressed() -> void:
	_try_buy_upgrade("dash_mastery", 34, 8)


func _try_buy_upgrade(upgrade_id: String, base_cost: int, max_level: int) -> void:
	var level: int = GameState.get_upgrade_level(upgrade_id)
	if level >= max_level:
		panel_title.text = "Upgrade maxed."
		return
	var cost: int = base_cost + (level * 12)
	if GameState.buy_upgrade(upgrade_id, cost, max_level):
		panel_title.text = "Purchased."
	else:
		panel_title.text = "Not enough coins."
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_coins()
	_refresh_upgrade_button(button_hp, "max_health", "Vitality", "Increases your maximum health capacity.", 22, 10)
	_refresh_upgrade_button(button_speed, "move_speed", "Swiftness", "Run faster across all maps.", 24, 10)
	_refresh_upgrade_button(button_luck, "luck", "Fortune", "Find better items and more coins.", 26, 8)
	_refresh_upgrade_button(button_dash, "dash_mastery", "Agility", "Reduces dash cooldown and increases i-frames.", 34, 8)
	
	if button_damage:
		_refresh_upgrade_button(button_damage, "damage", "Strength", "Increases your attack damage.", 30, 10)
	if button_atk_speed:
		_refresh_upgrade_button(button_atk_speed, "attack_speed", "Haste", "Increases attack speed.", 28, 10)
		
	_refresh_stats_label()


func _refresh_upgrade_button(btn: Button, id: String, title: String, desc: String, base_cost: int, max_lv: int) -> void:
	var lv: int = GameState.get_upgrade_level(id)
	var cost: int = base_cost + (lv * 12)
	var status: String = "MAXED" if lv >= max_lv else "Cost: %d" % cost
	btn.text = "%s (Lv.%d/%d)\n%s\n%s" % [title, lv, max_lv, desc, status]
	btn.disabled = (lv >= max_lv)


func _refresh_coins() -> void:
	coin_label.text = "Coins: %d" % GameState.get_coins()


func _refresh_lobby_dash_ui() -> void:
	if global_hud == null or not global_hud.has_method("update_combat_bars") or player == null:
		return
	var dash_cd_left: float = player.get_dash_cooldown_remaining() if player.has_method("get_dash_cooldown_remaining") else 0.0
	var dash_cd_total: float = player.get_dash_cooldown_total() if player.has_method("get_dash_cooldown_total") else 1.0
	var dash_ready_count: int = 1 if dash_cd_left <= 0.01 else 0
	global_hud.call(
		"update_combat_bars",
		1,
		1,
		0,
		1,
		dash_ready_count,
		1,
		dash_cd_left,
		dash_cd_total,
		""
	)


func _set_upgrade_panel_visible(is_open: bool) -> void:
	panel.visible = is_open
	if is_open:
		panel.move_to_front()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var black_style := StyleBoxFlat.new()
		black_style.bg_color = Color(0, 0, 0, 1)
		panel.add_theme_stylebox_override("panel", black_style)
		
	if player != null:
		player.set_physics_process(not is_open)
		if is_open:
			player.velocity = Vector2.ZERO


func _deferred_change_scene(destination_scene: String) -> void:
	get_tree().change_scene_to_file(destination_scene)
func _style_web_button(btn: Button, is_accent: bool = false) -> void:
	if btn == null: return
	var normal := StyleBoxFlat.new()
	# Dark gray button so it stands out on black background
	normal.bg_color = Color(0.1, 0.1, 0.1, 1)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.3, 0.3, 1)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.2, 1)
	hover.border_color = Color(0.5, 0.5, 0.5, 1)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	btn.pivot_offset = btn.size / 2.0
	if not btn.item_rect_changed.is_connected(func(): btn.pivot_offset = btn.size / 2.0):
		btn.item_rect_changed.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.button_down.connect(func():
		var t = btn.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)
	)
	btn.button_up.connect(func():
		var t = btn.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
	)
