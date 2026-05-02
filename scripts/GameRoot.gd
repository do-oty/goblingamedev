extends Node2D

const RUN_DURATION_SECONDS: float = 15.0 * 60.0
const START_SPAWN_INTERVAL: float = 1.35
const END_SPAWN_INTERVAL: float = 0.07
const START_MAX_ENEMIES: int = 55
const END_MAX_ENEMIES: int = 1200
const START_MIN_ENEMIES_ALIVE: int = 6
const END_MIN_ENEMIES_ALIVE: int = 760
const START_SPAWN_BURST: int = 2
const END_SPAWN_BURST: int = 20
const SPAWN_DISTANCE_MIN: float = 360.0
const SPAWN_DISTANCE_MAX: float = 760.0
const BASE_XP_TO_LEVEL: int = 5
const XP_GROWTH_PER_LEVEL: int = 3
const HORDE_EVENT_MIN_SECONDS: float = 16.0
const HORDE_EVENT_MAX_SECONDS: float = 30.0
const HORDE_GROUP_MIN: int = 24
const HORDE_GROUP_MAX: int = 90
const HORDE_WARNING_DURATION: float = 1.8
const HORDE_EXTRA_WARNING_BASE_CHANCE: float = 0.62
const HORDE_EXTRA_WARNING_MAX_CHANCE: float = 0.88
const HORDE_MAX_WARNING_BURST: int = 3
const ELITE_START_TIME_SECONDS: float = 120.0
const ELITE_BASE_SPAWN_CHANCE: float = 0.04
const ELITE_MAX_SPAWN_CHANCE: float = 0.28
const ELITE_EVENT_MIN_INTERVAL: float = 10.0
const ELITE_EVENT_MAX_INTERVAL: float = 28.0
const SWORD_UNLOCK_SECONDS: float = 75.0
const FIRE_MAGE_UNLOCK_SECONDS: float = 240.0
const ELECTRIC_MAGE_UNLOCK_SECONDS: float = 420.0
const TANK_ENEMY_UNLOCK_SECONDS: float = 120.0
const COIN_DROP_CHANCE: float = 0.18
const HEALTH_DROP_CHANCE: float = 0.012
const HEALTH_DROP_HEAL: int = 22
const LOBBY_SCENE_PATH: String = "res://scenes/maps/LobbyMap.tscn"
const FLOOR_FILL_INTERVAL: float = 0.18
const EARLY_GAME_EASY_SECONDS: float = 120.0

@onready var tree_layer = $trees
@onready var player = $Player
@onready var global_hud: Control = $"CanvasLayer/HUD"
@onready var enemies_root: Node2D = $Enemies
@onready var orbs_root: Node2D = $XpOrbs
@onready var drops_root: Node2D = $Drops
@onready var time_label: Label = get_node_or_null("CanvasLayer/HUD/TopBar/TimeLabel") as Label
@onready var hp_label: Label = get_node_or_null("CanvasLayer/HUD/TopBar/HealthLabel") as Label
@onready var enemy_count_label: Label = get_node_or_null("CanvasLayer/HUD/TopBar/EnemyCountLabel") as Label
@onready var level_label: Label = get_node_or_null("CanvasLayer/HUD/TopBar/LevelLabel") as Label
@onready var weapon_label: Label = get_node_or_null("CanvasLayer/HUD/TopBar/WeaponLabel") as Label
@onready var xp_bar: ProgressBar = get_node_or_null("CanvasLayer/HUD/XpBar") as ProgressBar
@onready var hp_bar: ProgressBar = get_node_or_null("CanvasLayer/HUD/HpBar") as ProgressBar
@onready var status_label: Label = get_node_or_null("CanvasLayer/HUD/BottomBar/StatusLabel") as Label
@onready var stats_label: Label = get_node_or_null("CanvasLayer/HUD/BottomBar/StatsLabel") as Label
@onready var top_bar: Control = get_node_or_null("CanvasLayer/HUD/TopBar") as Control
@onready var bottom_bar: Control = get_node_or_null("CanvasLayer/HUD/BottomBar") as Control
@onready var sprite_hud: Control = $"CanvasLayer/HUD/SpriteHud"
@onready var sprite_hud_time_label: Label = $"CanvasLayer/HUD/SpriteHud/TopRightFrame/TimeLabel"
@onready var sprite_hud_hp_label: Label = $"CanvasLayer/HUD/SpriteHud/TopLeftStack/HpFrame/HpLabel"
@onready var sprite_hud_xp_label: Label = $"CanvasLayer/HUD/SpriteHud/TopLeftStack/XpFrame/XpLabel"
@onready var sprite_hud_status_label: Label = get_node_or_null("CanvasLayer/HUD/SpriteHud/StatusFrame/StatusLabel") as Label
@onready var sprite_stats_toggle_button: Button = get_node_or_null("CanvasLayer/HUD/SpriteHud/StatsToggleButton") as Button
@onready var sprite_stats_modal: PanelContainer = get_node_or_null("CanvasLayer/HUD/SpriteHud/StatsModal") as PanelContainer
@onready var sprite_stats_text_label: Label = get_node_or_null("CanvasLayer/HUD/SpriteHud/StatsModal/Margin/StatsText") as Label
@onready var horde_warning_label: Label = $"CanvasLayer/HUD/HordeWarning"
@onready var brute_charge_warning_label: Label = $"CanvasLayer/HUD/BruteChargeWarning"
@onready var game_over_panel: PanelContainer = $"CanvasLayer/HUD/GameOverPanel"
@onready var game_over_title: Label = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/SummaryPanel/SummaryMargin/SummaryVBox/Title"
@onready var game_over_desc: Label = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/SummaryPanel/SummaryMargin/SummaryVBox/Description"
@onready var game_over_summary_text: Label = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/SummaryPanel/SummaryMargin/SummaryVBox/SummaryText"
@onready var level_up_panel: PanelContainer = $"CanvasLayer/HUD/LevelUpPanel"
@onready var level_up_title: Label = $"CanvasLayer/HUD/LevelUpPanel/Margin/VBox/Title"
@onready var level_up_subtitle: Label = $"CanvasLayer/HUD/LevelUpPanel/Margin/VBox/SubTitle"
@onready var upgrade_button_1: Button = $"CanvasLayer/HUD/LevelUpPanel/Margin/VBox/UpgradeButton1"
@onready var upgrade_button_2: Button = $"CanvasLayer/HUD/LevelUpPanel/Margin/VBox/UpgradeButton2"
@onready var upgrade_button_3: Button = $"CanvasLayer/HUD/LevelUpPanel/Margin/VBox/UpgradeButton3"
@onready var debug_toggle_button: Button = $"CanvasLayer/HUD/SpriteHud/DebugToggleButtonSprite"
@onready var debug_panel: PanelContainer = $"CanvasLayer/HUD/DebugPanel"
@onready var debug_skip_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugSkipButton"
@onready var debug_horde_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugHordeButton"
@onready var debug_elite_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugEliteButton"
@onready var debug_brute_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugBruteButton"
@onready var debug_blink_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugBlinkButton"
@onready var debug_tank_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugTankButton"
@onready var debug_gtank_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugGTankButton"
@onready var debug_sword_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugSwordButton"
@onready var debug_mage_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugMageButton"
@onready var debug_electric_mage_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugElectricMageButton"
@onready var debug_elite_sword_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugEliteSwordButton"
@onready var debug_elite_mage_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugEliteMageButton"
@onready var debug_elite_electric_mage_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugEliteElectricMageButton"
@onready var debug_elite_hobgoblin_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugEliteHobgoblinButton"
@onready var debug_aoe_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugAoeButton"
@onready var debug_level_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugLevelButton"
@onready var debug_heal_button: Button = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugHealButton"
@onready var debug_stats_label: Label = $"CanvasLayer/HUD/DebugPanel/DebugMargin/DebugVBox/DebugStatsLabel"

