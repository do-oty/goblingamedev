extends RefCounted
class_name ItemCatalog

# Item schema (struct-like Dictionary):
# {
#   "id": String,
#   "name": String,
#   "type": String, # weapon/passive/placeholder
#   "max_level": int,
#   "implemented": bool,
#   "description": String,
#   "stats_by_level": Array[Dictionary]
# }
#
# Item stats schema:
# {
#   "damage": int,
#   "aoe_radius": float,
#   "cooldown": float,
#   "projectiles": int,
#   "duration": float,
#   "crit_chance": float
# }

static func get_item_pool() -> Array[Dictionary]:
	return [
		get_item_by_id("sword_slash"),
		get_item_by_id("bow_placeholder"),
		get_item_by_id("wand_placeholder")
	]


static func get_item_by_id(item_id: String) -> Dictionary:
	match item_id:
		"sword_slash":
			return {
				"id": "sword_slash",
				"name": "Sword Slash",
				"type": "weapon",
				"max_level": 8,
				"implemented": true,
				"description": "Auto-slashes toward cursor. Milestone dupes unlock extra angled slashes.",
				"stats_by_level": [
					{"damage": 5, "aoe_radius": 70.0, "cooldown": 1.15, "projectiles": 1, "duration": 0.14, "crit_chance": 0.0},
					{"damage": 8, "aoe_radius": 84.0, "cooldown": 1.00, "projectiles": 1, "duration": 0.13, "crit_chance": 0.0},
					{"damage": 12, "aoe_radius": 98.0, "cooldown": 0.88, "projectiles": 1, "duration": 0.12, "crit_chance": 0.0},
					{"damage": 17, "aoe_radius": 116.0, "cooldown": 0.76, "projectiles": 1, "duration": 0.11, "crit_chance": 0.0},
					{"damage": 23, "aoe_radius": 136.0, "cooldown": 0.64, "projectiles": 1, "duration": 0.10, "crit_chance": 0.0},
					{"damage": 30, "aoe_radius": 152.0, "cooldown": 0.58, "projectiles": 1, "duration": 0.10, "crit_chance": 0.0},
					{"damage": 38, "aoe_radius": 170.0, "cooldown": 0.52, "projectiles": 1, "duration": 0.09, "crit_chance": 0.0},
					{"damage": 48, "aoe_radius": 192.0, "cooldown": 0.46, "projectiles": 1, "duration": 0.09, "crit_chance": 0.0}
				]
			}
		"bow_placeholder":
			return {
				"id": "bow_placeholder",
				"name": "Hunter Bow",
				"type": "weapon",
				"max_level": 8,
				"implemented": true,
				"description": "Fires piercing arrows at the nearest enemy.",
				"stats_by_level": [
					{"damage": 8, "aoe_radius": 0.0, "cooldown": 1.2, "projectiles": 1, "duration": 4.0, "crit_chance": 0.05},
					{"damage": 12, "aoe_radius": 0.0, "cooldown": 1.0, "projectiles": 1, "duration": 4.0, "crit_chance": 0.05},
					{"damage": 18, "aoe_radius": 0.0, "cooldown": 0.85, "projectiles": 1, "duration": 4.5, "crit_chance": 0.05},
					{"damage": 26, "aoe_radius": 0.0, "cooldown": 0.7, "projectiles": 2, "duration": 4.5, "crit_chance": 0.10},
					{"damage": 38, "aoe_radius": 0.0, "cooldown": 0.6, "projectiles": 2, "duration": 5.0, "crit_chance": 0.10},
					{"damage": 54, "aoe_radius": 0.0, "cooldown": 0.5, "projectiles": 2, "duration": 5.0, "crit_chance": 0.15},
					{"damage": 78, "aoe_radius": 0.0, "cooldown": 0.4, "projectiles": 3, "duration": 5.5, "crit_chance": 0.15},
					{"damage": 110, "aoe_radius": 0.0, "cooldown": 0.3, "projectiles": 3, "duration": 6.0, "crit_chance": 0.20}
				]
			}
		"wand_placeholder":
			return {
				"id": "wand_placeholder",
				"name": "Arcane Wand",
				"type": "weapon",
				"max_level": 8,
				"implemented": true,
				"description": "Shoots homing arcane orbs at the nearest enemy.",
				"stats_by_level": [
					{"damage": 6, "aoe_radius": 24.0, "cooldown": 1.4, "projectiles": 1, "duration": 5.0},
					{"damage": 9, "aoe_radius": 28.0, "cooldown": 1.25, "projectiles": 1, "duration": 5.0},
					{"damage": 14, "aoe_radius": 34.0, "cooldown": 1.1, "projectiles": 1, "duration": 5.5},
					{"damage": 20, "aoe_radius": 40.0, "cooldown": 0.9, "projectiles": 2, "duration": 5.5},
					{"damage": 28, "aoe_radius": 48.0, "cooldown": 0.75, "projectiles": 2, "duration": 6.0},
					{"damage": 38, "aoe_radius": 56.0, "cooldown": 0.6, "projectiles": 2, "duration": 6.0},
					{"damage": 52, "aoe_radius": 68.0, "cooldown": 0.45, "projectiles": 3, "duration": 6.5},
					{"damage": 72, "aoe_radius": 80.0, "cooldown": 0.3, "projectiles": 3, "duration": 7.0}
				]
			}
		_:
			return {}


static func get_talent_pool() -> Array[Dictionary]:
	return [
		{
			"id": "might",
			"name": "Might",
			"description": "+20% weapon damage.",
			"stats": {"damage_multiplier": 0.20}
		},
		{
			"id": "reach",
			"name": "Reach",
			"description": "+20% sword AOE radius.",
			"stats": {"aoe_multiplier": 0.20}
		},
		{
			"id": "haste",
			"name": "Haste",
			"description": "+15% attack speed (lower cooldown).",
			"stats": {"attack_speed_multiplier": 0.15}
		},
		{
			"id": "blade_fan",
			"name": "Blade Fan",
			"description": "Adds one angled side slash (max 2).",
			"stats": {"extra_slash_count": 1}
		},
		{
			"id": "dash_mastery",
			"name": "Dash Mastery",
			"description": "-15% dash cooldown and +0.03s dash i-frames.",
			"stats": {"dash_cooldown_reduction": 0.15, "dash_iframe_bonus": 0.03}
		},
		{
			"id": "longstep",
			"name": "Longstep",
			"description": "+45 dash distance.",
			"stats": {"dash_distance_bonus": 45.0}
		},
		{
			"id": "magnet_pulse",
			"name": "Magnet Pulse",
			"description": "Periodically pulses to pull all nearby XP orbs closer.",
			"stats": {"magnet_pulse": 1}
		}
	]
