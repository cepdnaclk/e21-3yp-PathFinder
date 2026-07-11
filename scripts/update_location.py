import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"
DEVICE_ID = "pathfinder_001"


def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def update_device_location(lat, lng):
    db = init_firebase()

    device_ref = db.collection("devices").document(DEVICE_ID)

    device_ref.update({
        "gpsLat": lat,
        "gpsLng": lng,
        "online": True,
        "lastUpdated": firestore.SERVER_TIMESTAMP
    })

    print(f"[FIREBASE] Location updated: lat={lat}, lng={lng}")


if __name__ == "__main__":
    # test values
    update_device_location(7.254583, 80.591283)
