extends Node

var udp := PacketPeerUDP.new()

func _ready():
	var err = udp.bind(4242)
	if err == OK:
		print("Listening for ESP32...")
	else:
		print("Failed to bind!")

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var msg = packet.get_string_from_utf8()
		print("From ESP32:", msg)
