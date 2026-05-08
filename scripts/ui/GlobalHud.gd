extends Control

const MODE_COMBAT: String = "combat"
const MODE_LOBBY: String = "lobby"
const LOW_HP_PULSE_THRESHOLD: float = 0.35
const HP_HIT_FLASH_SECONDS: float = 0.22

@onready var sprite_hud: Control = $SpriteHud
@onready var top_bar: Control = get_node_or_null("TopBar") as Control
@onready var debug_panel: Control = $DebugPanel
@onready var xp_bar: Control = get_node_or_null("XpBar") as Control
@onready var hp_bar: Control = get_node_or_null("HpBar") as Control
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
@onready var dash_panel: Control = $SpriteHud/DashPanel
@onready var hp_sprite_bar: ProgressBar = $SpriteHud/TopBars/HpSpriteBar
@onready var xp_sprite_bar: ProgressBar = $SpriteHud/TopBars/XpSpriteBar
@onready var dash_count_label: Label = $SpriteHud/DashPanel/DashCountLabel
@onready var dash_cooldown_bar: TextureProgressBar = $SpriteHud/DashPanel/DashCooldownBar
@onready var mobile_dash_button: Button = $SpriteHud/MobileDashButton
@onready var run_timer_label: Label = $SpriteHud/RunTimerLabel
@onready var level_chip_label: Label = $SpriteHud/LevelChipLabel
@onready var quick_stats_label: Label = get_node_or_null("SpriteHud/QuickStatsLabel") as Label
@onready var item_grid_hud: HBoxContainer = null # Created in _ready
@onready var items_toggle_button: Button = $SpriteHud/ItemsToggleButton
@onready var talents_toggle_button: Button = $SpriteHud/TalentsToggleButton
@onready var stats_toggle_button_left: Button = $SpriteHud/StatsToggleButtonLeft
@onready var items_modal: PanelContainer = $SpriteHud/ItemsModal
@onready var items_list: Control = $SpriteHud/ItemsModal/Margin/ItemsList
@onready var item_detail_label: Control = $SpriteHud/ItemsModal/Margin/ItemDetailLabel
@onready var talents_modal: PanelContainer = $SpriteHud/TalentsModal
@onready var talents_list: Control = $SpriteHud/TalentsModal/Margin/TalentsList
@onready var talent_detail_label: Control = $SpriteHud/TalentsModal/Margin/TalentDetailLabel
@onready var stats_modal_left: PanelContainer = $SpriteHud/StatsModalLeft
@onready var stats_grid: GridContainer = null # Created in _ready
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
	if items_list != null:
		var parent = items_list.get_parent()
		var scroll = ScrollContainer.new()
		scroll.name = "ItemsScroll"
		scroll.custom_minimum_size.y = 350
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		var vbox = VBoxContainer.new()
		vbox.name = "ItemsVBox"
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)
		
		parent.add_child(scroll)
		items_list.queue_free()
		items_list = vbox
	
	if talents_list != null:
		var parent = talents_list.get_parent()
		var scroll = ScrollContainer.new()
		scroll.name = "TalentsScroll"
		scroll.custom_minimum_size.y = 350
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		
		var vbox = VBoxContainer.new()
		vbox.name = "TalentsVBox"
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)
		
		parent.add_child(scroll)
		talents_list.queue_free()
		talents_list = vbox

	# Position and size the modals for side-by-side layout
	if stats_modal_left != null:
		stats_modal_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		stats_modal_left.custom_minimum_size = Vector2(200, 400)
		stats_modal_left.position.x = 20
		_style_modal_panel(stats_modal_left)
		
	if items_modal != null:
		items_modal.set_anchors_preset(Control.PRESET_CENTER)
		items_modal.custom_minimum_size = Vector2(280, 400)
		_style_modal_panel(items_modal)
		
	if talents_modal != null:
		talents_modal.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		talents_modal.custom_minimum_size = Vector2(280, 400)
		talents_modal.position.x -= 20
		_style_modal_panel(talents_modal)

	# Replace detail labels with RichTextLabels for BBCode support
	
	# Replace detail labels with RichTextLabels for BBCode support
	for lbl_name in ["item_detail_label", "talent_detail_label"]:
		var old_lbl = get(lbl_name)
		if old_lbl != null:
			var parent = old_lbl.get_parent()
			var rich := RichTextLabel.new()
			rich.name = old_lbl.name
			rich.bbcode_enabled = true
			rich.fit_content = true
			rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(rich)
			old_lbl.queue_free()
			set(lbl_name, rich)

	# Create tiny card HUD for weapons
	var hud_parent = $SpriteHud
	var old_stacks = hud_parent.get_node_or_null("ItemStacksLabel")
	var hud_grid = HBoxContainer.new()
	hud_grid.name = "ItemGridHud"
	hud_grid.add_theme_constant_override("separation", 6)
	hud_parent.add_child(hud_grid)
	if old_stacks != null:
		old_stacks.queue_free()
	item_grid_hud = hud_grid

	_style_modal_panel(stats_modal_left)
	_style_web_button(items_toggle_button)
	_style_web_button(talents_toggle_button)
	_style_web_button(stats_toggle_button_left)

	_request_modal_relayout()
	
	# Create Dialogue Panel for NPCs
	var dialogue_panel := PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	dialogue_panel.custom_minimum_size = Vector2(500, 120)
	dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Center it and offset from bottom
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue_panel.position.y = -140
	dialogue_panel.position.x = -250
	
	var hox := HBoxContainer.new()
	hox.name = "Hbox"
	dialogue_panel.add_child(hox)
	
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hox.add_child(portrait)
	
	var text_label := RichTextLabel.new()
	text_label.name = "DialogueText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hox.add_child(text_label)
	
	add_child(dialogue_panel)
	
	set_ui_mode(MODE_COMBAT)


