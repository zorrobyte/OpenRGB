# Load or save an OpenRGB profile on the local service (SDK protocol 6, local client).
# usage: orgb_profile.py load|save <name>
import socket, struct, sys, time

action, name = sys.argv[1], sys.argv[2]
PKT = {"save": 151, "load": 152}[action]

for attempt in range(30):
    try:
        s = socket.create_connection(("127.0.0.1", 6742), timeout=2)
        break
    except OSError:
        time.sleep(2)
else:
    sys.exit("OpenRGB server not reachable")

def send(pkt_id, data=b""):
    s.sendall(b"ORGB" + struct.pack("<III", 0, pkt_id, len(data)) + data)

send(50, b"orgb_profile\0")                 # SET_CLIENT_NAME
send(40, struct.pack("<I", 6))              # REQUEST_PROTOCOL_VERSION
send(52, struct.pack("<I", 1 << 16))        # SET_CLIENT_FLAGS: REQUEST_LOCAL_CLIENT
time.sleep(0.5)
send(PKT, name.encode() + b"\0")
time.sleep(1.5)
s.close()
print(action, name, "sent")