var enemy_scene: PackedScene = preload("res://assets/characters/enemy.tscn")
var enemy_scene_goblin_sword: PackedScene = preload("res://assets/characters/goblinSword.tscn")
var enemy_scene_goblin_mage: PackedScene = preload("res://assets/characters/goblinMage.tscn")
var enemy_scene_goblin_electric_mage: PackedScene = preload("res://assets/characters/goblinElectricMage.tscn")
var enemy_scene_hobgoblin: PackedScene = preload("res://assets/characters/hobgoblin.tscn")
var xp_orb_scene: PackedScene = preload("res://scenes/XpOrb.tscn")
var pickup_drop_scene: PackedScene = preload("res://scenes/PickupDrop.tscn")
var run_time_seconds: float = 0.0
var spawn_cooldown: float = 0.0
var horde_event_cooldown: float = 45.0
var elite_event_cooldown: float = 30.0
var run_is_over: bool = false
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = BASE_XP_TO_LEVEL
var queued_upgrades: Array[Dictionary] = []
var pending_level_queue: Array[Dictionary] = []
var item_pool: Array[Dictionary] = []
var talent_pool: Array[Dictionary] = []
var active_horde_warnings: int = 0
var debug_status_until_ms: int = 0
var debug_status_text: String = ""
var use_sprite_hud: bool = true
var run_coins: int = 0
var run_damage_taken: int = 0
var last_health_sample: int = -1
var floor_fill_cooldown: float = 0.0

var tree_tiles = [
	Vector2i(0, 0),  # replace with your actual atlas coords
]
var map_width := 50
var map_height := 50
var tree_count := 80
var source_id := 0


func _ready() -> void:
	randomize()
	spawn_trees()
	run_coins = 0
	run_damage_taken = 0
	last_health_sample = -1
	if global_hud != null and global_hud.has_method("set_ui_mode"):
		global_hud.call("set_ui_mode", "combat")
	player.add_to_group("player")
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.sword_level_changed.connect(_on_sword_level_changed)
	item_pool = ItemCatalog.get_item_pool()
	talent_pool = ItemCatalog.get_talent_pool()
	game_over_panel.visible = false
	level_up_panel.visible = false
	game_over_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	level_up_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	debug_skip_button.visible = true
	debug_horde_button.visible = true
	debug_elite_button.visible = true
	debug_brute_button.visible = true
	debug_blink_button.visible = true
	debug_tank_button.visible = true
	debug_gtank_button.visible = true
	debug_sword_button.visible = true
	debug_mage_button.visible = true
	debug_electric_mage_button.visible = true
	debug_elite_sword_button.visible = true
	debug_elite_mage_button.visible = true
	debug_elite_electric_mage_button.visible = true
	debug_elite_hobgoblin_button.visible = true
	debug_aoe_button.visible = true
	debug_level_button.visible = true
	debug_heal_button.visible = true
	debug_panel.visible = false
	debug_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	debug_panel.move_to_front()
	debug_toggle_button.visible = true
	debug_toggle_button.text = "Debug (Open)"
	_ensure_debug_connections()
	_ensure_panel_connections()
	_ensure_debug_controls_clickable()
	_make_debug_panel_overlay()
	_setup_hud_mode()
	if xp_bar != null:
		xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hp_bar != null:
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if time_label != null:
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hp_label != null:
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enemy_count_label != null:
		enemy_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level_label != null:
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if weapon_label != null:
		weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label != null:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stats_label != null:
		stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horde_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brute_charge_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbs_root.z_index = 1
	drops_root.z_index = 1
	enemies_root.z_index = 2
	_ensure_runtime_lighting()
	horde_warning_label.visible = false
	brute_charge_warning_label.visible = false
	_on_player_health_changed(player.current_health, player.max_health)
	_on_sword_level_changed(player.sword_level, player.sword_max_level)
	_update_hud()
	
func spawn_trees():
	for i in tree_count:
		var x = randi_range(-map_width, map_width)
		var y = randi_range(-map_height, map_height)
		var random_tree = tree_tiles[randi() % tree_tiles.size()]
		tree_layer.set_cell(Vector2i(x, y), source_id, random_tree)
		
func _setup_hud_mode() -> void:
	if sprite_hud != null:
		sprite_hud.visible = use_sprite_hud
	if top_bar != null:
		top_bar.visible = not use_sprite_hud
	if bottom_bar != null:
		bottom_bar.visible = not use_sprite_hud
	if xp_bar != null:
		xp_bar.visible = not use_sprite_hud
	if hp_bar != null:
		hp_bar.visible = not use_sprite_hud
	if sprite_stats_modal != null:
		sprite_stats_modal.visible = false
	if sprite_stats_toggle_button != null:
		sprite_stats_toggle_button.visible = use_sprite_hud


func _ensure_debug_connections() -> void:
	if not debug_toggle_button.pressed.is_connected(_on_debug_toggle_button_pressed):
		debug_toggle_button.pressed.connect(_on_debug_toggle_button_pressed)
	if sprite_stats_toggle_button != null and not sprite_stats_toggle_button.pressed.is_connected(_on_stats_toggle_button_pressed):
		sprite_stats_toggle_button.pressed.connect(_on_stats_toggle_button_pressed)
	if not debug_skip_button.pressed.is_connected(_on_debug_skip_button_pressed):
		debug_skip_button.pressed.connect(_on_debug_skip_button_pressed)
	if not debug_horde_button.pressed.is_connected(_on_debug_horde_button_pressed):
		debug_horde_button.pressed.connect(_on_debug_horde_button_pressed)
	if not debug_elite_button.pressed.is_connected(_on_debug_elite_button_pressed):
		debug_elite_button.pressed.connect(_on_debug_elite_button_pressed)
	if not debug_brute_button.pressed.is_connected(_on_debug_brute_button_pressed):
		debug_brute_button.pressed.connect(_on_debug_brute_button_pressed)
	if not debug_blink_button.pressed.is_connected(_on_debug_blink_button_pressed):
		debug_blink_button.pressed.connect(_on_debug_blink_button_pressed)
	if not debug_tank_button.pressed.is_connected(_on_debug_tank_button_pressed):
		debug_tank_button.pressed.connect(_on_debug_tank_button_pressed)
	if not debug_gtank_button.pressed.is_connected(_on_debug_gtank_button_pressed):
		debug_gtank_button.pressed.connect(_on_debug_gtank_button_pressed)
	if not debug_sword_button.pressed.is_connected(_on_debug_sword_button_pressed):
		debug_sword_button.pressed.connect(_on_debug_sword_button_pressed)
	if not debug_mage_button.pressed.is_connected(_on_debug_mage_button_pressed):
		debug_mage_button.pressed.connect(_on_debug_mage_button_pressed)
	if not debug_electric_mage_button.pressed.is_connected(_on_debug_electric_mage_button_pressed):
		debug_electric_mage_button.pressed.connect(_on_debug_electric_mage_button_pressed)
	if not debug_elite_sword_button.pressed.is_connected(_on_debug_elite_sword_button_pressed):
		debug_elite_sword_button.pressed.connect(_on_debug_elite_sword_button_pressed)
	if not debug_elite_mage_button.pressed.is_connected(_on_debug_elite_mage_button_pressed):
		debug_elite_mage_button.pressed.connect(_on_debug_elite_mage_button_pressed)
	if not debug_elite_electric_mage_button.pressed.is_connected(_on_debug_elite_electric_mage_button_pressed):
		debug_elite_electric_mage_button.pressed.connect(_on_debug_elite_electric_mage_button_pressed)
	if not debug_elite_hobgoblin_button.pressed.is_connected(_on_debug_elite_hobgoblin_button_pressed):
		debug_elite_hobgoblin_button.pressed.connect(_on_debug_elite_hobgoblin_button_pressed)
	if not debug_aoe_button.pressed.is_connected(_on_debug_aoe_button_pressed):
		debug_aoe_button.pressed.connect(_on_debug_aoe_button_pressed)
	if not debug_level_button.pressed.is_connected(_on_debug_level_button_pressed):
		debug_level_button.pressed.connect(_on_debug_level_button_pressed)
	if not debug_heal_button.pressed.is_connected(_on_debug_heal_button_pressed):
		debug_heal_button.pressed.connect(_on_debug_heal_button_pressed)


