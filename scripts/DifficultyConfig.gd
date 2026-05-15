extends RefCounted
class_name DifficultyConfig

const PRESETS := {
	"forest": {
		"spawn_multiplier": 1.0,
		"max_enemy_multiplier": 1.0,
		"enemy_speed_multiplier": 1.0,
		"elite_start_seconds": 120.0,
		"elite_spawn_multiplier": 1.0,
		"variant_interval_seconds": 999.0,
		"horde_cooldown_multiplier": 1.0,
		"force_all_enemy_types": false,
		"force_early_variants": false
	},
	"snow": {
		"spawn_multiplier": 0.45,
		"max_enemy_multiplier": 1.4,
		"enemy_speed_multiplier": 1.15,
		"elite_start_seconds": 180.0,
		"elite_spawn_multiplier": 1.5,
		"variant_interval_seconds": 15.0,
		"horde_cooldown_multiplier": 0.8,
		"force_all_enemy_types": false,
		"force_early_variants": true
	},
	"desert": {
		"spawn_multiplier": 0.4,
		"max_enemy_multiplier": 1.4,
		"enemy_speed_multiplier": 1.2,
		"elite_start_seconds": 150.0,
		"elite_spawn_multiplier": 1.6,
		"variant_interval_seconds": 12.0,
		"horde_cooldown_multiplier": 0.8,
		"force_all_enemy_types": true,
		"force_early_variants": true
	}
}


static func get_preset(map_id: String) -> Dictionary:
	var key: String = map_id.to_lower()
	if PRESETS.has(key):
		return PRESETS[key].duplicate(true)
	return PRESETS["forest"].duplicate(true)