func show_dialogue(text: String, portrait_sprite: Texture2D = null) -> void:
	var panel = $DialoguePanel
	if panel:
		panel.visible = true
		var label = panel.get_node("Hbox/DialogueText")
		if label:
			label.text = text
		var portrait = panel.get_node("Hbox/Portrait")
		if portrait:
			portrait.texture = portrait_sprite


func set_ui_mode(mode: String) -> void:
	var combat_visible: bool = mode == MODE_COMBAT
	combat_mode_active = combat_visible
	if sprite_hud != null:
		sprite_hud.visible = true
	if top_bar != null:
		top_bar.visible = false
	if debug_panel != null:
		debug_panel.visible = combat_visible
	if xp_bar != null:
		xp_bar.visible = false
	if hp_bar != null:
		hp_bar.visible = false
	if horde_warning != null:
		horde_warning.visible = false
	if brute_warning != null:
		brute_warning.visible = false
	if bottom_bar != null:
		bottom_bar.visible = false
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
	if top_bars != null:
		top_bars.visible = combat_visible
	if dash_panel != null:
		dash_panel.visible = true
	if mobile_dash_button != null:
		mobile_dash_button.visible = true
	if quick_stats_label != null:
		quick_stats_label.visible = false
	if item_grid_hud != null:
		item_grid_hud.visible = combat_visible
	if items_modal != null:
		items_modal.visible = false
	if talents_modal != null:
		talents_modal.visible = false
	if stats_modal_left != null:
		stats_modal_left.visible = false
	if items_toggle_button != null:
		items_toggle_button.visible = combat_visible
	if talents_toggle_button != null:
		talents_toggle_button.visible = combat_visible
	if stats_toggle_button_left != null:
		stats_toggle_button_left.visible = combat_visible
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
	_item_stacks_text: String,
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
	if item_grid_hud != null:
		_rebuild_hud_item_cards(item_entries)
	
	if stats_grid != null:
		_rebuild_stats_modal(stats_modal_text, run_damage_taken)
		
	_style_modal_panel(items_modal)
	_style_modal_panel(talents_modal)
	_rebuild_items_modal(item_entries)
	_rebuild_talents_modal(talent_entries)
	_request_modal_relayout()


func _process(_delta: float) -> void:
	if combat_mode_active:
		_update_xp_wrap_anim(_delta)
		queue_redraw()


func _draw() -> void:
	if not combat_mode_active or top_bars == null:
		return
	# Keep draw math in HUD-local space so camera/world transforms can't
	# accidentally expand this draw over unrelated HUD elements (dash panel).
	var bars_origin_local: Vector2 = top_bars.position
	var bars_size: Vector2 = top_bars.size
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


func _rebuild_hud_item_cards(item_entries: Array[Dictionary]) -> void:
	for child in item_grid_hud.get_children():
		child.queue_free()
	for entry in item_entries:
		var card := _create_tiny_card(entry)
		item_grid_hud.add_child(card)


