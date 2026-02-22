extends Node
var flip = false
@export var manual = false
var a_is_one := true
func fake_key(key, is_pressed):
	var ev = InputEventKey.new()
	ev.keycode = key
	ev.pressed = is_pressed
	Input.parse_input_event(ev)
	
func _input(event):
	if event is InputEventKey and not event.echo:
		var dir = EspListener.esp_direction
		if manual == false:
			if dir == 'UP':
				flip = true
			if dir == "DOWN":
				flip = false
		if Input.is_action_pressed("flip"):
			flip =!flip
			print("ON the flip side")
			
		if flip:
					
			var remap = {
				KEY_1: KEY_Y,
				KEY_2: KEY_U,
				KEY_3: KEY_I,
				KEY_4: KEY_H,
				KEY_5: KEY_J,
				KEY_6: KEY_K,
				KEY_7: KEY_N,
				KEY_8: KEY_M,
				KEY_9: KEY_A,
			}
			if event.keycode in remap:
				# Stop original key
				get_viewport().set_input_as_handled()

				# Send fake one instead
				fake_key(remap[event.keycode], event.pressed)
		else: if !flip:
			var remap = {
				KEY_1: KEY_1,
				KEY_2: KEY_2,
				KEY_3: KEY_3,
				KEY_4: KEY_4,
				KEY_5: KEY_5,
				KEY_6: KEY_6,
				KEY_7: KEY_7,
				KEY_8: KEY_8,
				KEY_9: KEY_9,
				
			}
			if event.keycode in remap:
				# Stop original key
				get_viewport().set_input_as_handled()

				# Send fake one instead
				fake_key(remap[event.keycode], event.pressed)
		
		if event.keycode == KEY_Y:
			print("yoooo")
		
		
func _ready():
	print("Remapper loaded")
