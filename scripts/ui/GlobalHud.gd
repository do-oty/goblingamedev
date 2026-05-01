extends Control

const MODE_COMBAT: String = "combat"
const MODE_LOBBY: String = "lobby"
const LOW_HP_PULSE_THRESHOLD: float = 0.35
const HP_HIT_FLASH_SECONDS: float = 0.22

@onready var sprite_hud: Control = $SpriteHud
@onready var top_bar: Control = $TopBar
@onready var debug_panel: Control = $DebugPanel
@onready var xp_bar: Control = $XpBar
@onready var hp_bar: Control = $HpBar
@onready var horde_warning: Control = $HordeWarning
@onready var brute_warning: Control = $BruteChargeWarning
@onready var bottom_bar: Control = get_node_or_null("BottomBar") as Control
@onready var coin_label: Label = $CoinLabel
@onready var hint_label: Label = $HintLabel
@onready var last_run_label: Label = $LastRunLabel
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var level_up_panel: PanelContainer = $LevelUpPanel
@onready var top_bars: Control = $SpriteHud/TopBars
@onready var hp_sprite_bar: ProgressBar = $SpriteHud/TopBars/HpSpriteBar
@onready var xp_sprite_bar: ProgressBar = $SpriteHud/TopBars/XpSpriteBar
@onready var dash_count_label: Label = $SpriteHud/DashPanel/DashCountLabel
@onready var dash_cooldown_bar: TextureProgressBar = $SpriteHud/DashPanel/DashCooldownBar
@onready var mobile_dash_button: Button = $SpriteHud/MobileDashButton
@onready var run_timer_label: Label = $SpriteHud/RunTimerLabel
@onready var level_chip_label: Label = $SpriteHud/LevelChipLabel
@onready var quick_stats_label: Label = get_node_or_null("SpriteHud/QuickStatsLabel") as Label
@onready var item_stacks_label: Label = get_node_or_null("SpriteHud/ItemStacksLabel") as Label
@onready var items_toggle_button: Button = $SpriteHud/ItemsToggleButton
@onready var talents_toggle_button: Button = $SpriteHud/TalentsToggleButton
@onready var stats_toggle_button_left: Button = $SpriteHud/StatsToggleButtonLeft
@onready var items_modal: PanelContainer = $SpriteHud/ItemsModal
@onready var items_list: VBoxContainer = $SpriteHud/ItemsModal/Margin/ItemsList
@onready var item_detail_label: Label = $SpriteHud/ItemsModal/Margin/ItemDetailLabel
@onready var talents_modal: PanelContainer = $SpriteHud/TalentsModal
@onready var talents_list: VBoxContainer = $SpriteHud/TalentsModal/Margin/TalentsList
@onready var talent_detail_label: Label = $SpriteHud/TalentsModal/Margin/TalentDetailLabel
@onready var stats_modal_left: PanelContainer = $SpriteHud/StatsModalLeft
@onready var stats_modal_left_text: Label = $SpriteHud/StatsModalLeft/Margin/StatsText
@onready var status_frame: Control = get_node_or_null("SpriteHud/StatusFrame") as Control
@onready var legacy_stats_toggle_button: Button = get_node_or_null("SpriteHud/StatsToggleButton") as Button
@onready var legacy_stats_modal: PanelContainer = get_node_or_null("SpriteHud/StatsModal") as PanelContainer

var combat_mode_active: bool = false
var hp_current: int = 1
var hp_max: int = 1
var xp_current: int = 0
var xp_max: int = 1
var hp_previous: int = 1
var hp_hit_flash_until: float = 0.0
var xp_display_ratio: float = 0.0
var xp_wrap_anim_active: bool = false
var xp_wrap_anim_phase: int = 0
var xp_wrap_anim_timer: float = 0.0
var xp_wrap_target_ratio: float = 0.0
var items_modal_cache_key: String = ""
var talents_modal_cache_key: String = ""


