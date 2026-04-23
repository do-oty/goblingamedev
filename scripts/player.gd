extends CharacterBody2D

const SPEED = 200.0

var last_direction := Vector2.DOWN
var is_attacking := false

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO

	# Prevent movement while attacking
	if not is_attacking:
		direction.x = Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left")
		direction.y = Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up")

		if direction != Vector2.ZERO:
			direction = direction.normalized()
			velocity = direction * SPEED
			last_direction = direction
			if not is_attacking:
				play_walk_animation(direction)
		else:
			velocity = Vector2.ZERO
			
			if not is_attacking:
				play_idle_animation()

	# Attack input (you can map this in Input Map)
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

	move_and_slide()

# -------------------------
# ANIMATIONS
# -------------------------

func play_walk_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			$AnimatedSprite2D.play("hero_right")
		else:
			$AnimatedSprite2D.play("hero_left")
	else:
		if direction.y > 0:
			$AnimatedSprite2D.play("hero_front")
		else:
			$AnimatedSprite2D.play("hero_back")

func play_idle_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			$AnimatedSprite2D.play("idle_right")
		else:
			$AnimatedSprite2D.play("idle_left")
	else:
		if last_direction.y > 0:
			$AnimatedSprite2D.play("idle_front")
		else:
			$AnimatedSprite2D.play("idle_back")

# -------------------------
# ATTACK SYSTEM
# -------------------------

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO

	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			$AnimatedSprite2D.play("attack_right")
		else:
			$AnimatedSprite2D.play("attack_left")
	else:
		if last_direction.y > 0:
			$AnimatedSprite2D.play("attack_front")
		else:
			$AnimatedSprite2D.play("attack_back")

# This function should be called when attack animation finishes
func _on_AnimatedSprite2D_animation_finished():
	if is_attacking:
		is_attacking = false
		play_idle_animation()
