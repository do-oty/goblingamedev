extends Control

const MODE_COMBAT: String = "combat"
const MODE_LOBBY: String = "lobby"
const LOW_HP_PULSE_THRESHOLD: float = 0.35
const HP_HIT_FLASH_SECONDS: float = 0.1

@export var pause_card_texture: Texture2D
@export var death_card_texture: Texture2D

@onready var sprite_hud: Control = $SpriteHud
@onready var top_bar: Control = get_node_or_null("TopBar") as Control
@onready var debug_panel: Control = $DebugPanel
@onready var xp_bar: ProgressBar = get_node_or_null("XpBar") as ProgressBar
@onready var hp_bar: ProgressBar = get_node_or_null("HpBar") as ProgressBar
@onready var coin_label: Label = $CoinLabel
@onready var dash_panel: Control = $SpriteHud/DashPanel
@onready var hp_sprite_bar: ProgressBar = $SpriteHud/TopBars/HpSpriteBar
@onready var xp_sprite_bar: ProgressBar = $SpriteHud/TopBars/XpSpriteBar
@onready var dash_count_label: Label = $SpriteHud/DashPanel/DashCountLabel
@onready var dash_cooldown_bar: TextureProgressBar = $SpriteHud/DashPanel/DashCooldownBar
@onready var mobile_dash_button: Button = $SpriteHud/MobileDashButton
@onready var run_timer_label: Label = $SpriteHud/RunTimerLabel
@onready var virtual_joystick: Control = get_node_or_null("Virtual Joystick") as Control
@onready var level_chip_label: Label = get_node_or_null("SpriteHud/LevelChipLabel") as Label
@onready var hp_chip_label: Label = get_node_or_null("SpriteHud/TopLeftStack/HpFrame/HpLabel") as Label
@onready var xp_chip_label: Label = get_node_or_null("SpriteHud/TopLeftStack/XpFrame/XpLabel") as Label
@onready var items_toggle_button: Button = get_node_or_null("SpriteHud/ItemsToggleButton") as Button
@onready var stats_toggle_button_left: Button = get_node_or_null("SpriteHud/StatsToggleButtonLeft") as Button
@onready var items_modal: PanelContainer = get_node_or_null("SpriteHud/ItemsModal") as PanelContainer
@onready var stats_modal_left: PanelContainer = get_node_or_null("SpriteHud/StatsModalLeft") as PanelContainer
@onready var items_list: VBoxContainer = get_node_or_null("SpriteHud/ItemsModal/Margin/ContentVBox/ItemsList") as VBoxContainer
@onready var item_detail_label: Label = get_node_or_null("SpriteHud/ItemsModal/Margin/ContentVBox/ItemDetailLabel") as Label
@onready var stats_text_left_label: Label = get_node_or_null("SpriteHud/StatsModalLeft/Margin/StatsText") as Label
@onready var items_modal_bg: TextureRect = get_node_or_null("SpriteHud/ItemsModal/Background") as TextureRect
@onready var stats_modal_left_bg: TextureRect = get_node_or_null("SpriteHud/StatsModalLeft/Background") as TextureRect
@onready var stats_modal_bg: TextureRect = get_node_or_null("SpriteHud/StatsModal/Background") as TextureRect

@onready var sprite_hud_status_label: Label = get_node_or_null("SpriteHud/StatusFrame/StatusLabel") as Label
@onready var time_label: Label = get_node_or_null("TopBar/TimeLabel") as Label
@onready var enemy_count_label: Label = get_node_or_null("TopBar/EnemyCountLabel") as Label
@onready var mobile_interact_button: TouchScreenButton = _create_mobile_interact_ts_button()

signal interact_pressed



var combat_mode_active: bool = false
var hp_current: int = 1
var hp_max: int = 1
var hp_ghost_ratio: float = 1.0
var hp_ghost_delay_timer: float = 0.0
var hp_shake_amount: float = 0.0
var xp_current: int = 0
var xp_max: int = 1
var hp_previous: int = 1
var hp_hit_flash_until: float = 0.0
var level_up_flash_until: float = 0.0
var xp_display_ratio: float = 0.0
var xp_wrap_anim_active: bool = false
var xp_wrap_anim_phase: int = 0
var xp_wrap_anim_timer: float = 0.0
var xp_wrap_target_ratio: float = 0.0
var items_modal_cache_key: String = ""
var item_modal_entries: Array[Dictionary] = []



