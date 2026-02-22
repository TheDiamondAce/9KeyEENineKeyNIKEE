extends Node

signal call_started(call_sid: String)
signal call_updated(status: String, choice: Variant)
signal call_finished(choice: String)

@onready var http: HTTPRequest = HTTPRequest.new()
@onready var poll_timer: Timer = Timer.new()

enum ReqType { NONE, START_CALL, POLL_STATE }
var last_req: ReqType = ReqType.NONE

var call_sid: String = ""
var base_url: String = ""
var phone: String = ""

func _ready() -> void:
	add_child(http)
	add_child(poll_timer)

	http.request_completed.connect(_on_http_done)

	poll_timer.wait_time = 1.0
	poll_timer.one_shot = false
	poll_timer.timeout.connect(_poll_state)
	poll_timer.stop()

func start_call(p_phone: String, p_base_url: String) -> void:
	phone = p_phone.strip_edges()
	base_url = p_base_url.strip_edges().trim_suffix("/")

	if phone == "" or not phone.begins_with("+"):
		CallUi.show_ui("Invalid phone. Use +1...")
		return
	if base_url == "" or not base_url.begins_with("https://"):
		CallUi.show_ui("Invalid base_url. Must be https://...")
		return

	call_sid = ""
	poll_timer.stop()

	CallUi.show_ui("Calling the boss... answer and press 1/2.")

	var payload := {"phone": phone, "base_url": base_url}
	var url := base_url + "/start_call"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify(payload)

	last_req = ReqType.START_CALL
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		CallUi.set_status("HTTP start error: %s" % err)
		last_req = ReqType.NONE

func _poll_state() -> void:
	if call_sid == "":
		return

	last_req = ReqType.POLL_STATE
	var url := base_url + "/mission_state?call_sid=" + call_sid
	var err := http.request(url)
	if err != OK:
		CallUi.set_status("Poll error: %s" % err)

func _on_http_done(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text := body.get_string_from_utf8()

	# handle non-2xx
	if response_code < 200 or response_code >= 300:
		CallUi.set_status("HTTP %d: %s" % [response_code, text])
		last_req = ReqType.NONE
		return

	var json := JSON.new()
	if json.parse(text) != OK:
		CallUi.set_status("Bad JSON: %s" % text)
		last_req = ReqType.NONE
		return

	var data = json.data
	if not (data is Dictionary):
		CallUi.set_status("Unexpected response: %s" % text)
		last_req = ReqType.NONE
		return

	if last_req == ReqType.START_CALL:
		if not data.has("call_sid"):
			CallUi.set_status("Missing call_sid: %s" % text)
			last_req = ReqType.NONE
			return

		call_sid = str(data["call_sid"])
		emit_signal("call_started", call_sid)
		CallUi.set_status("Boss line open. Press 1 accept / 2 decline.")
		poll_timer.start()
		last_req = ReqType.NONE
		return

	if last_req == ReqType.POLL_STATE:
		if not bool(data.get("found", false)):
			CallUi.set_status("Waiting for call state...")
			last_req = ReqType.NONE
			return

		var status := str(data.get("status", "unknown"))
		var choice = data.get("choice", null)

		emit_signal("call_updated", status, choice)

		if choice == null:
			CallUi.set_status("Call status: %s (waiting input...)" % status)
			last_req = ReqType.NONE
			return

		# final choice reached
		poll_timer.stop()
		var choice_str := str(choice)

		match choice_str:
			"accepted":
				CallUi.set_status("Accepted. Antonio is picking you up...")
			"declined":
				CallUi.set_status("Declined. Boss hangs up.")
			_:
				CallUi.set_status("Invalid input. Try again.")

		emit_signal("call_finished", choice_str)
		last_req = ReqType.NONE
