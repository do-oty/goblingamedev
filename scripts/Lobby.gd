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

var player_in_npc_range: bool = false


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
	button_hp.pressed.connect(_on_hp_upgrade_pressed)
	button_speed.pressed.connect(_on_speed_upgrade_pressed)
	button_luck.pressed.connect(_on_luck_upgrade_pressed)
	button_dash.pressed.connect(_on_dash_upgrade_pressed)
	_refresh_ui()


func _process(_delta: float) -> void:
	if player_in_npc_range and not panel.visible:
		hint_label.visible = true
		hint_label.text = "Press E to talk"
	else:
		hint_label.visible = false
	_refresh_coins()


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
	var hp_level: int = GameState.get_upgrade_level("max_health")
	var speed_level: int = GameState.get_upgrade_level("move_speed")
	var luck_level: int = GameState.get_upgrade_level("luck")
	var dash_level: int = GameState.get_upgrade_level("dash_mastery")
	button_hp.text = "Max HP Lv.%d (cost %d)" % [hp_level, 22 + hp_level * 12]
	button_speed.text = "Move Speed Lv.%d (cost %d)" % [speed_level, 24 + speed_level * 12]
	button_luck.text = "Luck Lv.%d (cost %d)" % [luck_level, 26 + luck_level * 12]
	button_dash.text = "Dash Mastery Lv.%d (cost %d)" % [dash_level, 34 + dash_level * 12]


func _refresh_coins() -> void:
	coin_label.text = "Coins: %d" % GameState.get_coins()


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
