extends CharacterBody2D

@export var speed = 80.0
@export var detection_range = 200.0
@export var stop_distance = 20.0
@export var knockback_force = 300.0
@export var knockback_decay = 10.0

var player = null
var knockback_velocity = Vector2.ZERO

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemy")

func _physics_process(delta):
	if player == null:
		return

	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)

	var distance = global_position.distance_to(player.global_position)

	if distance < detection_range and distance > stop_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	velocity += knockback_velocity
	move_and_slide()

func take_knockback(player_position: Vector2):
	var direction = (global_position - player_position).normalized()
	knockback_velocity = direction * knockback_force

func play_walk_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			$AnimatedSprite2D.play("enemy_right")
		else:
			$AnimatedSprite2D.play("enemy_left")
	else:
		if direction.y > 0:
			$AnimatedSprite2D.play("enemy_front")
		else:
			$AnimatedSprite2D.play("enemy_back")

func play_idle_animation():
	$AnimatedSprite2D.stop()
