extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		lose_game()

func lose_game():
	get_tree().reload_current_scene()
