import asyncio
import fractions
import time
import uuid

import av
import firebase_admin
from firebase_admin import credentials, firestore

from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack, RTCConfiguration, RTCIceServer
from aiortc.sdp import candidate_from_sdp, candidate_to_sdp

from camera_service import get_latest_frame

SERVICE_KEY_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"

ROOM_COLLECTION = "streamRooms"
ROOM_ID = "test_room"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()
room_ref = db.collection(ROOM_COLLECTION).document(ROOM_ID)


class SharedCameraVideoTrack(VideoStreamTrack):
    def __init__(self):
        super().__init__()
        self.counter = 0
        self.fps = 15

    async def recv(self):
        await asyncio.sleep(1 / self.fps)

        frame = get_latest_frame()

        while frame is None:
            await asyncio.sleep(0.05)
            frame = get_latest_frame()

        video_frame = av.VideoFrame.from_ndarray(frame, format="rgb24")
        video_frame.pts = self.counter
        video_frame.time_base = fractions.Fraction(1, self.fps)

        self.counter += 1
        return video_frame


def is_real_offer(data):
    offer = data.get("offer")

    if not offer:
        return False

    sdp = offer.get("sdp", "")
    offer_type = offer.get("type", "")

    return offer_type == "offer" and isinstance(sdp, str) and sdp.startswith("v=0")


async def wait_for_offer():
    print("[WEBRTC] Waiting for streamAvailable=true and real offer...")

    last_seen_sdp = None

    while True:
        doc = room_ref.get()

        if doc.exists:
            data = doc.to_dict()

            stream_available = data.get("streamAvailable") is True
            stream_requested = data.get("streamRequested") is True

            if stream_available and stream_requested and is_real_offer(data):
                offer = data["offer"]

                if offer["sdp"] != last_seen_sdp:
                    print("[WEBRTC] Real offer found")
                    return offer

        await asyncio.sleep(1)


async def add_existing_caller_candidates(pc, added_candidate_ids):
    docs = room_ref.collection("callerCandidates").stream()

    for cand_doc in docs:
        if cand_doc.id in added_candidate_ids:
            continue

        cand = cand_doc.to_dict()

        if not cand.get("candidate"):
            continue

        try:
            candidate_sdp = cand["candidate"].replace("candidate:", "", 1)
            candidate = candidate_from_sdp(candidate_sdp)
            candidate.sdpMid = cand.get("sdpMid")
            candidate.sdpMLineIndex = cand.get("sdpMLineIndex")

            await pc.addIceCandidate(candidate)
            added_candidate_ids.add(cand_doc.id)

            print("[WEBRTC] Caller ICE candidate added")
        except Exception as e:
            print("[WEBRTC] Failed to add caller candidate:", e)


async def poll_caller_candidates(pc, added_candidate_ids):
    while pc.connectionState not in ["closed", "failed"]:
        await add_existing_caller_candidates(pc, added_candidate_ids)
        await asyncio.sleep(1)


async def handle_one_session():
    offer = await wait_for_offer()

    session_id = str(uuid.uuid4())[:8]
    print(f"[WEBRTC] Starting session {session_id}")

    ice_servers = [
        RTCIceServer(urls=["stun:stun.relay.metered.ca:80"]),

        RTCIceServer(
            urls="turn:global.relay.metered.ca:80",
            username="171b155e7e3b7363fdc462a5",
            credential="vYNGMpoS3eprvmEZ",
        ),
    ]

    pc = RTCPeerConnection(
        configuration=RTCConfiguration(
            iceServers=ice_servers
        )
    )
    added_candidate_ids = set()

    video_track = SharedCameraVideoTrack()
    pc.addTrack(video_track)

    @pc.on("connectionstatechange")
    async def on_connectionstatechange():
        print(f"[WEBRTC] Connection state: {pc.connectionState}")

        room_ref.set({
            "streamActive": pc.connectionState == "connected",
            "connectionState": pc.connectionState,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        if pc.connectionState in ["failed", "closed", "disconnected"]:
            await pc.close()

    @pc.on("icecandidate")
    async def on_icecandidate(candidate):
        if candidate is None:
            return

        candidate_data = {
            "candidate": "candidate:" + candidate_to_sdp(candidate),
            "sdpMid": candidate.sdpMid,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }

        room_ref.collection("calleeCandidates").add(candidate_data)
        print("[WEBRTC] Callee ICE candidate added")

    await pc.setRemoteDescription(
        RTCSessionDescription(
            sdp=offer["sdp"],
            type=offer["type"]
        )
    )

    print("[WEBRTC] Remote offer set")

    await add_existing_caller_candidates(pc, added_candidate_ids)

    candidate_task = asyncio.create_task(
        poll_caller_candidates(pc, added_candidate_ids)
    )

    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)

    room_ref.set({
        "answer": {
            "type": pc.localDescription.type,
            "sdp": pc.localDescription.sdp,
        },
        "streamActive": False,
        "connectionState": "answer_created",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)

    print("[WEBRTC] Answer written to Firebase")
    print("[WEBRTC] Waiting for WebRTC connection...")

    while True:
        doc = room_ref.get()
        data = doc.to_dict() if doc.exists else {}

        if data.get("streamAvailable") is False or data.get("streamRequested") is False:
            print("[WEBRTC] Stream disabled/request ended")
            break

        if pc.connectionState in ["failed", "closed", "disconnected"]:
            print("[WEBRTC] Connection ended")
            break

        await asyncio.sleep(1)

    candidate_task.cancel()

    try:
        await candidate_task
    except asyncio.CancelledError:
        pass
    except Exception as e:
        print("[WEBRTC] Candidate task cleanup:", e)

    await asyncio.sleep(0.5)

    try:
        await pc.close()
    except Exception as e:
        print("[WEBRTC] PeerConnection close cleanup:", e)

    await asyncio.sleep(0.5)

    room_ref.set({
        "streamActive": False,
        "connectionState": "available",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)

    print(f"[WEBRTC] Session {session_id} closed")


async def webrtc_loop():
    print("[WEBRTC] WebRTC service started")

    while True:
        try:
            await handle_one_session()
        except Exception as e:
            print("[WEBRTC ERROR]", e)

            room_ref.set({
                "streamActive": False,
                "connectionState": "error",
                "lastError": str(e),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            await asyncio.sleep(3)


def start_webrtc_service():
    asyncio.run(webrtc_loop())


if __name__ == "__main__":
    start_webrtc_service()