func _ready() -> void:
	_disable_focus_recursively(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Button Squish Effect
	for btn in [mobile_dash_button]:
		if btn:
			btn.button_down.connect(func():
				btn.pivot_offset = btn.size / 2
				create_tween().tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
			)
			btn.button_up.connect(func():
				create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
			)

	if hp_sprite_bar != null:
		hp_sprite_bar.visible = true
	if xp_sprite_bar != null:
		xp_sprite_bar.visible = true
	if level_chip_label != null:
		level_chip_label.visible = true

	if mobile_dash_button != null:
		if OS.get_name() in ["Android", "iOS"]:
			_convert_to_touch_screen_button(mobile_dash_button)
		else:
			if not mobile_dash_button.button_down.is_connected(_on_mobile_dash_button_down):
				mobile_dash_button.button_down.connect(_on_mobile_dash_button_down)
			if not mobile_dash_button.button_up.is_connected(_on_mobile_dash_button_up):
				mobile_dash_button.button_up.connect(_on_mobile_dash_button_up)
			_style_mobile_dash_button()
			mobile_dash_button.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if virtual_joystick != null:
		virtual_joystick.modulate.a = 0.6
	_ensure_modal_toggle_connections()
	_set_items_modal_visible(false)
	_set_stats_modal_visible(false)
	_prepare_modal_backgrounds()
	_stack_side_modals()
	if stats_text_left_label != null:
		stats_text_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_text_left_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		stats_text_left_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Create a CanvasLayer to ensure HUD draws on top of maps!
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 100
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	
	# Reparent SpriteHud to the CanvasLayer
	if sprite_hud != null:
		sprite_hud.get_parent().remove_child(sprite_hud)
		hud_layer.add_child(sprite_hud)
		
	# Create a stack for the three buttons
	var button_stack := HBoxContainer.new()
	button_stack.name = "ButtonStack"
	button_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	button_stack.add_theme_constant_override("separation", 15)
	hud_layer.add_child(button_stack) # Added to hud_layer!
	
	# Position it in the center of the screen dynamically
	var pos_func := func():
		await get_tree().process_frame
		var viewport_size: Vector2 = get_viewport_rect().size
		button_stack.global_position = Vector2(viewport_size.x / 2.0 - button_stack.size.x / 2.0, viewport_size.y - 60.0)
	pos_func.call()
	
	var objectives_toggle_btn := Button.new()
	objectives_toggle_btn.text = "Objectives"
	objectives_toggle_btn.name = "ObjectivesToggleButton"
	objectives_toggle_btn.focus_mode = Control.FOCUS_NONE

	# Reparent existing buttons if they exist

	if stats_toggle_button_left != null:
		stats_toggle_button_left.get_parent().remove_child(stats_toggle_button_left)
		button_stack.add_child(stats_toggle_button_left)
		_style_web_button(stats_toggle_button_left)
		_apply_squish_to_button(stats_toggle_button_left)
		stats_toggle_button_left.focus_mode = Control.FOCUS_NONE
		
	button_stack.add_child(objectives_toggle_btn)
	_style_web_button(objectives_toggle_btn)
	_apply_squish_to_button(objectives_toggle_btn)
	
	if items_toggle_button != null:
		items_toggle_button.get_parent().remove_child(items_toggle_button)
		button_stack.add_child(items_toggle_button)
		_style_web_button(items_toggle_button)
		_apply_squish_to_button(items_toggle_button)
		items_toggle_button.focus_mode = Control.FOCUS_NONE
		
	objectives_toggle_btn.pressed.connect(func():
		var tracker = get_tree().current_scene.find_child("ObjectiveUI_TrackerBg", true, false)
		if tracker != null:
			tracker.visible = !tracker.visible
	)

		





	
	set_ui_mode(MODE_COMBAT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause_menu()


func show_dialogue(_text: String, _portrait_sprite: Texture2D = null) -> void:
	pass


func set_ui_mode(mode: String) -> void:
	var combat_visible: bool = mode == MODE_COMBAT
	combat_mode_active = combat_visible
	if sprite_hud != null:
		sprite_hud.visible = true
	if top_bar != null:
		top_bar.visible = true # Keep top bar for timer and enemy count
	if debug_panel != null:
		debug_panel.visible = combat_visible
	if hp_bar != null:
		hp_bar.visible = false
	if xp_bar != null:
		xp_bar.visible = false
	if hp_sprite_bar != null:
		hp_sprite_bar.visible = false
	if xp_sprite_bar != null:
		xp_sprite_bar.visible = false
	if coin_label != null:
		coin_label.visible = true
	if level_chip_label != null:
		level_chip_label.visible = true
		level_chip_label.modulate.a = 1.0
	if hp_chip_label != null:
		hp_chip_label.visible = true
		hp_chip_label.modulate.a = 1.0
	if xp_chip_label != null:
		xp_chip_label.visible = true
		xp_chip_label.modulate.a = 1.0
	if sprite_hud != null:
		sprite_hud.visible = true
		sprite_hud.modulate.a = 1.0


	if dash_panel != null:
		dash_panel.visible = true
	if mobile_dash_button != null:
		mobile_dash_button.visible = true
	if run_timer_label != null:
		run_timer_label.visible = combat_visible


func update_combat_bars(
	current_hp: int,
	max_hp: int,
	current_xp: int,
	max_xp: int,
	dash_count: int,
	dash_max: int,
	dash_cooldown_left: float,
	dash_cooldown_total: float,
	_quick_stats_text: String = ""
) -> void:
	if current_hp < hp_previous:
		hp_hit_flash_until = (float(Time.get_ticks_msec()) / 1000.0) + HP_HIT_FLASH_SECONDS
		_spawn_hp_hit_particles()
		hp_ghost_delay_timer = 0.6
		hp_shake_amount = 6.0
	hp_current = max(current_hp, 0)
	hp_max = max(max_hp, 1)
	xp_current = max(current_xp, 0)
	xp_max = max(max_xp, 1)
	var target_xp_ratio: float = clamp(float(xp_current) / float(xp_max), 0.0, 1.0)
	_update_xp_animation(target_xp_ratio)
	hp_previous = hp_current
	if hp_bar != null:
		hp_bar.max_value = hp_max
		hp_bar.value = hp_current
	if hp_chip_label != null:
		hp_chip_label.text = "HP %d / %d" % [hp_current, hp_max]
	if xp_chip_label != null:
		xp_chip_label.text = "XP %d / %d" % [xp_current, xp_max]
	if xp_bar != null:
		xp_bar.max_value = xp_max
		xp_bar.value = xp_current
	if dash_count_label != null:
		dash_count_label.text = "Dash %d/%d" % [max(dash_count, 0), max(dash_max, 1)]
	if dash_cooldown_bar != null:
		var total_cd: float = max(dash_cooldown_total, 0.01)
		var left_cd: float = clamp(dash_cooldown_left, 0.0, total_cd)
		dash_cooldown_bar.max_value = total_cd
		# Invert so a full bar means dash ready.
		dash_cooldown_bar.value = total_cd - left_cd

	queue_redraw()


func update_combat_meta(
	coins: int,
	_item_stacks_text: String,
	stats_modal_text: String,
	item_entries: Array[Dictionary],
	_talent_entries: Array[Dictionary],
	run_timer_text: String,
	level_chip_text: String,
	_run_damage_taken: int,
	status_text: String = ""
) -> void:
	if coin_label != null:
		coin_label.text = "Run Coins: %d" % coins
	if run_timer_label != null:
		run_timer_label.text = run_timer_text
		run_timer_label.visible = true
	if level_chip_label != null:
		level_chip_label.text = level_chip_text
	if stats_text_left_label != null:
		stats_text_left_label.text = stats_modal_text.replace(" | ", "\n")
		_fit_stats_modal_height()
	if sprite_hud_status_label != null:
		sprite_hud_status_label.text = status_text
		sprite_hud_status_label.visible = not status_text.is_empty()
		var frame = sprite_hud.get_node_or_null("StatusFrame")
		if frame: frame.visible = not status_text.is_empty()
		
	_update_item_modal_entries(item_entries)




func _draw() -> void:
	if not combat_mode_active:
		return
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var screen_width = get_viewport_rect().size.x
	var width: float = screen_width
	var bar_height: float = 18.0
	
	# Position at the very top
	var hp_y: float = 0.0
	var xp_y: float = hp_y + bar_height + 2.0
	var bars_group_top_left := Vector2(0.0, hp_y)
	var bars_group_size := Vector2(width, (xp_y + bar_height) - hp_y)
	draw_rect(Rect2(bars_group_top_left - Vector2(2.0, 2.0), bars_group_size + Vector2(4.0, 4.0)), Color(0.0, 0.0, 0.0, 0.9), false, 3.0)
	
	# Check for flashes
	var is_flashing: bool = now_seconds < hp_hit_flash_until
	var flash_active: bool = is_flashing
	
	# Check for low HP flash
	var hp_ratio: float = float(hp_current) / float(hp_max)
	var is_low_hp: bool = hp_ratio < 0.3
	var low_hp_flash: bool = is_low_hp and (int(Time.get_ticks_msec() / 250.0) % 2 == 0)
	
	# Draw HP Bar (Red)
	var hp_color = Color(1, 1, 1) if flash_active else (Color(1, 0.3, 0.3) if low_hp_flash else Color(0.85, 0.15, 0.15))
	var hp_color_dark = Color(1, 1, 1) if is_flashing else (Color(0.5, 0.05, 0.05) if low_hp_flash else Color(0.3, 0.05, 0.05))
	
	# Apply shake to HP bar
	var hp_pos := Vector2(0, hp_y)
	if hp_shake_amount > 0.1:
		hp_pos += Vector2(randf_range(-hp_shake_amount, hp_shake_amount), randf_range(-hp_shake_amount, hp_shake_amount))
	
	_draw_segmented_bar(
		hp_pos,
		Vector2(width, bar_height),
		hp_ratio,
		hp_ghost_ratio,
		hp_color,
		hp_color_dark,
		Color(0.1, 0.02, 0.02),
		40
	)
	
	# Draw XP Bar (Green/Lime)
	_draw_segmented_bar(
		Vector2(0, xp_y),
		Vector2(width, bar_height),
		xp_display_ratio,
		xp_display_ratio, # Ghost ratio same as ratio for XP
		Color(0.15, 0.85, 0.15),
		Color(0.05, 0.4, 0.05),
		Color(0.02, 0.1, 0.02),
		50
	)

func _draw_segmented_bar(pos: Vector2, size: Vector2, ratio: float, ghost_ratio: float, fill_color: Color, fill_color_dark: Color, bg_color: Color, segments: int) -> void:
	# Draw black outline (thicker, 2px)
	draw_rect(Rect2(pos - Vector2(2,2), size + Vector2(4,4)), Color(0,0,0))
	
	# Draw background
	draw_rect(Rect2(pos, size), bg_color)
	
	# Draw fill
	var fill_width: float = size.x * ratio
	var ghost_width: float = size.x * ghost_ratio
	
	if ghost_width > fill_width:
		# Draw ghost bar (damage lag)
		draw_rect(Rect2(pos + Vector2(fill_width, 0), Vector2(ghost_width - fill_width, size.y)), Color(1, 1, 1, 0.6))
		
	if fill_width > 0:
		# Use a solid fill with a highlight for a cleaner look
		draw_rect(Rect2(pos, Vector2(fill_width, size.y)), fill_color)
		
		# Top highlight (glossy look)
		draw_line(Vector2(pos.x, pos.y + 1), Vector2(pos.x + fill_width, pos.y + 1), Color(1, 1, 1, 0.4), 1.0)
		
		# Inner outline for the filled part
		draw_rect(Rect2(pos, Vector2(fill_width, size.y)), Color(0, 0, 0, 0.3), false, 1.0)
		
	# Draw segment separators
	var seg_w: float = size.x / float(segments)
	for i in range(1, segments):
		var sep_x: float = pos.x + (i * seg_w)
		draw_line(Vector2(sep_x, pos.y), Vector2(sep_x, pos.y + size.y), Color(0, 0, 0, 0.6), 2.0)


func _process(_delta: float) -> void:
	if combat_mode_active:
		_update_xp_wrap_anim(_delta)
		
		# Update HP Ghost Bar
		var current_hp_ratio: float = float(hp_current) / float(hp_max)
		if hp_ghost_delay_timer > 0.0:
			hp_ghost_delay_timer -= _delta
		else:
			hp_ghost_ratio = lerp(hp_ghost_ratio, current_hp_ratio, _delta * 3.0)
			
		# Update HP Bar Shake
		if hp_shake_amount > 0.1:
			hp_shake_amount = lerp(hp_shake_amount, 0.0, _delta * 10.0)
		else:
			hp_shake_amount = 0.0
			
		queue_redraw()





func _update_xp_animation(target_ratio: float) -> void:
	if xp_wrap_anim_active:
		xp_wrap_target_ratio = target_ratio
		return
	# Detect level-up wrap: ratio drops hard from high to low.
	if xp_display_ratio > 0.72 and target_ratio < (xp_display_ratio - 0.35):
		xp_wrap_anim_active = true
		xp_wrap_anim_phase = 0
		xp_wrap_anim_timer = 0.0
		xp_wrap_target_ratio = target_ratio
	else:
		xp_display_ratio = target_ratio


func _ensure_modal_toggle_connections() -> void:
	if items_toggle_button != null and not items_toggle_button.pressed.is_connected(_on_items_toggle_pressed):
		items_toggle_button.pressed.connect(_on_items_toggle_pressed)
	if stats_toggle_button_left != null and not stats_toggle_button_left.pressed.is_connected(_on_stats_toggle_pressed):
		stats_toggle_button_left.pressed.connect(_on_stats_toggle_pressed)
	if items_modal != null:
		items_modal.visible = false
	if stats_modal_left != null:
		stats_modal_left.visible = false


func _set_items_modal_visible(is_visible: bool) -> void:
	if items_modal != null:
		items_modal.visible = is_visible
	if items_toggle_button != null:
		items_toggle_button.text = "Items"
	_stack_side_modals()


func _set_stats_modal_visible(is_visible: bool) -> void:
	if stats_modal_left != null:
		stats_modal_left.visible = is_visible
	if stats_toggle_button_left != null:
		stats_toggle_button_left.text = "Stats"
	_fit_stats_modal_height()
	_stack_side_modals()


func _on_items_toggle_pressed() -> void:
	var show_items: bool = items_modal == null or not items_modal.visible
	_set_items_modal_visible(show_items)


func _on_stats_toggle_pressed() -> void:
	var show_stats: bool = stats_modal_left == null or not stats_modal_left.visible
	_set_stats_modal_visible(show_stats)


func _update_item_modal_entries(item_entries: Array[Dictionary]) -> void:
	if items_list == null:
		return
	item_modal_entries = item_entries.duplicate(true)
	var cache_key: String = str(item_modal_entries)
	if cache_key == items_modal_cache_key:
		return
	items_modal_cache_key = cache_key
	for child in items_list.get_children():
		child.queue_free()
	var display_count: int = min(item_modal_entries.size(), 3)
	for idx in range(3):
		if idx < display_count:
			var entry: Dictionary = item_modal_entries[idx]
			var item_name: String = str(entry.get("name", "Item"))
			var stacks: String = str(entry.get("stacks", ""))
			var btn := Button.new()
			btn.text = item_name if stacks.is_empty() else "%s (%s)" % [item_name, stacks]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0.0, 32.0)
			_apply_squish_to_button(btn)
			btn.pressed.connect(_on_item_entry_pressed.bind(idx))
			items_list.add_child(btn)
		else:
			var slot := Label.new()
			slot.text = "Empty Slot"
			slot.modulate = Color(0.8, 0.82, 0.9, 0.55)
			items_list.add_child(slot)
	if item_detail_label != null:
		if display_count > 0:
			_on_item_entry_pressed(0)
		else:
			item_detail_label.text = "Collect item upgrades to see details."
		item_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _on_item_entry_pressed(index: int) -> void:
	if item_detail_label == null:
		return
	if index < 0 or index >= item_modal_entries.size():
		item_detail_label.text = "Tap an item to view effects."
		return
	var entry: Dictionary = item_modal_entries[index]
	item_detail_label.text = str(entry.get("effects", "No details available yet."))


func _prepare_modal_backgrounds() -> void:
	for bg in [items_modal_bg, stats_modal_left_bg, stats_modal_bg]:
		if bg == null:
			continue
		bg.self_modulate = Color(0.16, 0.2, 0.28, 0.16)
		
	# Removed style overrides that were causing black boxes


func _fit_stats_modal_height() -> void:
	if stats_modal_left == null or stats_text_left_label == null:
		return
	var modal_min_h: float = 140.0
	var top_pad: float = 24.0
	var bottom_pad: float = 24.0
	var text_min_h: float = stats_text_left_label.get_combined_minimum_size().y
	var target_h: float = max(modal_min_h, text_min_h + top_pad + bottom_pad)
	stats_modal_left.offset_bottom = stats_modal_left.offset_top + target_h


func _stack_side_modals() -> void:
	if items_modal == null or stats_modal_left == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = 14.0
	var gap: float = 28.0
	var modal_w: float = 300.0
	var items_top: float = 180.0 # Pushed lower to avoid clipping
	var items_h: float = max(136.0, items_modal.offset_bottom - items_modal.offset_top)
	var stats_h: float = max(140.0, stats_modal_left.offset_bottom - stats_modal_left.offset_top)
	var max_h: float = max(120.0, viewport_size.y - (items_top + margin))
	items_h = min(items_h, max_h)
	stats_h = min(stats_h, max_h)
	items_modal.offset_left = margin
	items_modal.offset_right = margin + modal_w
	items_modal.offset_top = items_top
	items_modal.offset_bottom = items_top + items_h
	var stats_top: float = (items_modal.offset_bottom + gap) if items_modal.visible else (items_top + 180.0)
	if stats_top + stats_h > viewport_size.y - margin:
		var overflow: float = (stats_top + stats_h) - (viewport_size.y - margin)
		if items_modal.visible:
			items_top = max(42.0, items_top - overflow)
			items_modal.offset_top = items_top
			items_modal.offset_bottom = items_top + items_h
			stats_top = items_modal.offset_bottom + gap
		if stats_top + stats_h > viewport_size.y - margin:
			stats_h = max(110.0, (viewport_size.y - margin) - stats_top)
	stats_modal_left.offset_left = margin
	stats_modal_left.offset_right = margin + modal_w
	stats_modal_left.offset_top = stats_top
	stats_modal_left.offset_bottom = stats_top + stats_h


func hit_stop(duration: float = 0.08, timescale: float = 0.02) -> void:
	Engine.time_scale = timescale
	await get_tree().create_timer(duration * 0.01, true, false, true).timeout
	Engine.time_scale = 1.0


func _update_xp_wrap_anim(delta: float) -> void:
	if not xp_wrap_anim_active:
		return
	xp_wrap_anim_timer += delta
	if xp_wrap_anim_phase == 0:
		var drain_t: float = clamp(xp_wrap_anim_timer / 0.16, 0.0, 1.0)
		xp_display_ratio = lerp(xp_display_ratio, 0.0, drain_t)
		if drain_t >= 1.0:
			xp_wrap_anim_phase = 1
			xp_wrap_anim_timer = 0.0
	elif xp_wrap_anim_phase == 1:
		var fill_t: float = clamp(xp_wrap_anim_timer / 0.2, 0.0, 1.0)
		xp_display_ratio = lerp(0.0, xp_wrap_target_ratio, fill_t)
		if fill_t >= 1.0:
			xp_wrap_anim_active = false
			xp_wrap_anim_phase = 0
			xp_wrap_anim_timer = 0.0



	










	





	


	

	


	





































func _convert_to_touch_screen_button(btn: Button) -> void:
	if btn == null: return
	var ts_btn = TouchScreenButton.new()
	ts_btn.action = "dash"
	ts_btn.name = "TouchDashButton"
	var size = btn.custom_minimum_size if btn.custom_minimum_size.x > 0 else Vector2(80, 80)
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var center = size / 2
	var radius = min(size.x, size.y) / 2
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	ts_btn.texture_normal = ImageTexture.create_from_image(img)
	ts_btn.modulate = Color(0.2, 0.2, 0.2, 0.7)
	btn.add_child(ts_btn)
	ts_btn.position = Vector2.ZERO
	btn.flat = true
	btn.text = ""
	btn.mouse_filter = Control.MOUSE_FILTER_PASS

func _create_mobile_interact_ts_button() -> TouchScreenButton:
	var ts_btn = TouchScreenButton.new()
	ts_btn.name = "MobileInteractTSButton"
	ts_btn.visible = false
	
	# Create a circle texture for the talk button
	var size = Vector2(120, 120)
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var center = size / 2
	var radius = size.x / 2
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, Color(0.2, 0.6, 0.2, 0.9)) # Green circle
			else:
				img.set_pixel(x, y, Color(0,0,0,0))
	
	ts_btn.texture_normal = ImageTexture.create_from_image(img)
	
	# Add a label to it
	var label = Label.new()
	label.text = "TALK"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 22)
	ts_btn.add_child(label)
	
	add_child(ts_btn)
	ts_btn.position = Vector2(get_viewport_rect().size.x - 260, get_viewport_rect().size.y - 280)
	
	ts_btn.pressed.connect(func(): interact_pressed.emit())
	return ts_btn

