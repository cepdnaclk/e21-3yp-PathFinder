# Pedestrian + Obstacle Mode with Audio Feedback - Raspberry Pi
# Detects people and selected obstacles, gives stable audio alerts, and streams MJPEG output.

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
IMG_SIZE = 256

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
FRAME_AREA = FRAME_WIDTH * FRAME_HEIGHT

VERY_CLOSE_TH = 0.10
CLOSE_TH = 0.03

MIN_PERSON_AREA_TH = 0.005
MIN_OBSTACLE_AREA_TH = 0.01
MIN_BOTTOM_RATIO = 0.35

BOTTOM_WEIGHT = 0.75
AREA_WEIGHT = 0.25

CROWDED_NEARBY_TH = 3
HEAVY_CROWDED_NEARBY_TH = 4
MIN_ZONES_FOR_CROWD = 2

STABILITY_FRAMES = 3
COOLDOWN_TIME = 2.5

OBSTACLE_CLASSES = {
    "chair",
    "couch",
    "bed",
    "dining table",
    "potted plant",
    "bench",
    "traffic light",
    "stop sign",
}

AUDIO_DIR = "/home/pathfinder/yolo-baseline/audio"

AUDIO_MAP = {
    "person left": "person_left.wav",
    "person center": "person_ahead.wav",
    "person right": "person_right.wav",
    "obstacle left": "obstacle_left.wav",
    "obstacle center": "obstacle_ahead.wav",
    "obstacle right": "obstacle_right.wav",
    "crowded area": "crowded.wav",
    "heavily crowded area": "heavily_crowded.wav",
    "no people": "path_clear.wav",
}

# -----------------------------
# AUDIO
# -----------------------------
def play_audio(state):
    audio_file = AUDIO_MAP.get(state)
    if audio_file:
        audio_path = os.path.join(AUDIO_DIR, audio_file)
        os.system(f"aplay '{audio_path}' > /dev/null 2>&1 &")

# -----------------------------
# HELPERS
# -----------------------------
def get_direction(center_x):
    if center_x < FRAME_WIDTH / 3:
        return "left"
    elif center_x < 2 * FRAME_WIDTH / 3:
        return "center"
    else:
        return "right"


def get_distance_label(area_ratio):
    if area_ratio > VERY_CLOSE_TH:
        return "very_close"
    elif area_ratio > CLOSE_TH:
        return "close"
    else:
        return "far"

# -----------------------------
# FLASK
# -----------------------------
app = Flask(__name__)

# -----------------------------
# MODEL
# -----------------------------
model = YOLO("yolov8n.pt")
class_names = model.names

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
# STATE
# -----------------------------
candidate_state = None
candidate_count = 0
current_state = None
last_spoken_time = 0

frame_count = 0
last_display_frame = None

print("Pedestrian + obstacle audio stream running.")


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
    navigation_targets = []
    occupied_zones = set()

    close_count = 0
    very_close_count = 0

    for box in boxes:
        cls = int(box.cls[0])
        class_name = class_names[cls]
        conf = float(box.conf[0])

        x1, y1, x2, y2 = map(int, box.xyxy[0])

        area = (x2 - x1) * (y2 - y1)
        area_ratio = area / FRAME_AREA

        center_x = (x1 + x2) / 2
        direction = get_direction(center_x)

        bottom_ratio = y2 / FRAME_HEIGHT
        closeness_score = (BOTTOM_WEIGHT * bottom_ratio) + (AREA_WEIGHT * area_ratio)

        if bottom_ratio < MIN_BOTTOM_RATIO:
            continue

        target_type = None
        box_color = None
        label = None

        if class_name == "person":
            if area_ratio < MIN_PERSON_AREA_TH:
                continue

            distance = get_distance_label(area_ratio)

            if distance == "very_close":
                very_close_count += 1
            elif distance == "close":
                close_count += 1

            occupied_zones.add(direction)

            people.append({
                "direction": direction,
                "distance": distance,
                "area_ratio": area_ratio
            })

            target_type = "person"
            box_color = (0, 255, 0)
            label = f"person {direction}"

        elif class_name in OBSTACLE_CLASSES:
            if area_ratio < MIN_OBSTACLE_AREA_TH:
                continue

            target_type = "obstacle"
            box_color = (255, 0, 0)
            label = f"obstacle {direction}"

        else:
            continue

        navigation_targets.append({
            "type": target_type,
            "direction": direction,
            "class_name": class_name,
            "area_ratio": area_ratio,
            "bottom_ratio": bottom_ratio,
            "closeness_score": closeness_score,
            "conf": conf
        })

        cv2.rectangle(frame, (x1, y1), (x2, y2), box_color, 2)
        cv2.putText(
            frame,
            label,
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            box_color,
            1
        )

    nearby_count = close_count + very_close_count
    zone_count = len(occupied_zones)

    # -----------------------------
    # DECISION LOGIC
    # -----------------------------
    if nearby_count >= HEAVY_CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "heavily crowded area"

    elif nearby_count >= CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "crowded area"

    elif navigation_targets:
        closest = max(navigation_targets, key=lambda t: t["closeness_score"])
        new_state = f"{closest['type']} {closest['direction']}"

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
        now = time.time()

        if now - last_spoken_time > COOLDOWN_TIME:
            print("SPEAK:", candidate_state)
            play_audio(candidate_state)
            current_state = candidate_state
            last_spoken_time = now

    # Minimal frame display
    cv2.putText(
        frame,
        f"{new_state}",
        (10, 25),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        (0, 0, 255),
        2
    )

    return frame


def generate_frames():
    global frame_count, last_display_frame

    while True:
        start = time.time()

        frame = picam2.capture_array()
        frame = cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))

        frame_count += 1

        # Run YOLO every 3rd frame for Pi performance
        if frame_count % 3 == 0:
            display_frame = process_frame(frame)
            last_display_frame = display_frame.copy()
        else:
            display_frame = last_display_frame.copy() if last_display_frame is not None else frame

        fps = 1.0 / max(time.time() - start, 1e-6)

        cv2.putText(
            display_frame,
            f"FPS:{fps:.2f}",
            (10, 50),
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
      <head><title>Pedestrian + Obstacle Mode</title></head>
      <body>
        <h2>Pedestrian + Obstacle Mode - Raspberry Pi</h2>
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