func _create_tiny_card(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(34, 34)
	
	# Prepare for sprites: Add a TextureRect
	var tex := TextureRect.new()
	tex.name = "Icon"
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(tex)
	
	var icon_tex = entry.get("icon", null)
	if icon_tex is Texture2D:
		tex.texture = icon_tex
	elif icon_tex is String and icon_tex != "":
		tex.texture = load(icon_tex)
	
	var label := Label.new()
	var name_text: String = entry.get("name", "??")
	label.text = name_text.substr(0, 1).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	
	var lv_label := Label.new()
	lv_label.text = entry.get("stacks", "").replace("Lv", "")
	lv_label.add_theme_font_size_override("font_size", 9)
	lv_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lv_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(lv_label)
	return panel


func _rebuild_items_modal(item_entries: Array[Dictionary]) -> void:
	if items_list == null: return
	for child in items_list.get_children():
		child.queue_free()
	for entry in item_entries:
		var row := _create_info_row(entry)
		items_list.add_child(row)
	if item_detail_label != null:
		item_detail_label.visible = false


func _rebuild_talents_modal(talent_entries: Array[Dictionary]) -> void:
	if talents_list == null: return
	for child in talents_list.get_children():
		child.queue_free()
	for entry in talent_entries:
		var row := _create_info_row(entry)
		talents_list.add_child(row)
	if talent_detail_label != null:
		talent_detail_label.visible = false


func _create_info_row(entry: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	var name_text: String = entry.get("name", "??")
	var lv_text: String = entry.get("stacks", "")
	
	var title_label := RichTextLabel.new()
	title_label.bbcode_enabled = true
	title_label.text = "[b]%s[/b] [color=#ffcc33]%s[/color]" % [name_text.to_upper(), lv_text]
	title_label.fit_content = true
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(title_label)
	
	var desc_label := RichTextLabel.new()
	desc_label.bbcode_enabled = true
	var effects_text: String = entry.get("effects", "")
	var body = effects_text
	if ":" in effects_text:
		body = effects_text.split(":", true, 1)[1].strip_edges()
	desc_label.text = body
	desc_label.add_theme_font_size_override("normal_font_size", 11)
	desc_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.9, 0.8))
	desc_label.fit_content = true
	vbox.add_child(desc_label)
	
	var line = ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color(1, 1, 1, 0.05)
	vbox.add_child(line)
	
	return vbox


func _rebuild_stats_modal(stats_text: String, damage_taken: int) -> void:
	if stats_grid == null: return
	for child in stats_grid.get_children():
		child.queue_free()
	
	var parts = stats_text.split("|")
	for p in parts:
		var s = p.strip_edges()
		if s == "": continue
		var label := Label.new()
		label.text = s.to_upper()
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		stats_grid.add_child(label)
	
	var dmg_label := Label.new()
	dmg_label.text = "DMG TAKEN: %d" % damage_taken
	dmg_label.add_theme_font_size_override("font_size", 12)
	dmg_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	stats_grid.add_child(dmg_label)


func _create_stat_card(stat_str: String, bg_col: Color = Color(0.15, 0.18, 0.25, 0.9)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(86, 54) # Slightly larger
	
	var style := _get_card_style()
	style.bg_color = bg_col
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var parts = stat_str.split(" ", true, 1)
	var stat_name = parts[0]
	var stat_val = parts[1] if parts.size() > 1 else ""
	
	var name_label := Label.new()
	name_label.text = stat_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0, 0.6))
	vbox.add_child(name_label)
	
	var val_label := Label.new()
	val_label.text = stat_val
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	vbox.add_child(val_label)
	
	return panel


func _create_card(entry: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	
	# Prepare for sprites: Add a TextureRect
	var tex := TextureRect.new()
	tex.name = "Icon"
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(tex)
	
	var icon_tex = entry.get("icon", null)
	if icon_tex is Texture2D:
		tex.texture = icon_tex
	elif icon_tex is String and icon_tex != "":
		tex.texture = load(icon_tex)
	
	var label := Label.new()
	var name_text: String = entry.get("name", "??")
	label.text = name_text.substr(0, 2).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	btn.add_child(label)
	
	var lv_label := Label.new()
	lv_label.text = entry.get("stacks", "")
	lv_label.add_theme_font_size_override("font_size", 12)
	lv_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	lv_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lv_label.offset_right = -8
	lv_label.offset_top = 6
	btn.add_child(lv_label)
	
	var effects_text: String = entry.get("effects", "")
	btn.pressed.connect(_on_item_entry_pressed.bind(effects_text))
	
	return btn


func _get_card_style(is_hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.24, 0.95) if not is_hover else Color(0.22, 0.26, 0.38, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.7, 1.0, 0.3) if not is_hover else Color(0.5, 0.8, 1.0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _style_modal_panel(panel: PanelContainer) -> void:
	if panel == null: return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.7, 1.0, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)



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
		item_detail_label.bbcode_enabled = true
		var bb = ""
		if ":" in effects_text:
			var parts = effects_text.split(":", true, 1)
			bb = "[b]%s[/b]\n%s" % [parts[0].strip_edges(), parts[1].strip_edges()]
		else:
			bb = effects_text
		item_detail_label.text = bb


func _on_talent_entry_pressed(effects_text: String) -> void:
	if talent_detail_label != null:
		talent_detail_label.bbcode_enabled = true
		var bb = ""
		if ":" in effects_text:
			var parts = effects_text.split(":", true, 1)
			bb = "[b]%s[/b]\n%s" % [parts[0].strip_edges(), parts[1].strip_edges()]
		else:
			bb = effects_text
		talent_detail_label.text = bb


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
		panel.reset_size()
		panel.size = compact_size
		panel.position = Vector2(x, y)
		panel.move_to_front()
		y += panel.size.y + spacing


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
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.95) if not is_accent else Color(0.3, 0.5, 0.9, 0.95)
	hover.border_color = Color(0.5, 0.8, 1.0, 0.8)
	
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
