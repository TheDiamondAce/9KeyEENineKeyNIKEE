extends CharacterBody2D
class_name KeypadCharacter

# Physics
@export var max_speed: float = 400.0
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0

# hardware
@export var activation_threshold: int = 2

# mapping physical numpad keys to a cartesian grid

# grid:
# 1 2 3
# 4 5 6
# 7 8 9
const KEY_MATRIX = {
	KEY_1: Vector2(1, -1),
	KEY_2: Vector2(0, -1), 
	KEY_3: Vector2(-1, -1), 
	KEY_4: Vector2(1, 0), 
	KEY_5: Vector2(0, 0), 
	KEY_6: Vector2(-1, 0), 
	KEY_7: Vector2(1, 1), 
	KEY_8: Vector2(0, 1), 
	KEY_9: Vector2(-1, 1)
}

func _physics_process(delta: float) -> void:
	# poll the custom hardware array
	var input_dir := _get_tilt_vector()
	
	# integrate velocity
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		print("velocity: ", velocity)
		
	move_and_slide()

func _get_tilt_vector() -> Vector2:
	var raw_direction := Vector2.ZERO
	var active_keys := 0
	
	for key in KEY_MATRIX:
		if Input.is_physical_key_pressed(key):
			raw_direction += KEY_MATRIX[key]
			active_keys += 1
	if active_keys < activation_threshold:
		return Vector2.ZERO
	
	return raw_direction.normalized()
