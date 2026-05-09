extends Node

@export var map_id: String = "forest"

var _game_root: Node = null
var _enemies_root: Node = null
var _preset: Dictionary = {}
var _extra_spawn_accum: float = 0.0
var _elite_accum: float = 0.0
var _variant_accum: float = 0.0
var _spawn_cooldown_applied: bool = false


func _ready() -> void:
	_game_root = get_node_or_null("../")
	_enemies_root = get_node_or_null("../Enemies")
	_preset = DifficultyConfig.get_preset(map_id)
	await get_tree().process_frame
	_apply_static_values()


func _process(delta: float) -> void:
	if _game_root == null:
		return
	_apply_enemy_speed()
	_apply_spawn_pressure(delta)
	_apply_elite_pressure(delta)
	_apply_variant_pressure(delta)


func _apply_static_values() -> void:
	if _game_root == null:
		return
	# GameRoot keeps most progression knobs as const values, so we only touch safe vars.
	var horde_multiplier: float = float(_preset.get("horde_cooldown_multiplier", 1.0))
	if _game_root.has_method("set"):
		if _game_root.get("horde_event_cooldown") != null:
			var cooldown: float = float(_game_root.get("horde_event_cooldown"))
			_game_root.set("horde_event_cooldown", max(10.0, cooldown * horde_multiplier))
		if not _spawn_cooldown_applied and _game_root.get("spawn_cooldown") != null:
			var spawn_multiplier: float = float(_preset.get("spawn_multiplier", 1.0))
			var spawn_cd: float = float(_game_root.get("spawn_cooldown"))
			_game_root.set("spawn_cooldown", max(0.01, spawn_cd * spawn_multiplier))
			_spawn_cooldown_applied = true
	var elite_start_seconds: float = float(_preset.get("elite_start_seconds", 120.0))
	if _game_root.get("run_time_seconds") != null:
		var run_time: float = float(_game_root.get("run_time_seconds"))
		if run_time < elite_start_seconds:
			_game_root.set("run_time_seconds", elite_start_seconds)


func _apply_enemy_speed() -> void:
	if _enemies_root == null:
		return
	var speed_multiplier: float = float(_preset.get("enemy_speed_multiplier", 1.0))
	for enemy in _enemies_root.get_children():
		if enemy == null:
			continue
		if enemy.get("elite_speed_multiplier") != null:
			enemy.set("elite_speed_multiplier", speed_multiplier)
		elif enemy.get("speed") != null:
			if not enemy.has_meta("_diff_base_speed"):
				enemy.set_meta("_diff_base_speed", float(enemy.get("speed")))
			enemy.set("speed", float(enemy.get_meta("_diff_base_speed")) * speed_multiplier)
		elif enemy.get("move_speed") != null:
			if not enemy.has_meta("_diff_base_move_speed"):
				enemy.set_meta("_diff_base_move_speed", float(enemy.get("move_speed")))
			enemy.set("move_speed", float(enemy.get_meta("_diff_base_move_speed")) * speed_multiplier)


func _apply_spawn_pressure(delta: float) -> void:
	if _game_root == null:
		return
	var extra_max: float = float(_preset.get("max_enemy_multiplier", 1.0))
	if extra_max <= 1.0:
		return
	var enemies_alive: int = 0
	if _enemies_root != null:
		enemies_alive = _enemies_root.get_child_count()
	var base_cap: int = 30
	if _game_root.has_method("_get_max_enemies_alive"):
		base_cap = int(_game_root.call("_get_max_enemies_alive"))
	var target_cap: int = int(round(float(base_cap) * extra_max))
	if enemies_alive >= target_cap:
		return
	_extra_spawn_accum += delta * (2.0 + (extra_max - 1.0) * 2.0)
	if _extra_spawn_accum < 1.0:
		return
	_extra_spawn_accum = 0.0
	if _game_root.has_method("_spawn_enemy_instance"):
		_game_root.call("_spawn_enemy_instance")


func _apply_elite_pressure(delta: float) -> void:
	if _game_root == null:
		return
	var elite_start_seconds: float = float(_preset.get("elite_start_seconds", 120.0))
	var run_time: float = 0.0
	if _game_root.get("run_time_seconds") != null:
		run_time = float(_game_root.get("run_time_seconds"))
	if run_time < elite_start_seconds:
		return
	_elite_accum += delta
	var elite_interval: float = 25.0 if map_id.to_lower() == "snow" else 12.0
	if map_id.to_lower() == "forest":
		elite_interval = 45.0
	var elite_spawn_multiplier: float = float(_preset.get("elite_spawn_multiplier", 1.0))
	elite_interval = max(3.0, elite_interval / max(elite_spawn_multiplier, 0.01))
	if _elite_accum < elite_interval:
		return
	_elite_accum = 0.0
	if _game_root.has_method("_spawn_debug_elite"):
		_game_root.call("_spawn_debug_elite")
	elif _game_root.has_method("_try_spawn_timed_elite"):
		_game_root.call("_try_spawn_timed_elite")


func _apply_variant_pressure(delta: float) -> void:
	if _game_root == null:
		return
	var force_variants: bool = bool(_preset.get("force_early_variants", false))
	var all_types_now: bool = bool(_preset.get("force_all_enemy_types", false))
	if not force_variants and not all_types_now:
		return
	_variant_accum += delta
	var interval: float = 15.0 if all_types_now else 28.0
	if _variant_accum < interval:
		return
	_variant_accum = 0.0
	if not _game_root.has_method("_spawn_debug_enemy_variant"):
		return
	if all_types_now:
		_game_root.call("_spawn_debug_enemy_variant", "basic")
		_game_root.call("_spawn_debug_enemy_variant", "brute")
		_game_root.call("_spawn_debug_enemy_variant", "blink")
	else:
		_game_root.call("_spawn_debug_enemy_variant", "brute")
