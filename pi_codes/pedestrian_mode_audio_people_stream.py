# Pedestrian Mode with Audio Feedback - Raspberry Pi Implementation
#(person-only detection) with audio alerts, 320x240 stream, YOLOv8n (imgsz 256), and MJPEG live streaming
from flask import Flask, Response
from picamera2 import Picamera2
from ultralytics import YOLO
import cv2
import time
import os

# -----------------------------
# CONFIG
# -----------------------------
CONF_THRESHOLD = 0.4

VERY_CLOSE_TH = 0.10
CLOSE_TH = 0.03
MIN_AREA_TH = 0.005

IMG_SIZE = 256

CROWDED_NEARBY_TH = 3
HEAVY_CROWDED_NEARBY_TH = 4
MIN_ZONES_FOR_CROWD = 2

# Audio anti-spam settings
STABILITY_FRAMES = 3
COOLDOWN_TIME = 2.5

# Camera settings
FRAME_WIDTH = 320
FRAME_HEIGHT = 240
FRAME_AREA = FRAME_WIDTH * FRAME_HEIGHT

# -----------------------------
# AUDIO FILES
# -----------------------------
AUDIO_DIR = "/home/pathfinder/yolo-baseline/audio"

AUDIO_MAP = {
    "person left": "person_left.wav",
    "person center": "person_ahead.wav",
    "person right": "person_right.wav",
    "crowded area": "crowded.wav",
    "heavily crowded area": "heavily_crowded.wav",
    "no people": "path_clear.wav"
}

def play_audio(state):
    if state in AUDIO_MAP:
        audio_path = os.path.join(AUDIO_DIR, AUDIO_MAP[state])
        os.system(f"aplay '{audio_path}' > /dev/null 2>&1 &")

# -----------------------------
# FLASK
# -----------------------------
app = Flask(__name__)

# -----------------------------
# LOAD MODEL
# -----------------------------
model = YOLO("yolov8n.pt")

# -----------------------------
# PI CAMERA
# -----------------------------
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (FRAME_WIDTH, FRAME_HEIGHT), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()

time.sleep(2)

# -----------------------------
# STATE MANAGEMENT
# -----------------------------
candidate_state = None
candidate_count = 0
current_state = None
last_spoken_time = 0

frame_count = 0
last_display_frame = None

print("Pedestrian audio stream running...")


def process_frame(frame):
    global candidate_state, candidate_count, current_state, last_spoken_time

    results = model.predict(
        frame,
        imgsz=IMG_SIZE,
        conf=CONF_THRESHOLD,
        device="cpu",
        verbose=False
    )

    boxes = results[0].boxes

    people = []
    occupied_zones = set()
    far_count = 0
    close_count = 0
    very_close_count = 0

    for box in boxes:
        cls = int(box.cls[0])

        # COCO class 0 = person
        if cls != 0:
            continue

        x1, y1, x2, y2 = map(int, box.xyxy[0])

        area = (x2 - x1) * (y2 - y1)
        area_ratio = area / FRAME_AREA

        if area_ratio < MIN_AREA_TH:
            continue

        if area_ratio > VERY_CLOSE_TH:
            distance = "very_close"
            very_close_count += 1
        elif area_ratio > CLOSE_TH:
            distance = "close"
            close_count += 1
        else:
            distance = "far"
            far_count += 1

        center_x = (x1 + x2) / 2

        if center_x < FRAME_WIDTH / 3:
            direction = "left"
            occupied_zones.add("left")
        elif center_x < 2 * FRAME_WIDTH / 3:
            direction = "center"
            occupied_zones.add("center")
        else:
            direction = "right"
            occupied_zones.add("right")

        people.append({
            "area": area,
            "direction": direction,
            "distance": distance
        })

        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(
            frame,
            f"{direction}, {distance}",
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            (0, 255, 0),
            1
        )

    total_people = len(people)
    nearby_people = [p for p in people if p["distance"] in ["close", "very_close"]]
    nearby_count = len(nearby_people)
    zone_count = len(occupied_zones)

    # -----------------------------
    # DECISION LOGIC
    # -----------------------------
    if nearby_count >= HEAVY_CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "heavily crowded area"

    elif nearby_count >= CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "crowded area"

    elif total_people > 0:
        closest = max(people, key=lambda p: p["area"])
        new_state = f"person {closest['direction']}"

    else:
        new_state = "no people"

    # -----------------------------
    # STABILITY FILTER
    # -----------------------------
    if new_state == candidate_state:
        candidate_count += 1
    else:
        candidate_state = new_state
        candidate_count = 1

    # -----------------------------
    # AUDIO POLICY
    # -----------------------------
    if candidate_count >= STABILITY_FRAMES and candidate_state != current_state:
        current_time = time.time()

        if current_time - last_spoken_time > COOLDOWN_TIME:
            print("SPEAK:", candidate_state)
            play_audio(candidate_state)

            current_state = candidate_state
            last_spoken_time = current_time

    debug_text = (
        f"{new_state} | P:{total_people} F:{far_count} "
        f"C:{close_count} VC:{very_close_count} Z:{zone_count}"
    )

    cv2.putText(
        frame,
        debug_text,
        (10, 25),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.45,
        (0, 0, 255),
        1
    )

    return frame


def generate_frames():
    global frame_count, last_display_frame

    while True:
        start = time.time()

        frame = picam2.capture_array()
        frame = cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))

        frame_count += 1

        # Run YOLO only every 3rd frame for better Pi performance
        if frame_count % 3 == 0:
            display_frame = process_frame(frame)
            last_display_frame = display_frame.copy()
        else:
            if last_display_frame is not None:
                display_frame = last_display_frame.copy()
            else:
                display_frame = frame

        fps = 1.0 / max(time.time() - start, 1e-6)

        cv2.putText(
            display_frame,
            f"FPS:{fps:.2f}",
            (10, 55),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            (255, 0, 0),
            1
        )

        ok, buffer = cv2.imencode(
            ".jpg",
            display_frame,
            [int(cv2.IMWRITE_JPEG_QUALITY), 60]
        )

        if not ok:
            continue

        yield (
            b"--frame\r\n"
            b"Content-Type: image/jpeg\r\n\r\n" +
            buffer.tobytes() +
            b"\r\n"
        )


@app.route("/")
def index():
    return """
    <html>
      <head><title>Pedestrian Mode Stream</title></head>
      <body>
        <h2>Pedestrian Mode - Raspberry Pi</h2>
        <img src="/video" width="640">
      </body>
    </html>
    """


@app.route("/video")
def video():
    return Response(
        generate_frames(),
        mimetype="multipart/x-mixed-replace; boundary=frame"
    )


@app.route("/status")
def status():
    return {
        "current_state": current_state,
        "candidate_state": candidate_state,
        "candidate_count": candidate_count
    }


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)