func _ready() -> void:
	if hp_sprite_bar != null:
		hp_sprite_bar.visible = false
	if xp_sprite_bar != null:
		xp_sprite_bar.visible = false
	if items_toggle_button != null and not items_toggle_button.pressed.is_connected(_on_items_toggle_pressed):
		items_toggle_button.pressed.connect(_on_items_toggle_pressed)
	if talents_toggle_button != null and not talents_toggle_button.pressed.is_connected(_on_talents_toggle_pressed):
		talents_toggle_button.pressed.connect(_on_talents_toggle_pressed)
	if stats_toggle_button_left != null and not stats_toggle_button_left.pressed.is_connected(_on_stats_toggle_left_pressed):
		stats_toggle_button_left.pressed.connect(_on_stats_toggle_left_pressed)
	if mobile_dash_button != null:
		if not mobile_dash_button.button_down.is_connected(_on_mobile_dash_button_down):
			mobile_dash_button.button_down.connect(_on_mobile_dash_button_down)
		if not mobile_dash_button.button_up.is_connected(_on_mobile_dash_button_up):
			mobile_dash_button.button_up.connect(_on_mobile_dash_button_up)
		_style_mobile_dash_button()
	if items_modal != null:
		items_modal.visible = false
	if talents_modal != null:
		talents_modal.visible = false
	if stats_modal_left != null:
		stats_modal_left.visible = false
	if legacy_stats_toggle_button != null:
		legacy_stats_toggle_button.visible = false
	if legacy_stats_modal != null:
		legacy_stats_modal.visible = false
	if run_timer_label != null:
		run_timer_label.visible = true
	if level_chip_label != null:
		level_chip_label.visible = true
	_request_modal_relayout()
	set_ui_mode(MODE_COMBAT)


func set_ui_mode(mode: String) -> void:
	var combat_visible: bool = mode == MODE_COMBAT
	combat_mode_active = combat_visible
	if sprite_hud != null:
		sprite_hud.visible = combat_visible
	if top_bar != null:
		top_bar.visible = combat_visible
	if debug_panel != null:
		debug_panel.visible = combat_visible
	if xp_bar != null:
		xp_bar.visible = combat_visible
	if hp_bar != null:
		hp_bar.visible = combat_visible
	if horde_warning != null:
		horde_warning.visible = false
	if brute_warning != null:
		brute_warning.visible = false
	if bottom_bar != null:
		bottom_bar.visible = combat_visible
	if coin_label != null:
		coin_label.visible = true
	if hint_label != null:
		hint_label.visible = false
	if last_run_label != null:
		last_run_label.visible = not combat_visible
	if upgrade_panel != null:
		upgrade_panel.visible = false
	if game_over_panel != null:
		game_over_panel.visible = false
	if level_up_panel != null:
		level_up_panel.visible = false
	if status_frame != null:
		status_frame.visible = false
	if quick_stats_label != null:
		quick_stats_label.visible = false
	if item_stacks_label != null:
		item_stacks_label.visible = false
	if items_modal != null:
		items_modal.visible = false
	if talents_modal != null:
		talents_modal.visible = false
	if stats_modal_left != null:
		stats_modal_left.visible = false
	if legacy_stats_toggle_button != null:
		legacy_stats_toggle_button.visible = false
	if legacy_stats_modal != null:
		legacy_stats_modal.visible = false
	if run_timer_label != null:
		run_timer_label.visible = combat_visible
	if level_chip_label != null:
		level_chip_label.visible = combat_visible
	_request_modal_relayout()


