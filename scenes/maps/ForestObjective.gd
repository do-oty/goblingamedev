extends "res://scenes/maps/ObjectiveBase.gd"


func _ready() -> void:
	objective_name = "Forest"
	unlock_map_id = "snow"
	objectives = [
		{"type": "kill", "target": "any", "required": 15, "count": 0, "desc": "Defeat any goblins"},
		{"type": "kill", "target": "sword", "required": 5, "count": 0, "desc": "Defeat Goblin Swordsmen"},
		{"type": "kill", "target": "any", "required": 20, "count": 0, "desc": "Defeat more goblins"},
		{"type": "kill", "target": "brute", "required": 1, "count": 0, "desc": "Defeat a Brute Champion"},
		{"type": "kill", "target": "mage", "required": 2, "count": 0, "desc": "Defeat Goblin Mages"}
	]
	super._ready()


func _apply_difficulty() -> void:
	# Forest stays at GameRoot defaults.
	return