func set_mobile_interact_visible(v: bool) -> void:
	if mobile_interact_button:
		mobile_interact_button.visible = v and OS.get_name() in ["Android", "iOS", "Windows"]

func set_lobby_last_run_text(_text: String) -> void:
	pass


func _on_mobile_dash_button_down() -> void:
	Input.action_press("dash")


func _on_mobile_dash_button_up() -> void:
	Input.action_release("dash")


func _style_mobile_dash_button() -> void:
	if mobile_dash_button == null:
		return
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.08, 0.08, 0.8)
	normal_style.corner_radius_top_left = 38
	normal_style.corner_radius_top_right = 38
	normal_style.corner_radius_bottom_right = 38
	normal_style.corner_radius_bottom_left = 38
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.82, 0.82, 0.9, 0.95)
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.24, 0.28, 0.95)
	mobile_dash_button.add_theme_stylebox_override("normal", normal_style)
	mobile_dash_button.add_theme_stylebox_override("hover", normal_style)
	mobile_dash_button.add_theme_stylebox_override("pressed", pressed_style)


func _spawn_hp_hit_particles() -> void:
	var screen_width = get_viewport_rect().size.x
	var hit_fx: CPUParticles2D = CPUParticles2D.new()
	hit_fx.amount = 30
	hit_fx.lifetime = 0.5
	hit_fx.one_shot = true
	hit_fx.explosiveness = 0.8
	hit_fx.speed_scale = 1.0
	hit_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	hit_fx.emission_rect_extents = Vector2(screen_width * 0.5, 2.0)
	hit_fx.direction = Vector2(0, 1)
	hit_fx.spread = 15.0
	hit_fx.gravity = Vector2(0.0, 250.0)
	hit_fx.initial_velocity_min = 20.0
	hit_fx.initial_velocity_max = 50.0
	hit_fx.scale_amount_min = 1.0
	hit_fx.scale_amount_max = 2.0
	hit_fx.color = Color(0.85, 0.15, 0.15, 0.85)
	hit_fx.position = Vector2(screen_width * 0.5, 4.0)
	add_child(hit_fx)
	hit_fx.emitting = true
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(hit_fx.lifetime + 0.1)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(hit_fx):
			hit_fx.queue_free()
	)

