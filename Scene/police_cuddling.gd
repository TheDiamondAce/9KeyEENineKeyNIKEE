extends Area2D

@onready var lose_timer = $LoseTimer
var player_inside = false

func _on_body_entered(body):
	if body.name == "Player":
		player_inside = true
		lose_timer.start()

func _on_body_exited(body):
	if body.name == "Player":
		player_inside = false
		lose_timer.stop()

func lose_game():
	print("You Lose!")
	get_tree().reload_current_scene()
	
func _on_LoseTimer_timeout():
	if player_inside:
		lose_game()
