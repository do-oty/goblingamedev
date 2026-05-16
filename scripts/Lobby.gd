extends Node2D

const FOREST_SCENE_PATH: String = "res://scenes/maps/ForestMap.tscn"
const DESERT_SCENE_PATH: String = "res://scenes/maps/DesertMap.tscn"
const SNOW_SCENE_PATH: String = "res://scenes/maps/SnowMap.tscn"
const INTERACTABLE_MESSAGE_SCENE = preload("res://scenes/InteractableMessage.tscn")


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
var button_crit: Button
var button_regen: Button
var stats_label: Label


func _ready() -> void:
	get_tree().paused = false
	
	# Delete Historian NPC if it exists
	var historian = get_node_or_null("HistorianNpc")
	if historian:
		historian.queue_free()
		
	_setup_building_trigger()
		
	if global_hud != null and global_hud.has_method("set_ui_mode"):
		global_hud.call("set_ui_mode", "lobby")
	if global_hud != null and global_hud.has_method("set_lobby_last_run_text"):
		global_hud.call("set_lobby_last_run_text", GameState.get_last_run_summary_text())
	if player != null and player.has_method("set_lobby_mode"):
		player.call("set_lobby_mode", true)
	if panel != null: panel.visible = false
	if hint_label != null: hint_label.visible = false
	
	# Ensure CanvasLayer is visible in lobby
	var cl: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
	if cl != null:
		cl.visible = true
		
	# Add objectives label
	var obj_label := Label.new()
	obj_label.name = "LobbyObjectivesLabel"
	cl.add_child(obj_label)
	obj_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	obj_label.offset_left = -300
	obj_label.offset_right = -20
	obj_label.offset_top = 100
	obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	obj_label.add_theme_font_size_override("font_size", 18)
	obj_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	obj_label.add_theme_constant_override("shadow_offset_x", 1)
	obj_label.add_theme_constant_override("shadow_offset_y", 1)
	obj_label.add_theme_constant_override("shadow_outline_size", 1)
	
	_update_lobby_objectives(obj_label)
	
	# Add NPC hint label
	var npc_hint := Label.new()
	npc_hint.name = "NpcHint"
	npc_hint.text = "Press E to talk"
	npc_hint.visible = false
	$UpgradeNpc.add_child(npc_hint)
	npc_hint.position = Vector2(102 - 50, -83 - 40)
	npc_hint.add_theme_font_size_override("font_size", 14)
	npc_hint.add_theme_color_override("font_shadow_color", Color(0,0,0,1))
	npc_hint.add_theme_constant_override("shadow_offset_x", 1)
	npc_hint.add_theme_constant_override("shadow_offset_y", 1)
	
	forest_portal_area.body_entered.connect(_on_portal_body_entered.bind(FOREST_SCENE_PATH))
	desert_portal_area.body_entered.connect(_on_portal_body_entered.bind(DESERT_SCENE_PATH))
	snow_portal_area.body_entered.connect(_on_portal_body_entered.bind(SNOW_SCENE_PATH))
	npc_area.body_entered.connect(_on_npc_body_entered)
	npc_area.body_exited.connect(_on_npc_body_exited)
	
	# Add solid collisions for NPCs so player doesn't walk through them
	_add_solid_collision($UpgradeNpc, Vector2(0, 10), 30)
	var frog = get_node_or_null("frog")
	if frog:
		_add_solid_collision(frog, Vector2(0, 10), 40)
	
	if global_hud != null and global_hud.has_signal("interact_pressed"):
		global_hud.interact_pressed.connect(_on_mobile_interact_pressed)
	
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
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
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
	
	button_crit = Button.new()
	button_crit.name = "CritButton"
	grid.add_child(button_crit)
	_style_web_button(button_crit)
	button_crit.pressed.connect(func(): _try_buy_upgrade("crit_chance", 35, 5))
	
	button_regen = Button.new()
	button_regen.name = "RegenButton"
	grid.add_child(button_regen)
	_style_web_button(button_regen)
	button_regen.pressed.connect(func(): _try_buy_upgrade("health_regen", 40, 5))
	
	var button_close := Button.new()
	button_close.text = "Close"
	vbox.add_child(button_close)
	_style_web_button(button_close)
	button_close.pressed.connect(func(): _set_upgrade_panel_visible(false))
	
	for btn in [button_hp, button_speed, button_luck, button_dash, button_damage, button_atk_speed, button_crit, button_regen]:
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(300, 100) # Card size
		
	_refresh_ui()



