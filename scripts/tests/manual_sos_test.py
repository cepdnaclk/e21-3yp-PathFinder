import firebase_admin
from firebase_admin import credentials, firestore
import socket
import traceback

SERVICE_ACCOUNT_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"
DEVICE_ID = "pathfinder_001"


def init_firebase():
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    return firestore.client()


def get_hostname():
    try:
        return socket.gethostname()
    except Exception:
        return "unknown-pi"


def send_sos_alert(db):
    device_ref = db.collection("devices").document(DEVICE_ID)
    device_doc = device_ref.get()

    if not device_doc.exists:
        raise Exception(f"Device document '{DEVICE_ID}' not found in Firestore")

    device_data = device_doc.to_dict()

    alert_data = {
        "batteryLevel": device_data.get("batteryLevel", 0),
        "deviceId": DEVICE_ID,
        "lat": device_data.get("gpsLat", 0.0),
        "lng": device_data.get("gpsLng", 0.0),
        "status": "active",
        "timestamp": firestore.SERVER_TIMESTAMP,
        "type": "SOS",
        "userName": device_data.get("userName", "Unknown"),
        "ownerId": device_data.get("ownerId"),
        "source": "raspberry_pi_manual_test",
        "hostName": get_hostname()
    }

    alert_ref = db.collection("alerts").document()
    alert_ref.set(alert_data)

    device_ref.update({
        "sosActive": True,
        "lastUpdated": firestore.SERVER_TIMESTAMP,
        "online": True
    })

    print(f"[SUCCESS] SOS sent. Alert ID: {alert_ref.id}")


def reset_sos(db):
    device_ref = db.collection("devices").document(DEVICE_ID)
    device_ref.update({
        "sosActive": False,
        "lastUpdated": firestore.SERVER_TIMESTAMP
    })

    print("[SUCCESS] SOS reset done.")


if __name__ == "__main__":
    try:
        db = init_firebase()

        while True:
            cmd = input("Enter command (sos/reset/exit): ").strip().lower()

            if cmd == "sos":
                send_sos_alert(db)
            elif cmd == "reset":
                reset_sos(db)
            elif cmd == "exit":
                print("Exiting...")
                break
            else:
                print("Unknown command. Type sos, reset, or exit.")

    except Exception as e:
        print("[ERROR]", str(e))
        traceback.print_exc()
