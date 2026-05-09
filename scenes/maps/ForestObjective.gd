extends "res://scenes/maps/ObjectiveBase.gd"


func _ready() -> void:
	kills_required = 25
	objective_name = "Forest"
	unlock_map_id = "snow"
	super._ready()


func _apply_difficulty() -> void:
	# Forest stays at GameRoot defaults.
	return
