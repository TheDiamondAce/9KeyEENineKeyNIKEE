import serial
import socket

# CHANGE THIS
SERIAL_PORT = "/dev/ttyUSB0"
BAUD = 115200

UDP_IP = "127.0.0.1"
UDP_PORT = 4242

ser = serial.Serial(SERIAL_PORT, BAUD)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print("Bridge running...")

while True:
    line = ser.readline().decode().strip()
    print("ESP32:", line)
    sock.sendto(line.encode(), (UDP_IP, UDP_PORT))