func _style_web_button(btn: Button, is_accent: bool = false) -> void:
	if btn == null: return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0) # Blank
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(1, 1, 1, 0.2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.shadow_size = 4
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_offset = Vector2(0, 2)
	
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.1) # Slight tint on hover
	hover.border_color = Color(1, 1, 1, 0.5)
	
	btn.add_theme_stylebox_override('normal', normal)
	btn.add_theme_stylebox_override('hover', hover)
	btn.add_theme_stylebox_override('pressed', hover)
	btn.add_theme_stylebox_override('focus', StyleBoxEmpty.new())
	btn.add_theme_font_size_override('font_size', 12)
	btn.add_theme_color_override('font_color', Color(0.9, 0.95, 1.0, 0.9))
	
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
func _disable_focus_recursively(node: Node) -> void:
	if node is Button:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus_recursively(child)


func _play_level_up_white_flash() -> void:
	# Replaced by a player-centered flash effect in GameRoot.
	pass


func show_game_over(survived_to_end: bool) -> void:
	get_tree().paused = true
	var death_menu = get_node_or_null("DeathMenu")
	if death_menu == null:
		death_menu = Control.new()
		death_menu.name = "DeathMenu"
		death_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		var hud_layer = get_node_or_null("HudLayer")
		if hud_layer != null:
			hud_layer.add_child(death_menu)
		else:
			add_child(death_menu)
		death_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var bg = TextureRect.new()
		bg.name = "BackgroundTexture"
		death_menu.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.modulate = Color(0.0, 0.0, 0.0, 0.55)

		var initial_center = CenterContainer.new()
		initial_center.name = "CenterContainer"
		death_menu.add_child(initial_center)
		initial_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var initial_card = PanelContainer.new()
		initial_card.name = "Card"
		initial_card.custom_minimum_size = Vector2(460, 250)
		initial_center.add_child(initial_card)
		var blank_style := StyleBoxFlat.new()
		blank_style.bg_color = Color(0, 0, 0, 0.9)
		blank_style.content_margin_left = 20
		blank_style.content_margin_top = 18
		blank_style.content_margin_right = 20
		blank_style.content_margin_bottom = 18
		blank_style.shadow_size = 15
		blank_style.shadow_color = Color(0, 0, 0, 0.6)
		blank_style.shadow_offset = Vector2(0, 4)
		initial_card.add_theme_stylebox_override("panel", blank_style)
		var card_bg := TextureRect.new()
		card_bg.name = "CardTexture"
		card_bg.texture = death_card_texture
		card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_bg.stretch_mode = TextureRect.STRETCH_SCALE
		initial_card.add_child(card_bg)
		initial_card.move_child(card_bg, 0)
		var initial_vbox = VBoxContainer.new()
		initial_vbox.name = "VBox"
		initial_vbox.add_theme_constant_override("separation", 10)
		initial_card.add_child(initial_vbox)
		var initial_title = Label.new()
		initial_title.name = "Title"
		initial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial_title.add_theme_font_size_override("font_size", 30)
		initial_vbox.add_child(initial_title)

		var initial_retry_btn = Button.new()
		initial_retry_btn.text = "Retry"
		initial_retry_btn.custom_minimum_size = Vector2(0, 46)
		initial_vbox.add_child(initial_retry_btn)
		initial_retry_btn.pressed.connect(func():
			get_tree().paused = false
			death_menu.visible = false
			var gameroot = get_tree().current_scene
			if gameroot: gameroot._on_retry_button_pressed()
		)
		_apply_squish_to_button(initial_retry_btn)

		var initial_menu_btn = Button.new()
		initial_menu_btn.text = "Return to Menu"
		initial_menu_btn.custom_minimum_size = Vector2(0, 46)
		initial_vbox.add_child(initial_menu_btn)
		initial_menu_btn.pressed.connect(func():
			get_tree().paused = false
			death_menu.visible = false
			GameState.go_to_main_menu()
		)
		_apply_squish_to_button(initial_menu_btn)

	death_menu.visible = true
	var center = death_menu.get_node_or_null("CenterContainer") as CenterContainer
	if center == null:
		center = CenterContainer.new()
		center.name = "CenterContainer"
		death_menu.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card = center.get_node_or_null("Card") as PanelContainer
	if card == null:
		card = PanelContainer.new()
		card.name = "Card"
		card.custom_minimum_size = Vector2(460, 250)
		center.add_child(card)
	var root_row = card.get_node_or_null("RootRow") as HBoxContainer
	if root_row == null:
		root_row = HBoxContainer.new()
		root_row.name = "RootRow"
		root_row.add_theme_constant_override("separation", 16)
		card.add_child(root_row)
	var left_panel = root_row.get_node_or_null("SummaryVBox") as VBoxContainer
	if left_panel == null:
		left_panel = VBoxContainer.new()
		left_panel.name = "SummaryVBox"
		left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_panel.add_theme_constant_override("separation", 8)
		root_row.add_child(left_panel)
	var right_panel = root_row.get_node_or_null("ActionsVBox") as VBoxContainer
	if right_panel == null:
		right_panel = VBoxContainer.new()
		right_panel.name = "ActionsVBox"
		right_panel.custom_minimum_size = Vector2(190, 0)
		right_panel.add_theme_constant_override("separation", 10)
		root_row.add_child(right_panel)

	# Migrate any old nodes from previous layout.
	for child in card.get_children():
		if child != root_row and child.name in ["VBox", "Title", "RetryButton", "MenuButton"]:
			child.queue_free()

	var title = left_panel.get_node_or_null("Title") as Label
	if title == null:
		title = Label.new()
		title.name = "Title"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 30)
		left_panel.add_child(title)
	var scroll = left_panel.get_node_or_null("ScrollContainer") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_panel.add_child(scroll)
		
	var summary = scroll.get_node_or_null("SummaryText") as Label
	if summary == null:
		summary = Label.new()
		summary.name = "SummaryText"
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(summary)
	var retry_btn = right_panel.get_node_or_null("RetryButton") as Button
	if retry_btn == null:
		retry_btn = Button.new()
		retry_btn.name = "RetryButton"
		retry_btn.text = "Retry"
		retry_btn.custom_minimum_size = Vector2(0, 46)
		right_panel.add_child(retry_btn)
		retry_btn.pressed.connect(func():
			get_tree().paused = false
			death_menu.visible = false
			var gameroot = get_tree().current_scene
			if gameroot:
				gameroot._on_retry_button_pressed()
		)
		_apply_squish_to_button(retry_btn)
	var lobby_btn = right_panel.get_node_or_null("LobbyButton") as Button
	if lobby_btn == null:
		lobby_btn = Button.new()
		lobby_btn.name = "LobbyButton"
		lobby_btn.text = "Return to Lobby"
		lobby_btn.custom_minimum_size = Vector2(0, 46)
		right_panel.add_child(lobby_btn)
		lobby_btn.pressed.connect(func():
			get_tree().paused = false
			death_menu.visible = false
			GameState.go_to_lobby()
		)
		_apply_squish_to_button(lobby_btn)

	var menu_btn = right_panel.get_node_or_null("MenuButton") as Button
	if menu_btn == null:
		menu_btn = Button.new()
		menu_btn.name = "MenuButton"
		menu_btn.text = "Return to Menu"
		menu_btn.custom_minimum_size = Vector2(0, 46)
		right_panel.add_child(menu_btn)
		menu_btn.pressed.connect(func():
			get_tree().paused = false
			death_menu.visible = false
			GameState.go_to_main_menu()
		)
		_apply_squish_to_button(menu_btn)
	# Remove duplicate retry buttons from old versions.
	for child in right_panel.get_children():
		if child is Button and child.name != "RetryButton" and child.name != "MenuButton" and child.name != "LobbyButton":
			child.queue_free()
	var death_bg = card.get_node_or_null("CardTexture") as TextureRect
	if death_bg == null:
		death_bg = TextureRect.new()
		death_bg.name = "CardTexture"
		death_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		death_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		death_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		death_bg.stretch_mode = TextureRect.STRETCH_SCALE
		card.add_child(death_bg)
		card.move_child(death_bg, 0)
	death_bg.texture = null
	title.text = "Victory!" if survived_to_end else "You Died!"
	var last_summary: Dictionary = GameState.get_last_run_summary()
	if last_summary.is_empty():
		summary.text = "No recent run summary."
	else:
		var summary_text = "Result: %s\nLevel: %d\nTime: %s\nRun Coins: %d\nDamage Taken: %d" % [
			String(last_summary.get("result", "Run")),
			int(last_summary.get("level", 1)),
			String(last_summary.get("time_text", "00:00")),
			int(last_summary.get("run_coins", 0)),
			int(last_summary.get("damage_taken", 0))
		]
		
		var objectives = last_summary.get("objectives", [])
		if objectives is Array and not objectives.is_empty():
			summary_text += "\n\nObjectives:"
			for obj in objectives:
				summary_text += "\n- %s" % str(obj)
		elif objectives is Dictionary and not objectives.is_empty():
			summary_text += "\n\nObjectives:"
			for k in objectives.keys():
				summary_text += "\n- %s" % str(k)
				
		summary.text = summary_text