func update_combat_bars(
	current_hp: int,
	max_hp: int,
	current_xp: int,
	max_xp: int,
	dash_count: int,
	dash_max: int,
	dash_cooldown_left: float,
	dash_cooldown_total: float,
	quick_stats_text: String = ""
) -> void:
	if current_hp < hp_previous:
		hp_hit_flash_until = (float(Time.get_ticks_msec()) / 1000.0) + HP_HIT_FLASH_SECONDS
		_spawn_hp_hit_particles()
	hp_current = max(current_hp, 0)
	hp_max = max(max_hp, 1)
	xp_current = max(current_xp, 0)
	xp_max = max(max_xp, 1)
	var target_xp_ratio: float = clamp(float(xp_current) / float(xp_max), 0.0, 1.0)
	_update_xp_animation(target_xp_ratio)
	hp_previous = hp_current
	if dash_count_label != null:
		dash_count_label.text = "Dash %d/%d" % [max(dash_count, 0), max(dash_max, 1)]
	if dash_cooldown_bar != null:
		var total_cd: float = max(dash_cooldown_total, 0.01)
		var left_cd: float = clamp(dash_cooldown_left, 0.0, total_cd)
		dash_cooldown_bar.max_value = total_cd
		# Invert so a full bar means dash ready.
		dash_cooldown_bar.value = total_cd - left_cd
	if quick_stats_label != null:
		quick_stats_label.text = quick_stats_text
	queue_redraw()


func update_combat_meta(
	coins: int,
	item_stacks_text: String,
	stats_modal_text: String,
	item_entries: Array[Dictionary],
	talent_entries: Array[Dictionary],
	run_timer_text: String,
	level_chip_text: String,
	run_damage_taken: int
) -> void:
	if coin_label != null:
		coin_label.text = "Run Coins: %d" % coins
	if run_timer_label != null:
		run_timer_label.text = run_timer_text
		run_timer_label.visible = true
	if level_chip_label != null:
		level_chip_label.text = level_chip_text
		level_chip_label.visible = true
	if item_stacks_label != null:
		item_stacks_label.text = item_stacks_text
	if stats_modal_left_text != null:
		var with_damage: String = "%s | DMG TAKEN %d" % [stats_modal_text, run_damage_taken]
		stats_modal_left_text.text = _format_stats_vertical(with_damage)
	_rebuild_items_modal(item_entries)
	_rebuild_talents_modal(talent_entries)


func _process(_delta: float) -> void:
	if combat_mode_active:
		_update_xp_wrap_anim(_delta)
		queue_redraw()


func _draw() -> void:
	if not combat_mode_active or top_bars == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var bars_rect_global: Rect2 = top_bars.get_global_rect()
	var bars_origin_local: Vector2 = to_local * bars_rect_global.position
	var bars_size: Vector2 = bars_rect_global.size
	if bars_size.y <= 2.0:
		return

	var hp_rect: Rect2 = Rect2(bars_origin_local.x, bars_origin_local.y, bars_size.x, 12.0)
	var xp_rect: Rect2 = Rect2(bars_origin_local.x, bars_origin_local.y + 16.0, bars_size.x, 12.0)
	var hp_ratio: float = clamp(float(hp_current) / float(max(hp_max, 1)), 0.0, 1.0)
	var xp_ratio: float = xp_display_ratio

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var low_ratio: float = clamp((LOW_HP_PULSE_THRESHOLD - hp_ratio) / LOW_HP_PULSE_THRESHOLD, 0.0, 1.0)
	var pulse: float = (sin(now_seconds * 8.0) * 0.5 + 0.5) * low_ratio
	var hit_flash_strength: float = clamp((hp_hit_flash_until - now_seconds) / HP_HIT_FLASH_SECONDS, 0.0, 1.0)

	_draw_segmented_bar(hp_rect, hp_ratio, Color(0.84, 0.1, 0.14), Color(1.0, 0.34, 0.36), false, pulse, hit_flash_strength, now_seconds)
	_draw_segmented_bar(xp_rect, xp_ratio, Color(0.2, 0.8, 0.28), Color(0.48, 1.0, 0.56), true, 0.0, 0.0, now_seconds)


