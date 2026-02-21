extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var directionX := Input.get_axis("left", "right")
	var directionY := Input.get_axis("up", "down")

	velocity.y = directionY * SPEED
	velocity.x = directionX * SPEED

	move_and_slide()
