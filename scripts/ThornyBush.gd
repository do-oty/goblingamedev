extends Area2D

const DAMAGE: int = 4
const TICK_RATE: float = 0.8
const SLOW_MULTIPLIER: float = 0.65

var affected_units: Dictionary = {} # unit -> time_since_last_tick


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Ensure we have a collision shape if not defined in scene
	if get_child_count() == 0:
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 24.0
		col.shape = shape
		add_child(col)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		affected_units[body] = 0.0
		_apply_slow(body, true)


func _on_body_exited(body: Node2D) -> void:
	if body in affected_units:
		affected_units.erase(body)
		_apply_slow(body, false)


func _process(delta: float) -> void:
	var to_remove: Array = []
	for unit in affected_units.keys():
		if not is_instance_valid(unit):
			to_remove.append(unit)
			continue
			
		affected_units[unit] += delta
		if affected_units[unit] >= TICK_RATE:
			affected_units[unit] = 0.0
			_deal_damage(unit)
			
	for unit in to_remove:
		affected_units.erase(unit)


func _deal_damage(unit: Node2D) -> void:
	if unit.has_method("receive_damage"):
		unit.call("receive_damage", DAMAGE)
	elif unit.has_method("take_damage"):
		unit.call("take_damage", DAMAGE)


func _apply_slow(unit: Node2D, active: bool) -> void:
	var mult: float = SLOW_MULTIPLIER if active else (1.0 / SLOW_MULTIPLIER)
	
	if unit.is_in_group("player"):
		if "move_speed" in unit:
			unit.move_speed *= mult
	elif unit.is_in_group("enemy"):
		if "elite_speed_multiplier" in unit:
			unit.set("elite_speed_multiplier", unit.get("elite_speed_multiplier") * mult)