func _draw_segmented_bar(
	bar_rect: Rect2,
	fill_ratio: float,
	base_color: Color,
	bright_color: Color,
	invert_gradient: bool,
	pulse_amount: float,
	hit_flash: float,
	now_seconds: float
) -> void:
	draw_rect(bar_rect, Color(0.05, 0.05, 0.05, 0.95), true)
	var segment_size: float = max(6.0, bar_rect.size.y - 2.0)
	var gap: float = 1.0
	var step_width: float = segment_size + gap
	var segment_count: int = max(1, int(floor((bar_rect.size.x - 2.0 + gap) / step_width)))
	var fill_count: int = int(floor(fill_ratio * float(segment_count)))
	var start_x: float = bar_rect.position.x + 1.0
	var start_y: float = bar_rect.position.y + 1.0

	for i in range(segment_count):
		var x: float = start_x + (float(i) * step_width)
		var seg_rect: Rect2 = Rect2(x, start_y, segment_size, bar_rect.size.y - 2.0)
		if i < fill_count:
			var t: float = float(i) / float(max(segment_count - 1, 1))
			if invert_gradient:
				t = 1.0 - t
			var seg_color: Color = base_color.lerp(bright_color, t)
			seg_color = seg_color.darkened(0.22 * (1.0 - t))
			if pulse_amount > 0.001:
				var wave: float = sin((float(i) * 0.72) - (now_seconds * 7.4)) * 0.5 + 0.5
				seg_color = seg_color.lerp(bright_color, pulse_amount * wave * 0.45)
			if hit_flash > 0.001:
				seg_color = seg_color.lerp(Color(1.0, 1.0, 1.0, 1.0), hit_flash * 0.85)
			draw_rect(seg_rect, seg_color, true)
		else:
			draw_rect(seg_rect, Color(0.12, 0.12, 0.12, 0.9), true)


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


func _rebuild_items_modal(item_entries: Array[Dictionary]) -> void:
	if items_list == null:
		return
	var key: String = JSON.stringify(item_entries)
	if key == items_modal_cache_key:
		return
	items_modal_cache_key = key
	for child in items_list.get_children():
		child.queue_free()
	var first_effect: String = ""
	for entry in item_entries:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(10, 10)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = entry.get("icon_path", "")
		if icon_path != "":
			var tex: Texture2D = load(icon_path) as Texture2D
			if tex != null:
				icon_rect.texture = tex
		row.add_child(icon_rect)
		var item_button: Button = Button.new()
		item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_button.flat = true
		item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.focus_mode = Control.FOCUS_NONE
		var icon_text: String = entry.get("icon", "")
		var name_text: String = entry.get("name", "Item")
		var stacks_text: String = entry.get("stacks", "x1")
		item_button.text = ("%s %s (%s)" % [icon_text, name_text, stacks_text]).strip_edges()
		var effects_text: String = entry.get("effects", "")
		item_button.pressed.connect(_on_item_entry_pressed.bind(effects_text))
		row.tooltip_text = effects_text
		row.add_child(item_button)
		items_list.add_child(row)
		if first_effect == "":
			first_effect = effects_text
	if item_detail_label != null:
		item_detail_label.text = first_effect if first_effect != "" else "Tap an item to view effects."


func _rebuild_talents_modal(talent_entries: Array[Dictionary]) -> void:
	if talents_list == null:
		return
	var key: String = JSON.stringify(talent_entries)
	if key == talents_modal_cache_key:
		return
	talents_modal_cache_key = key
	for child in talents_list.get_children():
		child.queue_free()
	var first_effect: String = ""
	for entry in talent_entries:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(10, 10)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = entry.get("icon_path", "")
		if icon_path != "":
			var tex: Texture2D = load(icon_path) as Texture2D
			if tex != null:
				icon_rect.texture = tex
		row.add_child(icon_rect)
		var talent_button: Button = Button.new()
		talent_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		talent_button.flat = true
		talent_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		talent_button.focus_mode = Control.FOCUS_NONE
		var icon_text: String = entry.get("icon", "")
		var name_text: String = entry.get("name", "Talent")
		var stacks_text: String = entry.get("stacks", "x1")
		talent_button.text = ("%s %s (%s)" % [icon_text, name_text, stacks_text]).strip_edges()
		var effects_text: String = entry.get("effects", "")
		talent_button.pressed.connect(_on_talent_entry_pressed.bind(effects_text))
		row.tooltip_text = effects_text
		row.add_child(talent_button)
		talents_list.add_child(row)
		if first_effect == "":
			first_effect = effects_text
	if talent_detail_label != null:
		talent_detail_label.text = first_effect if first_effect != "" else "No active talents yet."


