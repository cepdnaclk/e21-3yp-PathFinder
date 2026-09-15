import firebase_admin
from firebase_admin import credentials, firestore
import socket
import traceback

# ========= CONFIG =========
SERVICE_ACCOUNT_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"
DEVICE_ID = "pathfinder_001"
# ==========================


def init_firebase():
    """Initialize Firebase Admin SDK and return Firestore client."""
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def get_hostname():
    """Get Raspberry Pi hostname."""
    try:
        return socket.gethostname()
    except Exception:
        return "unknown-pi"


def send_sos_alert(db):
    """
    1. Read device info from devices/{DEVICE_ID}
    2. Create new alert in alerts collection
    3. Update device state: sosActive = True
    """
    device_ref = db.collection("devices").document(DEVICE_ID)
    device_doc = device_ref.get()

    if not device_doc.exists:
        raise Exception(f"Device document '{DEVICE_ID}' not found in Firestore")

    device_data = device_doc.to_dict()

    owner_id = device_data.get("ownerId")
    user_name = device_data.get("userName", "Unknown")
    battery_level = device_data.get("batteryLevel", 0)
    gps_lat = device_data.get("gpsLat", 0.0)
    gps_lng = device_data.get("gpsLng", 0.0)

    alert_data = {
        "batteryLevel": battery_level,
        "deviceId": DEVICE_ID,
        "lat": gps_lat,
        "lng": gps_lng,
        "status": "active",
        "timestamp": firestore.SERVER_TIMESTAMP,
        "type": "SOS",
        "userName": user_name,
        "ownerId": owner_id,
        "source": "raspberry_pi_test",
        "hostName": get_hostname()
    }

    # Create new alert document
    alert_ref = db.collection("alerts").document()
    alert_ref.set(alert_data)

    # Update device state
    device_ref.update({
        "sosActive": True,
        "lastUpdated": firestore.SERVER_TIMESTAMP,
        "online": True
    })

    print("====================================")
    print("SOS ALERT SENT SUCCESSFULLY")
    print(f"Alert document ID: {alert_ref.id}")
    print(f"Device updated: {DEVICE_ID}")
    print(f"Owner ID: {owner_id}")
    print(f"User Name: {user_name}")
    print("====================================")


if __name__ == "__main__":
    try:
        db = init_firebase()
        send_sos_alert(db)
    except Exception as e:
        print("====================================")
        print("ERROR SENDING SOS ALERT")
        print(str(e))
        print("====================================")
        traceback.print_exc()