func show_level_up(upgrades: Array) -> void:
	get_tree().paused = true
	var lvl_up = get_node_or_null("LevelUpMenu")
	if lvl_up == null:
		lvl_up = Control.new()
		lvl_up.name = "LevelUpMenu"
		lvl_up.process_mode = Node.PROCESS_MODE_ALWAYS
		var hud_layer = get_node_or_null("HudLayer")
		if hud_layer != null:
			hud_layer.add_child(lvl_up)
		else:
			add_child(lvl_up)
		lvl_up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var bg = TextureRect.new()
		bg.name = "BackgroundTexture"
		lvl_up.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# bg.texture = load("res://path/to/your/texture.png") # Add your texture here!
		
		var initial_center = CenterContainer.new()
		lvl_up.add_child(initial_center)
		initial_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var initial_card = PanelContainer.new()
		initial_card.name = "Card"
		initial_card.custom_minimum_size = Vector2(400, 250)
		initial_center.add_child(initial_card)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9) # Dark opaque background
		style.shadow_size = 15
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_offset = Vector2(0, 5)
		style.content_margin_left = 20
		style.content_margin_top = 18
		style.content_margin_right = 20
		style.content_margin_bottom = 18
		initial_card.add_theme_stylebox_override("panel", style)
		
		var initial_vbox = VBoxContainer.new()
		initial_vbox.add_theme_constant_override("separation", 10)
		initial_card.add_child(initial_vbox)
		
		var title = Label.new()
		title.text = "Level Up!"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		initial_vbox.add_child(title)
		
		for i in range(3):
			var btn = Button.new()
			btn.name = "Choice" + str(i+1)
			initial_vbox.add_child(btn)
			_style_web_button(btn)
			_apply_squish_to_button(btn)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.YELLOW)
			
	lvl_up.visible = true
	
	# Update buttons
	var center = lvl_up.get_child(1)
	var vbox = center.get_child(0).get_child(0) # Get VBox inside Card
	for i in range(3):
		var btn = vbox.get_node_or_null("Choice" + str(i+1))
		if btn and i < upgrades.size():
			var upg = upgrades[i]
			if upg.has("label"):
				btn.text = upg.get("label", "")
			else:
				btn.text = upg.get("title", "Upgrade") + "\n" + upg.get("description", "")
			btn.visible = true
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)
			btn.pressed.connect(func():
				get_tree().paused = false
				lvl_up.visible = false
				var gameroot = get_tree().current_scene
				if gameroot:
					if i == 0: gameroot._on_upgrade_button_1_pressed()
					elif i == 1: gameroot._on_upgrade_button_2_pressed()
					elif i == 2: gameroot._on_upgrade_button_3_pressed()
			)
		elif btn:
			btn.visible = false
	


		



