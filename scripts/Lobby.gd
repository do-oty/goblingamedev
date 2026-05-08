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
@onready var historian_area: Area2D = $HistorianNpc/NpcArea
@onready var coin_label: Label = $"CanvasLayer/HUD/CoinLabel"
@onready var hint_label: Label = $"CanvasLayer/HUD/HintLabel"
@onready var panel: PanelContainer = $"CanvasLayer/HUD/UpgradePanel"
@onready var panel_title: Label = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/Title"
@onready var button_hp: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/HpButton"
@onready var button_speed: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/SpeedButton"
@onready var button_luck: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/LuckButton"
@onready var button_dash: Button = $"CanvasLayer/HUD/UpgradePanel/Margin/VBox/DashButton"

var player_in_npc_range: bool = false
var player_in_historian_range: bool = false
var history_panel_visible: bool = false


func _ready() -> void:
	get_tree().paused = false
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
	historian_area.body_entered.connect(_on_historian_body_entered)
	historian_area.body_exited.connect(_on_historian_body_exited)
	button_hp.pressed.connect(_on_hp_upgrade_pressed)
	button_speed.pressed.connect(_on_speed_upgrade_pressed)
	button_luck.pressed.connect(_on_luck_upgrade_pressed)
	button_dash.pressed.connect(_on_dash_upgrade_pressed)
	
	for btn in [button_hp, button_speed, button_luck, button_dash]:
		_style_web_button(btn)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	_refresh_ui()


func _process(_delta: float) -> void:
	if player_in_historian_range:
		hint_label.visible = true
		hint_label.text = "Press E to view run history"
	elif player_in_npc_range and not panel.visible:
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
	if key_event.keycode == KEY_E and player_in_historian_range:
		history_panel_visible = not history_panel_visible
		if global_hud != null and global_hud.has_method("set_lobby_last_run_text"):
			if history_panel_visible:
				global_hud.call("set_lobby_last_run_text", GameState.get_run_history_text())
			else:
				global_hud.call("set_lobby_last_run_text", GameState.get_last_run_summary_text())
		get_viewport().set_input_as_handled()
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


func _on_historian_body_entered(body: Node) -> void:
	if body != player:
		return
	player_in_historian_range = true


func _on_historian_body_exited(body: Node) -> void:
	if body != player:
		return
	player_in_historian_range = false
	history_panel_visible = false
	if global_hud != null and global_hud.has_method("set_lobby_last_run_text"):
		global_hud.call("set_lobby_last_run_text", GameState.get_last_run_summary_text())


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
	if player != null:
		player.set_physics_process(not is_open)
		if is_open:
			player.velocity = Vector2.ZERO


func _deferred_change_scene(destination_scene: String) -> void:
	get_tree().change_scene_to_file(destination_scene)
func _style_web_button(btn: Button, is_accent: bool = false) -> void:
	if btn == null: return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.15, 0.22, 0.95) if not is_accent else Color(0.2, 0.4, 0.8, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.4, 0.7, 1.0, 0.3)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.95) if not is_accent else Color(0.3, 0.5, 0.9, 0.95)
	hover.border_color = Color(0.5, 0.8, 1.0, 0.8)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.9))
	
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