func _ensure_panel_connections() -> void:
	if not upgrade_button_1.pressed.is_connected(_on_upgrade_button_1_pressed):
		upgrade_button_1.pressed.connect(_on_upgrade_button_1_pressed)
	if not upgrade_button_2.pressed.is_connected(_on_upgrade_button_2_pressed):
		upgrade_button_2.pressed.connect(_on_upgrade_button_2_pressed)
	if not upgrade_button_3.pressed.is_connected(_on_upgrade_button_3_pressed):
		upgrade_button_3.pressed.connect(_on_upgrade_button_3_pressed)
	var retry_button: Button = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/ActionsVBox/RetryButton"
	var dungeon_button: Button = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/ActionsVBox/DungeonButton"
	var menu_button: Button = $"CanvasLayer/HUD/GameOverPanel/Margin/RootRow/ActionsVBox/MenuButton"
	if retry_button != null and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)
	if dungeon_button != null and not dungeon_button.pressed.is_connected(_on_return_to_dungeon_button_pressed):
		dungeon_button.pressed.connect(_on_return_to_dungeon_button_pressed)
	if menu_button != null and not menu_button.pressed.is_connected(_on_menu_button_pressed):
		menu_button.pressed.connect(_on_menu_button_pressed)


func _ensure_debug_controls_clickable() -> void:
	debug_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	debug_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_horde_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_elite_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_brute_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_blink_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_tank_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_gtank_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_sword_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_mage_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_electric_mage_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_elite_sword_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_elite_mage_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_elite_electric_mage_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_elite_hobgoblin_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_aoe_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_level_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_heal_button.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_toggle_button.disabled = false
	debug_skip_button.disabled = false
	debug_horde_button.disabled = false
	debug_elite_button.disabled = false
	debug_brute_button.disabled = false
	debug_blink_button.disabled = false
	debug_tank_button.disabled = false
	debug_gtank_button.disabled = false
	debug_sword_button.disabled = false
	debug_mage_button.disabled = false
	debug_electric_mage_button.disabled = false
	debug_elite_sword_button.disabled = false
	debug_elite_mage_button.disabled = false
	debug_elite_electric_mage_button.disabled = false
	debug_elite_hobgoblin_button.disabled = false
	debug_aoe_button.disabled = false
	debug_level_button.disabled = false
	debug_heal_button.disabled = false


func _make_debug_panel_overlay() -> void:
	var canvas_layer: CanvasLayer = $CanvasLayer
	if debug_panel.get_parent() != canvas_layer:
		debug_panel.reparent(canvas_layer)
	# Keep the panel on HUD canvas, but respect editor-authored position/size.
	debug_panel.z_index = 300


func _process(delta: float) -> void:
	if run_is_over:
		return

	run_time_seconds = min(run_time_seconds + delta, RUN_DURATION_SECONDS)
	spawn_cooldown = max(spawn_cooldown - delta, 0.0)
	floor_fill_cooldown = max(floor_fill_cooldown - delta, 0.0)
	horde_event_cooldown = max(horde_event_cooldown - delta, 0.0)
	elite_event_cooldown = max(elite_event_cooldown - delta, 0.0)

	if spawn_cooldown <= 0.0:
		_try_spawn_enemy(_get_spawn_burst_count())
		spawn_cooldown = _get_spawn_interval()

	if floor_fill_cooldown <= 0.0:
		_fill_minimum_enemy_floor()
		floor_fill_cooldown = FLOOR_FILL_INTERVAL

	if horde_event_cooldown <= 0.0:
		horde_event_cooldown = randf_range(HORDE_EVENT_MIN_SECONDS, HORDE_EVENT_MAX_SECONDS)
		_trigger_horde_event_warning()
	if elite_event_cooldown <= 0.0:
		_try_spawn_timed_elite()
		elite_event_cooldown = _get_next_elite_event_interval()

	_update_hud()

	if run_time_seconds >= RUN_DURATION_SECONDS:
		_finish_run(true)


func _unhandled_input(event: InputEvent) -> void:
	if run_is_over or not debug_panel.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var mouse_pos: Vector2 = mouse_event.position
	if _try_click_debug_button(debug_skip_button, mouse_pos):
		_on_debug_skip_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_horde_button, mouse_pos):
		_on_debug_horde_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_elite_button, mouse_pos):
		_on_debug_elite_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_brute_button, mouse_pos):
		_on_debug_brute_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_blink_button, mouse_pos):
		_on_debug_blink_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_tank_button, mouse_pos):
		_on_debug_tank_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_gtank_button, mouse_pos):
		_on_debug_gtank_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_sword_button, mouse_pos):
		_on_debug_sword_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_mage_button, mouse_pos):
		_on_debug_mage_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_electric_mage_button, mouse_pos):
		_on_debug_electric_mage_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_elite_sword_button, mouse_pos):
		_on_debug_elite_sword_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_elite_mage_button, mouse_pos):
		_on_debug_elite_mage_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_elite_electric_mage_button, mouse_pos):
		_on_debug_elite_electric_mage_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_elite_hobgoblin_button, mouse_pos):
		_on_debug_elite_hobgoblin_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_aoe_button, mouse_pos):
		_on_debug_aoe_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_level_button, mouse_pos):
		_on_debug_level_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if _try_click_debug_button(debug_heal_button, mouse_pos):
		_on_debug_heal_button_pressed()
		get_viewport().set_input_as_handled()
		return


func _try_click_debug_button(button: Button, mouse_pos: Vector2) -> bool:
	return button != null and button.visible and button.get_global_rect().has_point(mouse_pos)


func _try_spawn_enemy(count: int = 1) -> void:
	if _get_non_horde_enemy_count() >= _get_max_enemies_alive():
		return
	for _i in range(max(count, 1)):
		if _get_non_horde_enemy_count() >= _get_max_enemies_alive():
			break
		_spawn_enemy_instance()


func _spawn_enemy_instance() -> void:
	var spawn_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_distance: float = _get_offscreen_spawn_distance()
	var enemy: CharacterBody2D = _pick_enemy_scene_for_progress().instantiate() as CharacterBody2D
	enemy.global_position = player.global_position + (spawn_direction * spawn_distance)
	if _should_spawn_elite():
		_configure_enemy_as_elite(enemy)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_root.add_child(enemy)


func _get_progress_ratio() -> float:
	return clamp(run_time_seconds / RUN_DURATION_SECONDS, 0.0, 1.0)


