extends Node

@onready var http: HTTPRequest = $"."

@export var base_url: String = "https://karter-defensible-almeta.ngrok-free.dev"
@export var phone: String = "+19258584527"

var calling := false

func _ready():
	http.request_completed.connect(_on_done)

func _unhandled_input(event):
	if event.is_action_pressed("call") && KeypadController.flip:
		print("CALLING!")
		start_call()

func start_call():
	if calling:
		return
	calling = true
	
	var url = base_url + "/start_call"
	var payload := {
	"phone": phone,
	"base_url": base_url,
	"consent": true
}
	
	var headers = PackedStringArray(["Content-Type: application/json"])
	var body = JSON.stringify(payload)
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("HTTP error:", err)
		calling = false

func _on_done(result, code, headers, body):
	print("Call response:", code, body.get_string_from_utf8())
	calling = false