func _process(_delta: float) -> void:
	var npc_hint = $UpgradeNpc.get_node_or_null("NpcHint")
	if player_in_npc_range and not panel.visible:
		if npc_hint:
			npc_hint.visible = true
			npc_hint.z_index = 10
			npc_hint.position = Vector2(0, -50) # Position it above the NPC
	else:
		if npc_hint: npc_hint.visible = false
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
	var npc_hint = $UpgradeNpc.get_node_or_null("NpcHint")
	if npc_hint: npc_hint.visible = true
	
	if global_hud != null and global_hud.has_method("set_mobile_interact_visible"):
		global_hud.call("set_mobile_interact_visible", true)


func _on_npc_body_exited(body: Node) -> void:
	if body != player:
		return
	player_in_npc_range = false
	var npc_hint = $UpgradeNpc.get_node_or_null("NpcHint")
	if npc_hint: npc_hint.visible = false
	_set_upgrade_panel_visible(false)
	
	if global_hud != null and global_hud.has_method("set_mobile_interact_visible"):
		global_hud.call("set_mobile_interact_visible", false)

func _on_mobile_interact_pressed() -> void:
	if player_in_npc_range:
		_set_upgrade_panel_visible(not panel.visible)


func _setup_building_trigger() -> void:
	# If it's already in the scene, make sure it has the InteractableMessage script
	if building_trigger != null:
		print("BuildingTrigger found in scene. Ensuring InteractableMessage script...")
		var script = load("res://scripts/InteractableMessage.gd")
		if building_trigger.get_script() != script:
			building_trigger.set_script(script)
			# Manually trigger ready if we just set the script
			if building_trigger.has_method("_ready"):
				building_trigger._ready()
		
		# Now we can safely set properties
		if "message_text" in building_trigger:
			building_trigger.message_text = "Don't come back until the job's done!"
		return

	if INTERACTABLE_MESSAGE_SCENE:
		var msg = INTERACTABLE_MESSAGE_SCENE.instantiate()
		msg.name = "BuildingTrigger"
		msg.message_text = "Don't come back until the job's done!"
		msg.position = Vector2(0, -150)
		add_child(msg)
		building_trigger = msg
		print("InteractableMessage BuildingTrigger created at: ", msg.position)
	else:
		# Fallback to old logic if scene not found
		var bldg_area = Area2D.new()
		bldg_area.name = "BuildingTrigger"
		add_child(bldg_area)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(200, 200)
		collision.shape = shape
		bldg_area.add_child(collision)
		bldg_area.position = Vector2(0, -150) 
		# If it's the fallback, we need to handle the signal manually
		if not bldg_area.body_entered.is_connected(_on_building_trigger_body_entered):
			bldg_area.body_entered.connect(_on_building_trigger_body_entered)
		building_trigger = bldg_area
		print("Fallback BuildingTrigger created at: ", bldg_area.position)