func _get_spawn_interval() -> float:
	var base_interval: float = lerp(START_SPAWN_INTERVAL, END_SPAWN_INTERVAL, _get_progress_ratio())
	return base_interval / _get_difficulty_pressure()


func _get_spawn_burst_count() -> int:
	var base_burst: float = lerp(float(START_SPAWN_BURST), float(END_SPAWN_BURST), _get_progress_ratio())
	return int(round(base_burst * _get_difficulty_pressure()))


func _get_max_enemies_alive() -> int:
	var base_max: float = lerp(float(START_MAX_ENEMIES), float(END_MAX_ENEMIES), _get_progress_ratio())
	return int(round(base_max * _get_difficulty_pressure()))


func _get_min_enemies_alive() -> int:
	var base_min: float = lerp(float(START_MIN_ENEMIES_ALIVE), float(END_MIN_ENEMIES_ALIVE), _get_progress_ratio())
	return int(round(base_min * _get_difficulty_pressure()))


func _get_difficulty_pressure() -> float:
	# First ~2 minutes are intentionally easy, then pressure ramps aggressively.
	var time_pressure: float = 1.0
	if run_time_seconds < EARLY_GAME_EASY_SECONDS:
		var early_t: float = clamp(run_time_seconds / EARLY_GAME_EASY_SECONDS, 0.0, 1.0)
		time_pressure = lerp(0.35, 1.0, early_t)
	else:
		var post_progress: float = clamp((run_time_seconds - EARLY_GAME_EASY_SECONDS) / max(RUN_DURATION_SECONDS - EARLY_GAME_EASY_SECONDS, 1.0), 0.0, 1.0)
		time_pressure = lerp(1.0, 2.05, post_progress)
	var level_pressure: float = 1.0
	if current_level >= 6:
		level_pressure += min(float(current_level - 5) * 0.05, 0.55)
	return max(time_pressure * level_pressure, 0.25)


func _fill_minimum_enemy_floor() -> void:
	var min_alive: int = min(_get_min_enemies_alive(), _get_max_enemies_alive())
	if _get_non_horde_enemy_count() >= min_alive:
		return
	var needed: int = min_alive - _get_non_horde_enemy_count()
	var max_fill_batch: int = int(round(lerp(4.0, 90.0, _get_progress_ratio())))
	if run_time_seconds < 12.0:
		max_fill_batch = min(max_fill_batch, 2)
	elif run_time_seconds < 40.0:
		max_fill_batch = min(max_fill_batch, 5)
	_try_spawn_enemy(min(needed, max_fill_batch))


func _update_hud() -> void:
	var remaining_time_text: String = _format_time(RUN_DURATION_SECONDS - run_time_seconds)
	var non_horde_count: int = _get_non_horde_enemy_count()
	var enemy_text: String = "Enemies: %d (%d core) / %d core cap" % [enemies_root.get_child_count(), non_horde_count, _get_max_enemies_alive()]
	var level_text: String = "Lv %d  XP %d/%d  Coins %d" % [current_level, current_xp, xp_to_next_level, GameState.get_coins()]
	var hp_text: String = "HP: %d / %d" % [player.current_health, player.max_health]
	var status_text: String = "Sword stacks to Lv8. Milestones: Lv5 = +1 slash, Lv8 = +2 slashes."

	if time_label != null:
		time_label.text = remaining_time_text
	if enemy_count_label != null:
		enemy_count_label.text = enemy_text
	if level_label != null:
		level_label.text = level_text
	if hp_label != null:
		hp_label.text = hp_text
	if xp_bar != null:
		xp_bar.max_value = float(xp_to_next_level)
		xp_bar.value = float(current_xp)
	if hp_bar != null:
		hp_bar.max_value = float(player.max_health)
		hp_bar.value = float(player.current_health)
	if status_label != null:
		status_label.text = status_text
	if Time.get_ticks_msec() < debug_status_until_ms:
		status_text = debug_status_text
		if status_label != null:
			status_label.text = status_text
	var dash_cd_left: float = player.get_dash_cooldown_remaining() if player.has_method("get_dash_cooldown_remaining") else 0.0
	var dash_cd_total: float = player.get_dash_cooldown_total() if player.has_method("get_dash_cooldown_total") else 0.0
	var stats_text: String = "SPD %.0f | LUCK %.2f | PICK %.0f | MAG %.0f | DMG %d | AOE %.0f | ATK CD %.2fs | SLASH x%d | DASH %.2f/%.2f" % [
		player.move_speed,
		player.get_luck() if player.has_method("get_luck") else 0.0,
		player.get_pickup_radius() if player.has_method("get_pickup_radius") else 0.0,
		player.get_magnet_range() if player.has_method("get_magnet_range") else 0.0,
		player.sword_damage,
		player.sword_aoe_radius,
		player.sword_cooldown,
		1 + player.extra_slash_count,
		dash_cd_left,
		dash_cd_total
	]
	if stats_label != null:
		stats_label.text = stats_text
	_update_sprite_hud(remaining_time_text, hp_text, level_text, enemy_text, status_text, stats_text)
	_update_debug_stats_panel()
	_update_brute_offscreen_warning()


func _update_sprite_hud(
	remaining_time_text: String,
	_hp_text: String,
	_level_text: String,
	enemy_text: String,
	status_text: String,
	stats_text: String
) -> void:
	if not use_sprite_hud:
		return
	if sprite_hud_time_label != null:
		sprite_hud_time_label.text = remaining_time_text
	if sprite_hud_hp_label != null:
		sprite_hud_hp_label.text = ""
	if sprite_hud_xp_label != null:
		sprite_hud_xp_label.text = ""
	var dash_cd_left: float = player.get_dash_cooldown_remaining() if player.has_method("get_dash_cooldown_remaining") else 0.0
	var dash_cd_total: float = player.get_dash_cooldown_total() if player.has_method("get_dash_cooldown_total") else 1.0
	var dash_ready_count: int = 1 if dash_cd_left <= 0.01 else 0
	var quick_stats_text: String = "SPD %.0f  DMG %d  CD %.2fs  AOE %.0f" % [
		player.move_speed,
		player.sword_damage,
		player.sword_cooldown,
		player.sword_aoe_radius
	]
	var run_minutes: int = int(run_time_seconds / 60.0)
	var run_seconds: int = int(run_time_seconds) % 60
	var run_timer_text: String = "Run %02d:%02d" % [run_minutes, run_seconds]
	var level_chip_text: String = "Lv %d" % current_level
	var item_entries: Array[Dictionary] = []
	item_entries.append({
		"icon": "[S]",
		"name": "Sword Slash",
		"stacks": "Lv %d" % player.sword_level,
		"effects": "Damage %d\nAOE %.0f\nCooldown %.2fs\nExtra slashes x%d" % [
			player.sword_damage,
			player.sword_aoe_radius,
			player.sword_cooldown,
			1 + player.extra_slash_count
		]
	})
	var item_stack_text: String = "Items: [S] Lv%d" % player.sword_level
	var talent_entries: Array[Dictionary] = []
	if player.extra_slash_count > 0:
		talent_entries.append({
			"icon": "[F]",
			"name": "Blade Fan",
			"stacks": "x%d" % player.extra_slash_count,
			"effects": "Adds extra angled slashes (%d)." % player.extra_slash_count
		})
	if player.dash_cooldown_multiplier < 0.99:
		talent_entries.append({
			"icon": "[D]",
			"name": "Dash Mastery",
			"stacks": "Lv 1",
			"effects": "Dash cooldown improved (x%.2f)." % player.dash_cooldown_multiplier
		})
	if player.dash_iframe_bonus > 0.001:
		talent_entries.append({
			"icon": "[I]",
			"name": "I-Frame Boost",
			"stacks": "+%.2fs" % player.dash_iframe_bonus,
			"effects": "Extra dash invulnerability: +%.2fs." % player.dash_iframe_bonus
		})
	if player.dash_distance_bonus > 0.001:
		talent_entries.append({
			"icon": "[L]",
			"name": "Longstep",
			"stacks": "+%.0f" % player.dash_distance_bonus,
			"effects": "Adds dash distance by %.0f." % player.dash_distance_bonus
		})
	if talent_entries.is_empty():
		talent_entries.append({
			"icon": "[ ]",
			"name": "No Talents Yet",
			"stacks": "-",
			"effects": "Reach Lv 5 milestones to unlock talents."
		})
	if global_hud != null and global_hud.has_method("update_combat_bars"):
		global_hud.call(
			"update_combat_bars",
			player.current_health,
			player.max_health,
			current_xp,
			xp_to_next_level,
			dash_ready_count,
			1,
			dash_cd_left,
			dash_cd_total,
			quick_stats_text
		)
	if global_hud != null and global_hud.has_method("update_combat_meta"):
		global_hud.call(
			"update_combat_meta",
			run_coins,
			item_stack_text,
			stats_text,
			item_entries,
			talent_entries,
			run_timer_text,
			level_chip_text,
			run_damage_taken
		)
	if sprite_hud_status_label != null:
		sprite_hud_status_label.text = "%s | %s" % [enemy_text, status_text]
	if sprite_stats_text_label != null:
		sprite_stats_text_label.text = stats_text


