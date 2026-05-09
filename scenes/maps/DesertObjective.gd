extends "res://scenes/maps/ObjectiveBase.gd"


func _ready() -> void:
	var inherited_forest_objective: Node = get_node_or_null("../ForestObjective")
	if inherited_forest_objective != null and inherited_forest_objective != self:
		inherited_forest_objective.queue_free()
	kills_required = 100
	objective_name = "Desert"
	unlock_map_id = ""
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
