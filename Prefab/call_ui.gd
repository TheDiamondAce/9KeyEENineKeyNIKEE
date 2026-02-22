extends CanvasLayer

@onready var status_label: Label = $VBoxContainer/Status  # adjust if you have Panel

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	hide_ui()

func _on_scene_changed() -> void:
	hide_ui()

func show_ui(text: String = "") -> void:
	visible = true
	if text != "" and status_label:
		status_label.text = text

func hide_ui() -> void:
	visible = false

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text