func _update_brute_offscreen_warning() -> void:
	if brute_charge_warning_label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var zoom_value: float = camera.zoom.x if camera != null else 1.0
	var half_screen_world: Vector2 = (viewport_size * 0.5) * zoom_value

	var selected_rel: Vector2 = Vector2.ZERO
	var selected_dist: float = INF
	for enemy_node in enemies_root.get_children():
		if not enemy_node.has_method("get_debug_snapshot"):
			continue
		var snap: Dictionary = enemy_node.call("get_debug_snapshot")
		if snap.get("elite_type", "") != "brute":
			continue
		var state: String = snap.get("brute_state", "")
		if state != "windup" and state != "charge":
			continue
		if not (enemy_node is Node2D):
			continue
		var rel: Vector2 = (enemy_node as Node2D).global_position - player.global_position
		var is_offscreen: bool = abs(rel.x) > half_screen_world.x or abs(rel.y) > half_screen_world.y
		if not is_offscreen:
			continue
		var dist: float = rel.length()
		if dist < selected_dist:
			selected_dist = dist
			selected_rel = rel

	if selected_dist == INF:
		brute_charge_warning_label.visible = false
		return

	var dir: Vector2 = selected_rel.normalized()
	var screen_center: Vector2 = viewport_size * 0.5
	var edge_offset: Vector2 = dir * min(viewport_size.x, viewport_size.y) * 0.36
	brute_charge_warning_label.position = screen_center + edge_offset
	brute_charge_warning_label.rotation = dir.angle()
	brute_charge_warning_label.text = ">"
	brute_charge_warning_label.modulate = Color(1.0, 0.3, 0.3, 0.95)
	brute_charge_warning_label.visible = true


func _update_debug_stats_panel() -> void:
	if debug_stats_label == null:
		return
	var progress_pct: float = _get_progress_ratio() * 100.0
	var brute_idle: int = 0
	var brute_windup: int = 0
	var brute_charge: int = 0
	var brute_recover: int = 0
	var elite_total: int = 0
	var elite_brute: int = 0
	var elite_blink: int = 0
	var elite_tank: int = 0
	var goblin_grunt_count: int = 0
	var goblin_sword_count: int = 0
	var goblin_mage_count: int = 0
	var goblin_electric_mage_count: int = 0
	var hobgoblin_count: int = 0
	for enemy_node in enemies_root.get_children():
		if not enemy_node.has_method("get_debug_snapshot"):
			continue
		var snap: Dictionary = enemy_node.call("get_debug_snapshot")
		var archetype: String = snap.get("archetype", "grunt")
		match archetype:
			"sword":
				goblin_sword_count += 1
			"mage":
				goblin_mage_count += 1
			"electric_mage":
				goblin_electric_mage_count += 1
			"hobgoblin":
				hobgoblin_count += 1
			_:
				goblin_grunt_count += 1
		if snap.get("is_elite", false):
			elite_total += 1
			var elite_type: String = snap.get("elite_type", "")
			match elite_type:
				"brute":
					elite_brute += 1
				"blink":
					elite_blink += 1
				"tank":
					elite_tank += 1
			var brute_state: String = snap.get("brute_state", "none")
			match brute_state:
				"idle":
					brute_idle += 1
				"windup":
					brute_windup += 1
				"charge":
					brute_charge += 1
				"recover":
					brute_recover += 1

	debug_stats_label.text = "Run %.1f%% | T %.0fs | Lv %d\nSpawn i%.2f b%d | Alive %d min%d max%d\nTypes G:%d S:%d F:%d E:%d T:%d\nPlayer HP %d/%d | SPD %.0f | PICK %.0f MAG %.0f\nSword L%d DMG %d AOE %.0f CD %.2f | Slashes x%d\nElites %d (Brt %d Blk %d Tnk %d)\nBrute states idle:%d windup:%d charge:%d recover:%d\nHordeCD %.1f EliteCD %.1f XP %d/%d" % [
		progress_pct,
		run_time_seconds,
		current_level,
		_get_spawn_interval(),
		_get_spawn_burst_count(),
		enemies_root.get_child_count(),
		_get_min_enemies_alive(),
		_get_max_enemies_alive(),
		goblin_grunt_count,
		goblin_sword_count,
		goblin_mage_count,
		goblin_electric_mage_count,
		hobgoblin_count,
		player.current_health,
		player.max_health,
		player.move_speed,
		player.get_pickup_radius() if player.has_method("get_pickup_radius") else 0.0,
		player.get_magnet_range() if player.has_method("get_magnet_range") else 0.0,
		player.sword_level,
		player.sword_damage,
		player.sword_aoe_radius,
		player.sword_cooldown,
		1 + player.extra_slash_count,
		elite_total,
		elite_brute,
		elite_blink,
		elite_tank,
		brute_idle,
		brute_windup,
		brute_charge,
		brute_recover,
		horde_event_cooldown,
		elite_event_cooldown,
		current_xp,
		xp_to_next_level
	]


func _format_time(seconds_left: float) -> String:
	var total_seconds: int = int(ceil(max(seconds_left, 0.0)))
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_player_health_changed(current: int, max_health: int) -> void:
	if last_health_sample >= 0 and current < last_health_sample:
		run_damage_taken += (last_health_sample - current)
	last_health_sample = current
	if hp_label != null:
		hp_label.text = "HP: %d / %d" % [current, max_health]


func _on_sword_level_changed(level: int, max_level: int) -> void:
	if weapon_label != null:
		weapon_label.text = "Sword Slash Lv %d/%d" % [level, max_level]


func _on_stats_toggle_button_pressed() -> void:
	if sprite_stats_modal == null:
		return
	sprite_stats_modal.visible = not sprite_stats_modal.visible


func _on_player_died() -> void:
	_finish_run(false)