func _on_items_toggle_pressed() -> void:
	if items_modal == null:
		return
	items_modal.visible = not items_modal.visible
	_request_modal_relayout()


func _on_talents_toggle_pressed() -> void:
	if talents_modal == null:
		return
	talents_modal.visible = not talents_modal.visible
	_request_modal_relayout()


func _on_stats_toggle_left_pressed() -> void:
	if stats_modal_left == null:
		return
	stats_modal_left.visible = not stats_modal_left.visible
	_request_modal_relayout()


func _on_item_entry_pressed(effects_text: String) -> void:
	if item_detail_label != null:
		item_detail_label.text = effects_text if effects_text != "" else "No effects."


func _on_talent_entry_pressed(effects_text: String) -> void:
	if talent_detail_label != null:
		talent_detail_label.text = effects_text if effects_text != "" else "No effects."


func _request_modal_relayout() -> void:
	_relayout_open_modals()
	call_deferred("_relayout_open_modals")


func _relayout_open_modals() -> void:
	var opened: Array[PanelContainer] = []
	if items_modal != null and items_modal.visible:
		opened.append(items_modal)
	if talents_modal != null and talents_modal.visible:
		opened.append(talents_modal)
	if stats_modal_left != null and stats_modal_left.visible:
		opened.append(stats_modal_left)

	var x: float = 16.0
	var y: float = 132.0
	var spacing: float = 8.0
	var compact_size: Vector2 = Vector2(360.0, 148.0)
	for idx in range(opened.size()):
		var panel: PanelContainer = opened[idx]
		if panel == null:
			continue
		panel.size = compact_size
		panel.position = Vector2(x, y)
		panel.move_to_front()
		y += panel.size.y + spacing


func _format_stats_vertical(stats_modal_text: String) -> String:
	if stats_modal_text == "":
		return "Stats unavailable."
	var step_one: String = stats_modal_text.replace(" | ", "\n")
	return step_one.replace("  ", "\n")


func set_lobby_last_run_text(text: String) -> void:
	if last_run_label != null:
		last_run_label.text = text


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
	if top_bars == null:
		return
	var hit_fx: CPUParticles2D = CPUParticles2D.new()
	hit_fx.amount = 22
	hit_fx.lifetime = 0.33
	hit_fx.one_shot = true
	hit_fx.explosiveness = 1.0
	hit_fx.speed_scale = 1.0
	hit_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	hit_fx.emission_rect_extents = Vector2(max(top_bars.size.x * 0.5, 40.0), 5.0)
	hit_fx.direction = Vector2(0, 1)
	hit_fx.spread = 20.0
	hit_fx.gravity = Vector2(0.0, 190.0)
	hit_fx.initial_velocity_min = 28.0
	hit_fx.initial_velocity_max = 74.0
	hit_fx.scale_amount_min = 0.6
	hit_fx.scale_amount_max = 1.25
	hit_fx.color = Color(0.95, 0.12, 0.14, 0.85)
	hit_fx.position = top_bars.position + Vector2(top_bars.size.x * 0.5, 8.0)
	add_child(hit_fx)
	hit_fx.emitting = true
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(hit_fx.lifetime + 0.1)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(hit_fx):
			hit_fx.queue_free()
	)
