import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_KEY_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"

ROOM_COLLECTION = "streamRooms"
ROOM_ID = "test_room"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()
room_ref = db.collection(ROOM_COLLECTION).document(ROOM_ID)


def clear_collection(collection_name):
    docs = room_ref.collection(collection_name).stream()

    for doc in docs:
        doc.reference.delete()


def enable_stream():
    room_ref.set({
        "streamAvailable": True,
        "streamRequested": False,
        "streamActive": False,
        "connectionState": "available",
        "offer": {
            "sdp": "",
            "type": ""
        },
        "answer": {
            "sdp": "",
            "type": ""
        },
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)

    clear_collection("callerCandidates")
    clear_collection("calleeCandidates")

    print("[FIREBASE STREAM] Stream available = true")


def disable_stream():
    room_ref.set({
        "streamAvailable": False,
        "streamRequested": False,
        "streamActive": False,
        "connectionState": "disabled",
        "offer": {
            "sdp": "",
            "type": ""
        },
        "answer": {
            "sdp": "",
            "type": ""
        },
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)

    clear_collection("callerCandidates")
    clear_collection("calleeCandidates")

    print("[FIREBASE STREAM] Stream available = false")