func _finish_run(survived_to_end: bool) -> void:
	if run_is_over:
		return

	run_is_over = true
	get_tree().paused = true
	game_over_panel.visible = true
	game_over_panel.move_to_front()

	if survived_to_end:
		game_over_title.text = "Run Complete"
		game_over_desc.text = "You survived 15:00. Great baseline loop."
	else:
		game_over_title.text = "You Died"
		game_over_desc.text = "Try again and push your survival build farther."

	var elapsed_text: String = _format_time(run_time_seconds)
	var summary_data: Dictionary = {
		"result": "Complete" if survived_to_end else "Defeat",
		"level": current_level,
		"time_text": elapsed_text,
		"run_coins": run_coins,
		"damage_taken": run_damage_taken
	}
	GameState.record_last_run_summary(summary_data)
	if game_over_summary_text != null:
		game_over_summary_text.text = "Result: %s\nLevel Reached: %d\nTime Survived: %s\nRun Coins: %d\nDamage Taken: %d" % [
			summary_data.get("result", "Run"),
			current_level,
			elapsed_text,
			run_coins,
			run_damage_taken
		]


func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	GameState.go_to_main_menu()


func _on_return_to_dungeon_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _on_enemy_defeated(world_position: Vector2, xp_value: int, xp_tier: String) -> void:
	if run_is_over:
		return

	var orb: Node2D = xp_orb_scene.instantiate() as Node2D
	orb.global_position = world_position
	if orb.has_method("configure_drop"):
		orb.call("configure_drop", xp_value, xp_tier)
	orb.connect("collected", _on_xp_orb_collected)
	orbs_root.add_child(orb)
	_try_spawn_pickup_drop(world_position)


func _on_xp_orb_collected(xp_value: int) -> void:
	current_xp += xp_value
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		xp_to_next_level = BASE_XP_TO_LEVEL + ((current_level - 1) * XP_GROWTH_PER_LEVEL)
		pending_level_queue.append({
			"level": current_level,
			"is_talent": _is_talent_level(current_level)
		})

	if pending_level_queue.size() > 0 and not level_up_panel.visible:
		_show_level_up_panel()

	_update_hud()


func _try_spawn_pickup_drop(world_position: Vector2) -> void:
	var luck_value: float = player.get_luck() if player.has_method("get_luck") else 0.0
	var luck_mult: float = 1.0 + (luck_value * 0.22)
	if randf() < (HEALTH_DROP_CHANCE * luck_mult):
		_spawn_pickup_drop(world_position, "health", HEALTH_DROP_HEAL)
		return
	if randf() < (COIN_DROP_CHANCE * luck_mult):
		var coin_value: int = 1 + (1 if randf() < min(0.14 + luck_value * 0.05, 0.5) else 0)
		_spawn_pickup_drop(world_position, "coin", coin_value)


func _spawn_pickup_drop(world_position: Vector2, pickup_type: String, value: int) -> void:
	var pickup: Area2D = pickup_drop_scene.instantiate() as Area2D
	if pickup == null:
		return
	pickup.global_position = world_position + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
	if pickup.has_method("configure"):
		pickup.call("configure", pickup_type, value)
	pickup.connect("collected", _on_pickup_collected)
	drops_root.add_child(pickup)


func _on_pickup_collected(pickup_type: String, value: int) -> void:
	match pickup_type:
		"health":
			if player.has_method("heal"):
				player.call("heal", value)
		"coin":
			GameState.add_coins(value)
			run_coins += value
			_show_debug_status("Coins +%d" % value)
		_:
			pass
	_update_hud()


func _ensure_runtime_lighting() -> void:
	if get_node_or_null("ForestCanvasModulate") != null:
		return
	var dimmer: CanvasModulate = CanvasModulate.new()
	dimmer.name = "ForestCanvasModulate"
	dimmer.color = Color(0.76, 0.83, 0.9, 1.0)
	add_child(dimmer)
	var player_light: PointLight2D = PointLight2D.new()
	player_light.name = "PlayerLight"
	player_light.energy = 1.15
	player_light.texture_scale = 1.8
	player_light.color = Color(1.0, 0.97, 0.85, 1.0)
	player.add_child(player_light)


func _show_level_up_panel() -> void:
	if run_is_over:
		return
	if pending_level_queue.is_empty():
		return

	queued_upgrades = _build_upgrade_choices()
	var level_entry: Dictionary = pending_level_queue[0]
	var queued_level: int = level_entry.get("level", current_level)
	var is_talent_pick: bool = level_entry.get("is_talent", false)
	if is_talent_pick:
		level_up_title.text = "Talent Upgrade"
		level_up_subtitle.text = "Level %d milestone - choose 1 talent" % queued_level
	else:
		level_up_title.text = "Item Upgrade"
		level_up_subtitle.text = "Choose 1 item"
	upgrade_button_1.text = queued_upgrades[0].get("label", "Upgrade 1")
	upgrade_button_2.text = queued_upgrades[1].get("label", "Upgrade 2")
	upgrade_button_3.text = queued_upgrades[2].get("label", "Upgrade 3")
	level_up_panel.visible = true
	level_up_panel.move_to_front()
	get_tree().paused = true


func _build_upgrade_choices() -> Array[Dictionary]:
	if pending_level_queue.size() > 0 and pending_level_queue[0].get("is_talent", false):
		return _build_talent_choices()
	return _build_item_choices()


func _build_item_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for item_data in item_pool:
		var item_id: String = item_data.get("id", "")
		if item_id == "sword_slash" and not player.can_upgrade_sword():
			continue

		var item_name: String = item_data.get("name", "Unknown Item")
		var description: String = item_data.get("description", "")
		choices.append({
			"id": item_id,
			"category": "item",
			"label": "%s\n%s" % [item_name, description]
		})

	if choices.is_empty():
		choices.append({
			"id": "placeholder_none",
			"category": "item",
			"label": "Inventory Full\nNo more item upgrades available."
		})

	while choices.size() < 3:
		choices.append(choices[choices.size() - 1])

	return choices.slice(0, 3)


func _build_talent_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for talent_data in talent_pool:
		choices.append({
			"id": talent_data.get("id", ""),
			"category": "talent",
			"label": "%s\n%s" % [talent_data.get("name", "Talent"), talent_data.get("description", "")]
		})

	while choices.size() < 3:
		choices.append(choices[choices.size() - 1])

	return choices.slice(0, 3)


