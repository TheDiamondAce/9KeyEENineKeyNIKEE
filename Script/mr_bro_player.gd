extends CharacterBody2D

@export_category("Physics")
@export var max_speed: float = 1500.0
@export var acceleration: float = 2000.0
@export var friction: float = 3000.0

@export_category("Hardware")
@export var activation_threshold: int = 2

@export_category("Action")
@export var dashCooldownTimer := 1.5
@export var dashSpeed : float = 1500

@export_category("Misc")
@export var animSprite : AnimatedSprite2D

var isDashing
var lastDirection
var dashDuration = 0.51
var dashTimer = 0
var dashCooldown :float
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
	if velocity.length() != 0:
		animSprite.play("Run")
	if velocity.length() == 0:
		animSprite.play("Idle")
	if KeypadController.flip == true:
		velocity = Vector2.ZERO
	if velocity.x <0:
		animSprite.flip_h = true
	if velocity.x > 0:
		animSprite.flip_h = false
	if velocity != Vector2.ZERO:
		animSprite.play("Idle")
	else: 
		animSprite.play("Run")
		
	if isDashing:
		var direction = lastDirection
		velocity =direction * dashSpeed
		animSprite.play("Dash")
	if !isDashing:
		animSprite.play("Idle")
		
	if dashCooldown > 0:
		dashCooldown -=delta
	#if dashCooldown <=0:
		#print("Dash Ready!")
	if dashTimer > 0:
		dashTimer -= delta
	if dashTimer <=0 && isDashing:
		end_dash()
	# poll the custom hardware array
	var input_dir := _get_tilt_vector()
	
	# integrate velocity
	if input_dir != Vector2.ZERO && !isDashing:
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		#print("velocity: ", velocity)
		
	move_and_slide()

func _get_tilt_vector() -> Vector2:
	var raw_direction := Vector2.ZERO
	var active_keys := 0
	var dirString : String
	var actionString : String
	var combString
	
	for key in KEY_MATRIX:
		if Input.is_physical_key_pressed(key):
			raw_direction += KEY_MATRIX[key]
			active_keys += 1
			actionString = "Run"
		else: 
			actionString = "Idle"
						
	if active_keys < activation_threshold:
		return Vector2.ZERO
	if active_keys == 9:
		start_dash()
		
		
	lastDirection = raw_direction.normalized()
	"""if abs(lastDirection.x) > abs(lastDirection.y):
	# Closest to X-axis (Horizontal)
		if lastDirection.x > 0:
			dirString = "_Right"
		else:
			dirString = "_Left"
	else:
	# Closest to Y-axis (Vertical)
		if lastDirection.y > 0:
			dirString = "_Down"
		else:
			dirString = "_Up"
		
	combString = actionString+dirString
	animSprite.play(combString)"""
	return raw_direction.normalized()

func start_dash() -> void:
	if dashCooldown <=0:
		dashTimer = dashDuration
		isDashing = true
		print("dashed!")
		
func end_dash() -> void:
	dashTimer = 0
	isDashing = false
	if dashCooldown <=0:
		dashCooldown = dashCooldownTimer
		
	
	

	


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.


func _on_lose_timer_timeout() -> void:
	pass # Replace with function body.