func _on_building_trigger_body_entered(body: Node) -> void:
	if body == player:
		if hint_label:
			hint_label.visible = true
			hint_label.text = "Don't come back until the job's done!"
			var t = create_tween()
			t.tween_property(hint_label, "modulate:a", 1.0, 0.2).from(0.0)
			t.tween_property(hint_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
			t.tween_callback(func(): hint_label.visible = false)
		if player.has_method("apply_launch_force"):
			player.call("apply_launch_force", building_trigger.global_position, 350.0, 30.0, 0.3)


func _add_solid_collision(parent: Node2D, offset: Vector2, radius: float) -> void:
	if parent == null: return
	
	# Check if a StaticBody2D already exists
	var body = parent.get_node_or_null("SolidBody") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "SolidBody"
		parent.add_child(body)
		
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = radius
		collision.shape = shape
		body.add_child(collision)
		body.position = offset
		print("Added solid collision to: ", parent.name)


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
	if button_crit:
		_refresh_upgrade_button(button_crit, "crit_chance", "Critical", "Increases critical strike chance.", 35, 5)
	if button_regen:
		_refresh_upgrade_button(button_regen, "health_regen", "Regeneration", "Passive health regeneration.", 40, 5)
		
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
	if panel == null:
		return
	panel.visible = is_open
	if is_open:
		var shop_layer = get_node_or_null("ShopLayer")
		if shop_layer == null:
			shop_layer = CanvasLayer.new()
			shop_layer.layer = 105 # Higher than HUD (100)
			shop_layer.name = "ShopLayer"
			add_child(shop_layer)
			panel.get_parent().remove_child(panel)
			shop_layer.add_child(panel)
			
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.05, 0.9) # Barely translucent black
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.2, 0.2, 1)
		style.shadow_size = 15
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_offset = Vector2(0, 5)
		panel.add_theme_stylebox_override("panel", style)
		
	var cl = get_node_or_null("CanvasLayer")
	if cl:
		var obj_label = cl.get_node_or_null("LobbyObjectivesLabel")
		if obj_label:
			obj_label.visible = not is_open
		
	if player != null:
		player.set_physics_process(not is_open)
		if is_open:
			player.velocity = Vector2.ZERO


func _deferred_change_scene(destination_scene: String) -> void:
	get_tree().change_scene_to_file(destination_scene)
func _style_web_button(btn: Button, is_accent: bool = false) -> void:
	if btn == null: return
	var normal := StyleBoxFlat.new()
	# Bare button: transparent background
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_width_left = 0
	normal.border_width_top = 0
	normal.border_width_right = 0
	normal.border_width_bottom = 0
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.shadow_size = 2
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_offset = Vector2(0, 1)
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.2, 0.2, 0.3) # Subtle hover background
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	
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


func _update_lobby_objectives(label: Label) -> void:
	if label == null:
		return
	var text: String = "Objectives:\n"
	
	# Forest
	var forest_prog: Dictionary = GameState.get_map_progress("Forest")
	var forest_idx: int = forest_prog.get("index", 0)
	var forest_objectives: Array[String] = [
		"Defeat any goblins",
		"Defeat Goblin Swordsmen",
		"Defeat more goblins",
		"Defeat a Brute Champion",
		"Defeat Goblin Mages"
	]
	if forest_idx < forest_objectives.size():
		text += "Forest: %s\n" % forest_objectives[forest_idx]
	else:
		text += "Forest: Complete!\n"
		
	# Snow
	if GameState.is_snow_map_unlocked():
		var snow_prog: Dictionary = GameState.get_map_progress("Snow")
		var snow_idx: int = snow_prog.get("index", 0)
		var snow_objectives: Array[String] = [
			"Defeat any goblins",
			"Defeat Goblin Mages",
			"Defeat Goblin Swordsmen",
			"Defeat more goblins",
			"Defeat Brute Champions",
			"Defeat Goblin Mages"
		]
		if snow_idx < snow_objectives.size():
			text += "Snow: %s\n" % snow_objectives[snow_idx]
		else:
			text += "Snow: Complete!\n"
			
	# Desert
	if GameState.is_desert_map_unlocked():
		var desert_prog: Dictionary = GameState.get_map_progress("Desert")
		var desert_idx: int = desert_prog.get("index", 0)
		var desert_objectives: Array[String] = [
			"Defeat any goblins",
			"Defeat Goblin Swordsmen",
			"Defeat Goblin Mages",
			"Defeat Brute Champions",
			"Defeat more goblins",
			"Defeat Goblin Swordsmen",
			"Defeat Goblin Mages",
			"Prepare for the Boss!"
		]
		if desert_idx < desert_objectives.size():
			text += "Desert: %s\n" % desert_objectives[desert_idx]
		else:
			text += "Desert: Complete!\n"
			
	label.text = text
