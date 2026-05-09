extends "res://scenes/maps/ObjectiveBase.gd"


func _ready() -> void:
	var inherited_forest_objective: Node = get_node_or_null("../ForestObjective")
	if inherited_forest_objective != null and inherited_forest_objective != self:
		inherited_forest_objective.queue_free()
	objective_name = "Desert"
	unlock_map_id = ""
	objectives = [
		{"type": "kill", "target": "any", "required": 30, "count": 0, "desc": "Defeat any goblins"},
		{"type": "kill", "target": "sword", "required": 10, "count": 0, "desc": "Defeat Goblin Swordsmen"},
		{"type": "kill", "target": "mage", "required": 10, "count": 0, "desc": "Defeat Goblin Mages"},
		{"type": "kill", "target": "brute", "required": 5, "count": 0, "desc": "Defeat Brute Champions"},
		{"type": "kill", "target": "any", "required": 40, "count": 0, "desc": "Defeat more goblins"},
		{"type": "kill", "target": "sword", "required": 15, "count": 0, "desc": "Defeat Goblin Swordsmen"},
		{"type": "kill", "target": "mage", "required": 15, "count": 0, "desc": "Defeat Goblin Mages"},
		{"type": "kill", "target": "any", "required": 1, "count": 0, "desc": "Prepare for the Boss!"}
	]
	super._ready()


func _apply_difficulty() -> void:
	var map_root: Node = get_node_or_null("../")
	if map_root == null:
		return
	var applier: Node = get_node_or_null("../MapDifficultyApplier")
	if applier != null:
		applier.set("map_id", "desert")
		return
	if map_root.get("spawn_cooldown") != null:
		var spawn_cd: float = float(map_root.get("spawn_cooldown"))
		map_root.set("spawn_cooldown", spawn_cd * 0.6)
