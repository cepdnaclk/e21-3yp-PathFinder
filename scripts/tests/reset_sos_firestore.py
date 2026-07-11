import firebase_admin
from firebase_admin import credentials, firestore
import traceback

SERVICE_ACCOUNT_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"
DEVICE_ID = "pathfinder_001"


def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


if __name__ == "__main__":
    try:
        db = init_firebase()

        db.collection("devices").document(DEVICE_ID).update({
            "sosActive": False,
            "lastUpdated": firestore.SERVER_TIMESTAMP
        })

        print("====================================")
        print(f"SOS RESET SUCCESSFUL FOR {DEVICE_ID}")
        print("====================================")

    except Exception as e:
        print("====================================")
        print("ERROR RESETTING SOS")
        print(str(e))
        print("====================================")
        traceback.print_exc()
