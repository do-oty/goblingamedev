extends RefCounted
class_name CharacterCatalog

# Character schema:
# {
#   "id": String,
#   "name": String,
#   "starting_item_id": String,
#   "base_stats": Dictionary,
#   "permanent_bonus": Dictionary
# }
#
# Stats keys:
# move_speed, max_health, pickup_radius, magnet_range, magnet_strength, luck,
# dash_cooldown_reduction, dash_iframe_bonus, dash_distance_bonus

static func get_character(character_id: String) -> Dictionary:
	match character_id:
		"knight":
			return {
				"id": "knight",
				"name": "Knight",
				"starting_item_id": "sword_slash",
				"base_stats": {
					"move_speed": 110.0,
					"max_health": 100,
					"pickup_radius": 20.0,
					"magnet_range": 26.0,
					"magnet_strength": 70.0,
					"luck": 0.0
				},
				# Placeholder for future NPC meta upgrades.
				"permanent_bonus": {
					"move_speed": 0.0,
					"max_health": 0,
					"pickup_radius": 0.0,
					"magnet_range": 0.0,
					"magnet_strength": 0.0,
					"luck": 0.0,
					"dash_cooldown_reduction": 0.0,
					"dash_iframe_bonus": 0.0,
					"dash_distance_bonus": 0.0
				}
			}
		_:
			return {}