func update_hud_data(data: Dictionary) -> void:
	if time_label: time_label.text = data.get("time", "")
	if enemy_count_label: enemy_count_label.text = data.get("enemy_count", "")

	if xp_bar:
		xp_bar.max_value = data.get("xp_max", 100)
		xp_bar.value = data.get("xp_current", 0)
	if hp_bar:
		hp_bar.max_value = data.get("hp_max", 100)
		hp_bar.value = data.get("hp_current", 100)

@warning_ignore("unused_signal")
signal return_to_lobby_requested
@warning_ignore("unused_signal")
signal return_to_menu_requested

var pause_menu_panel: PanelContainer = null




	

	
func toggle_pause_menu() -> void:
	var menu = get_node_or_null("PauseMenu")
	if menu == null:
		menu = Control.new()
		menu.name = "PauseMenu"
		menu.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(menu)
		menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var bg = TextureRect.new()
		bg.name = "BackgroundTexture"
		menu.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.modulate = Color(0.0, 0.0, 0.0, 0.5)
		var center = CenterContainer.new()
		center.name = "CenterContainer"
		menu.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var card = PanelContainer.new()
		card.name = "Card"
		card.custom_minimum_size = Vector2(420, 220)
		center.add_child(card)
		var blank_style := StyleBoxFlat.new()
		blank_style.bg_color = Color(1, 1, 1, 0)
		blank_style.content_margin_left = 20
		blank_style.content_margin_top = 18
		blank_style.content_margin_right = 20
		blank_style.content_margin_bottom = 18
		blank_style.shadow_size = 15
		blank_style.shadow_color = Color(0, 0, 0, 0.6)
		blank_style.shadow_offset = Vector2(0, 4)
		blank_style.content_margin_right = 20
		blank_style.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", blank_style)
		var card_bg := TextureRect.new()
		card_bg.name = "CardTexture"
		card_bg.texture = pause_card_texture
		card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_bg.stretch_mode = TextureRect.STRETCH_SCALE
		card.add_child(card_bg)
		card.move_child(card_bg, 0)
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		card.add_child(vbox)
		var title = Label.new()
		title.text = "Paused"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		vbox.add_child(title)
		var resume_btn = Button.new()
		resume_btn.text = "Resume"
		resume_btn.custom_minimum_size = Vector2(0, 46)
		vbox.add_child(resume_btn)
		resume_btn.pressed.connect(func():
			get_tree().paused = false
			menu.visible = false
		)
		_apply_squish_to_button(resume_btn)

		var lobby_btn = Button.new()
		lobby_btn.text = "Return to Lobby"
		lobby_btn.custom_minimum_size = Vector2(0, 46)
		vbox.add_child(lobby_btn)
		lobby_btn.pressed.connect(func():
			get_tree().paused = false
			GameState.go_to_lobby()
		)
		_apply_squish_to_button(lobby_btn)

		var menu_btn = Button.new()
		menu_btn.text = "Return to Menu"
		menu_btn.custom_minimum_size = Vector2(0, 46)
		vbox.add_child(menu_btn)
		menu_btn.pressed.connect(func():
			get_tree().paused = false
			GameState.go_to_main_menu()
		)
		_apply_squish_to_button(menu_btn)
	else:
		var pause_card = menu.get_node_or_null("CenterContainer/Card") as PanelContainer
		if pause_card != null:
			var pause_bg = pause_card.get_node_or_null("CardTexture") as TextureRect
			if pause_bg == null:
				pause_bg = TextureRect.new()
				pause_bg.name = "CardTexture"
				pause_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pause_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				pause_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pause_bg.stretch_mode = TextureRect.STRETCH_SCALE
				pause_card.add_child(pause_bg)
				pause_card.move_child(pause_bg, 0)
			pause_bg.texture = pause_card_texture
		
	menu.visible = not menu.visible
	get_tree().paused = menu.visible


func _apply_squish_to_button(btn: Button) -> void:
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2
		var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
	)
	btn.button_up.connect(func():
		var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
	)






	







	

	