func _apply_upgrade(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= queued_upgrades.size():
		return

	var choice: Dictionary = queued_upgrades[choice_index]
	var id: String = choice.get("id", "")
	var category: String = choice.get("category", "item")

	if category == "talent":
		_apply_talent_choice(id)
	else:
		_apply_item_choice(id)

	if pending_level_queue.size() > 0:
		pending_level_queue.remove_at(0)
	queued_upgrades.clear()
	level_up_panel.visible = false
	get_tree().paused = false

	if pending_level_queue.size() > 0:
		_show_level_up_panel()

	_update_hud()


func _apply_item_choice(id: String) -> void:
	match id:
		"sword_slash":
			player.upgrade_sword()
		_:
			# Placeholder items have UI/data presence but no runtime behavior yet.
			pass


func _apply_talent_choice(id: String) -> void:
	match id:
		"might":
			player.apply_talent_effects(1.20, 1.0, 1.0)
		"reach":
			player.apply_talent_effects(1.0, 1.20, 1.0)
		"haste":
			player.apply_talent_effects(1.0, 1.0, 1.15)
		"blade_fan":
			if player.has_method("add_multi_slash"):
				player.call("add_multi_slash", 1)
		"dash_mastery":
			if player.has_method("apply_dash_talent"):
				player.call("apply_dash_talent", 0.15, 0.03, 0.0)
		"longstep":
			if player.has_method("apply_dash_talent"):
				player.call("apply_dash_talent", 0.0, 0.0, 45.0)
		_:
			pass


func _is_talent_level(level: int) -> bool:
	return level > 0 and level % 5 == 0


func _on_upgrade_button_1_pressed() -> void:
	_apply_upgrade(0)


func _on_upgrade_button_2_pressed() -> void:
	_apply_upgrade(1)


func _on_upgrade_button_3_pressed() -> void:
	_apply_upgrade(2)


func _on_debug_skip_button_pressed() -> void:
	if run_is_over:
		return
	run_time_seconds = min(run_time_seconds + 60.0, RUN_DURATION_SECONDS)
	spawn_cooldown = 0.0
	horde_event_cooldown = 0.0
	elite_event_cooldown = 0.0
	_show_debug_status("DEBUG: +60s applied")
	_update_hud()


func _on_debug_horde_button_pressed() -> void:
	if run_is_over:
		return
	_trigger_horde_event_warning()
	_show_debug_status("DEBUG: Horde event triggered")


func _on_debug_elite_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_elite()
	_show_debug_status("DEBUG: Elite spawned")


func _on_debug_brute_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_elite_variant("brute")
	_show_debug_status("DEBUG: Brute elite spawned")


func _on_debug_blink_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_elite_variant("blink")
	_show_debug_status("DEBUG: Blink elite spawned")


func _on_debug_tank_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_visible_enemy(enemy_scene, true, "tank")


func _on_debug_gtank_button_pressed() -> void:
	if run_is_over:
		return
	var hobgoblin_scene: PackedScene = load("res://assets/characters/hobgoblin.tscn") as PackedScene
	if hobgoblin_scene != null:
		_spawn_debug_visible_enemy(hobgoblin_scene, false, "")
		return
	# Fallback path: use archetype resolver in case direct load fails.
	_spawn_debug_enemy_variant("hobgoblin")
	_show_debug_status("DEBUG: Hobgoblin spawned via fallback")


func _on_debug_sword_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("sword")
	_show_debug_status("DEBUG: Goblin Sword spawned")


func _on_debug_mage_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("mage")
	_show_debug_status("DEBUG: Goblin Mage spawned")


func _on_debug_electric_mage_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("electric_mage")
	_show_debug_status("DEBUG: Electric Mage spawned")


func _on_debug_elite_sword_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("sword", true)
	_show_debug_status("DEBUG: Elite Sword Goblin spawned")


func _on_debug_elite_mage_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("mage", true)
	_show_debug_status("DEBUG: Elite Mage Goblin spawned")


func _on_debug_elite_electric_mage_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("electric_mage", true)
	_show_debug_status("DEBUG: Elite Electric Mage spawned")


func _on_debug_elite_hobgoblin_button_pressed() -> void:
	if run_is_over:
		return
	_spawn_debug_enemy_variant("hobgoblin", true)
	_show_debug_status("DEBUG: Elite Hobgoblin spawned")


func _on_debug_aoe_button_pressed() -> void:
	if run_is_over:
		return
	if player.has_method("debug_increase_sword_aoe"):
		player.call("debug_increase_sword_aoe", 14.0)
	_show_debug_status("DEBUG: Sword AOE increased")
	_update_hud()


func _on_debug_level_button_pressed() -> void:
	if run_is_over:
		return
	_on_xp_orb_collected(xp_to_next_level)
	_show_debug_status("DEBUG: Level up granted")


func _on_debug_heal_button_pressed() -> void:
	if run_is_over:
		return
	if player.has_method("heal"):
		player.call("heal", player.max_health)
	else:
		player.current_health = player.max_health
		if player.has_signal("health_changed"):
			player.health_changed.emit(player.current_health, player.max_health)
	_show_debug_status("DEBUG: Full heal")
	_update_hud()


func _on_debug_toggle_button_pressed() -> void:
	if debug_panel == null:
		return
	debug_panel.visible = not debug_panel.visible
	if debug_panel.visible:
		debug_panel.move_to_front()
	if debug_toggle_button != null:
		debug_toggle_button.text = "Debug (Close)" if debug_panel.visible else "Debug (Open)"


func _show_debug_status(text: String) -> void:
	debug_status_text = text
	debug_status_until_ms = Time.get_ticks_msec() + 1300


func _get_offscreen_spawn_distance() -> float:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom_value: float = camera.zoom.x if camera != null else 1.0
	var half_diagonal: float = viewport_size.length() * 0.5 * zoom_value
	var offscreen_min: float = max(SPAWN_DISTANCE_MIN, half_diagonal + 85.0)
	var offscreen_max: float = max(offscreen_min + 40.0, SPAWN_DISTANCE_MAX)
	return randf_range(offscreen_min, offscreen_max)


func _spawn_horde_event() -> void:
	_trigger_horde_event_warning()


func _trigger_horde_event_warning() -> void:
	if run_is_over:
		return
	var burst_count: int = _get_horde_warning_burst_count()
	for _i in range(burst_count):
		active_horde_warnings += 1
		var entry_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		_show_horde_warning(entry_direction)
		_spawn_horde_event_after_warning(entry_direction)


func _spawn_horde_event_after_warning(entry_direction: Vector2) -> void:
	await get_tree().create_timer(HORDE_WARNING_DURATION).timeout
	if run_is_over:
		active_horde_warnings = max(active_horde_warnings - 1, 0)
		return
	_spawn_horde_event_with_direction(entry_direction)
	active_horde_warnings = max(active_horde_warnings - 1, 0)


func _spawn_horde_event_with_direction(entry_direction: Vector2) -> void:
	var pressure: float = _get_difficulty_pressure()
	var horde_count: int = int(round(randi_range(HORDE_GROUP_MIN, HORDE_GROUP_MAX) * pressure))
	var center_distance: float = _get_offscreen_spawn_distance() + 140.0
	var center_pos: Vector2 = player.global_position + (entry_direction * center_distance)
	var move_direction: Vector2 = (player.global_position - center_pos).normalized()
	var side_direction: Vector2 = move_direction.orthogonal()
	var formation_type: String = _pick_horde_formation()

	for i in range(horde_count):
		var spawn_pos: Vector2 = _get_horde_spawn_position(i, horde_count, center_pos, move_direction, side_direction, formation_type)
		var horde_enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
		horde_enemy.global_position = spawn_pos
		horde_enemy.defeated.connect(_on_enemy_defeated)
		if horde_enemy.has_method("configure_as_horde_runner"):
			horde_enemy.call("configure_as_horde_runner", move_direction)
		enemies_root.add_child(horde_enemy)


func _show_horde_warning(entry_direction: Vector2) -> void:
	var dir: Vector2 = entry_direction.normalized() if entry_direction != Vector2.ZERO else Vector2.RIGHT
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_center: Vector2 = viewport_size * 0.5
	var edge_offset: Vector2 = dir * min(viewport_size.x, viewport_size.y) * 0.34
	var warning_label: Label = Label.new()
	warning_label.text = ">"
	warning_label.add_theme_font_size_override("font_size", 28)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.position = screen_center + edge_offset
	warning_label.rotation = dir.angle()
	warning_label.scale = Vector2.ONE
	warning_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	warning_label.z_index = 250
	$CanvasLayer.add_child(warning_label)

	var tween: Tween = create_tween()
	tween.tween_property(warning_label, "scale", Vector2(1.22, 1.22), HORDE_WARNING_DURATION * 0.5)
	tween.parallel().tween_property(warning_label, "modulate:a", 0.25, HORDE_WARNING_DURATION * 0.5)
	tween.tween_property(warning_label, "scale", Vector2.ONE, HORDE_WARNING_DURATION * 0.5)
	tween.parallel().tween_property(warning_label, "modulate:a", 1.0, HORDE_WARNING_DURATION * 0.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(warning_label):
			warning_label.queue_free()
	)


func _get_horde_warning_burst_count() -> int:
	var burst_count: int = 1
	var progress: float = _get_progress_ratio()
	var chance: float = lerp(HORDE_EXTRA_WARNING_BASE_CHANCE, HORDE_EXTRA_WARNING_MAX_CHANCE, progress)
	while burst_count < HORDE_MAX_WARNING_BURST and randf() < chance:
		burst_count += 1
		chance *= 0.72
	return burst_count


func _get_horde_spawn_position(
	index: int,
	count: int,
	center_pos: Vector2,
	move_direction: Vector2,
	side_direction: Vector2,
	formation_type: String
) -> Vector2:
	var centered_idx: float = float(index) - float(count - 1) * 0.5

	if formation_type == "line":
		# Thick line formation (2-3 stacked rows) instead of single overkill lane.
		var line_width: int = max(6, int(ceil(float(count) / 3.0)))
		var row: int = int(floor(float(index) / float(line_width)))
		var col: int = index % line_width
		var row_depth: float = (float(row) - 1.0) * 20.0
		var col_centered: float = float(col) - float(line_width - 1) * 0.5
		return center_pos + (side_direction * col_centered * 22.0) - (move_direction * row_depth)
	elif formation_type == "clump":
		# Default/most-common clustered horde.
		return center_pos + (side_direction * randf_range(-34.0, 34.0)) + (move_direction * randf_range(-24.0, 24.0))
	else:
		# V-shape horde.
		var arm_idx: float = abs(centered_idx)
		var side_sign: float = -1.0 if centered_idx < 0.0 else 1.0
		return center_pos + (side_direction * side_sign * arm_idx * 16.0) - (move_direction * arm_idx * 13.0)


func _pick_horde_formation() -> String:
	var roll: float = randf()
	# Make normal clump hordes most prominent.
	if roll < 0.6:
		return "clump"
	elif roll < 0.8:
		return "line"
	return "v"


func _should_spawn_elite() -> bool:
	if run_time_seconds < ELITE_START_TIME_SECONDS:
		return false
	var elite_progress: float = clamp((run_time_seconds - ELITE_START_TIME_SECONDS) / max(RUN_DURATION_SECONDS - ELITE_START_TIME_SECONDS, 1.0), 0.0, 1.0)
	var chance: float = lerp(ELITE_BASE_SPAWN_CHANCE, ELITE_MAX_SPAWN_CHANCE, elite_progress)
	return randf() < chance


func _configure_enemy_as_elite(enemy: CharacterBody2D, forced_type: String = "") -> void:
	if enemy != null and enemy.has_method("configure_as_elite"):
		enemy.call("configure_as_elite", _get_progress_ratio(), forced_type)


func _spawn_debug_elite() -> void:
	_spawn_debug_elite_variant("")


func _spawn_debug_elite_variant(elite_type: String) -> void:
	var spawn_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_distance: float = _get_offscreen_spawn_distance()
	var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	enemy.global_position = player.global_position + (spawn_direction * spawn_distance)
	_configure_enemy_as_elite(enemy, elite_type)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_root.add_child(enemy)


func _spawn_debug_enemy_variant(archetype: String, make_elite: bool = false) -> void:
	var spawn_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_distance: float = _get_offscreen_spawn_distance()
	var scene: PackedScene = _get_enemy_scene_by_archetype(archetype)
	var enemy: CharacterBody2D = scene.instantiate() as CharacterBody2D
	enemy.global_position = player.global_position + (spawn_direction * spawn_distance)
	if make_elite:
		_configure_enemy_as_elite(enemy)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_root.add_child(enemy)


func _spawn_debug_visible_enemy(scene: PackedScene, make_elite: bool = false, elite_type: String = "") -> void:
	if scene == null:
		_show_debug_status("DEBUG: Spawn failed (scene missing)")
		return
	var enemy: CharacterBody2D = scene.instantiate() as CharacterBody2D
	if enemy == null:
		_show_debug_status("DEBUG: Spawn failed (instantiate)")
		return
	var spawn_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_distance: float = randf_range(80.0, 130.0)
	enemy.global_position = player.global_position + (spawn_direction * spawn_distance)
	if make_elite:
		_configure_enemy_as_elite(enemy, elite_type)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_root.add_child(enemy)
	if enemy.has_method("get_enemy_archetype"):
		var kind: String = enemy.call("get_enemy_archetype")
		_show_debug_status("DEBUG: Spawned %s" % kind)
		return
	if make_elite:
		_show_debug_status("DEBUG: Tank elite spawned")
	else:
		_show_debug_status("DEBUG: Hobgoblin enemy spawned")


func _try_spawn_timed_elite() -> void:
	if run_is_over or run_time_seconds < ELITE_START_TIME_SECONDS:
		return
	if _get_non_horde_enemy_count() >= _get_max_enemies_alive():
		return
	var spawn_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_distance: float = _get_offscreen_spawn_distance() + 40.0
	var enemy: CharacterBody2D = _pick_enemy_scene_for_progress().instantiate() as CharacterBody2D
	enemy.global_position = player.global_position + (spawn_direction * spawn_distance)
	_configure_enemy_as_elite(enemy)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_root.add_child(enemy)


func _get_next_elite_event_interval() -> float:
	var progress: float = _get_progress_ratio()
	return lerp(ELITE_EVENT_MAX_INTERVAL, ELITE_EVENT_MIN_INTERVAL, progress)


func _pick_enemy_scene_for_progress() -> PackedScene:
	var progress: float = _get_progress_ratio()
	var sword_weight: float = lerp(0.0, 0.24, progress) if run_time_seconds >= SWORD_UNLOCK_SECONDS else 0.0
	var mage_weight: float = lerp(0.0, 0.18, progress) if run_time_seconds >= FIRE_MAGE_UNLOCK_SECONDS else 0.0
	var electric_mage_weight: float = lerp(0.0, 0.16, progress) if run_time_seconds >= ELECTRIC_MAGE_UNLOCK_SECONDS else 0.0
	var tank_weight: float = lerp(0.0, 0.12, progress) if run_time_seconds >= TANK_ENEMY_UNLOCK_SECONDS else 0.0
	# Keep early game overwhelmingly grunt-heavy, then layer in types over time.
	var roll: float = randf()
	if roll < tank_weight:
		return enemy_scene_hobgoblin
	if roll < tank_weight + electric_mage_weight:
		return enemy_scene_goblin_electric_mage
	if roll < tank_weight + electric_mage_weight + mage_weight:
		return enemy_scene_goblin_mage
	if roll < tank_weight + electric_mage_weight + mage_weight + sword_weight:
		return enemy_scene_goblin_sword
	return enemy_scene


func _get_enemy_scene_by_archetype(archetype: String) -> PackedScene:
	match archetype:
		"sword":
			return enemy_scene_goblin_sword
		"mage":
			return enemy_scene_goblin_mage
		"electric_mage":
			return enemy_scene_goblin_electric_mage
		"hobgoblin":
			return enemy_scene_hobgoblin
		_:
			return enemy_scene


func _get_non_horde_enemy_count() -> int:
	var count: int = 0
	for enemy_node in enemies_root.get_children():
		if enemy_node != null and enemy_node.has_method("is_horde_runner_unit") and enemy_node.call("is_horde_runner_unit"):
			continue
		count += 1
	return count
