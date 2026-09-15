import sys
import cv2
import time
import os

sys.path.append("/home/pathfinder/pathfinder/scripts")

from camera_service import get_latest_frame, set_debug_frame
from ultralytics import YOLO

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

AUDIO_DIR = "/home/pathfinder/pathfinder/scripts/modes/pedestrian/audio"

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
# STATE
# -----------------------------
candidate_state = None
candidate_count = 0
current_state = None
last_spoken_time = 0

frame_count = 0
last_display_frame = None

MODEL_PATH = "/home/pathfinder/pathfinder/scripts/modes/pedestrian/yolov8n.pt"
model = YOLO(MODEL_PATH)
class_names = model.names


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
def should_stop(stop_event):
    return stop_event is not None and stop_event.is_set()


def get_shared_frame():
    frame = get_latest_frame()

    if frame is None:
        return None

    return cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))


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


def process_frame(frame):
    global candidate_state
    global candidate_count
    global current_state
    global last_spoken_time

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

    if nearby_count >= HEAVY_CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "heavily crowded area"

    elif nearby_count >= CROWDED_NEARBY_TH and zone_count >= MIN_ZONES_FOR_CROWD:
        new_state = "crowded area"

    elif navigation_targets:
        closest = max(navigation_targets, key=lambda t: t["closeness_score"])
        new_state = f"{closest['type']} {closest['direction']}"

    else:
        new_state = "no people"

    if new_state == candidate_state:
        candidate_count += 1
    else:
        candidate_state = new_state
        candidate_count = 1

    if candidate_count >= STABILITY_FRAMES and candidate_state != current_state:
        now = time.time()

        if now - last_spoken_time > COOLDOWN_TIME:
            print("[PEDESTRIAN] SPEAK:", candidate_state)
            play_audio(candidate_state)
            current_state = candidate_state
            last_spoken_time = now

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


def run_pedestrian_mode(stop_event=None):
    global frame_count
    global last_display_frame

    print("[PEDESTRIAN] Pedestrian mode started")

    while not should_stop(stop_event):
        start = time.time()

        frame = get_shared_frame()

        if frame is None:
            time.sleep(0.05)
            continue

        frame_count += 1

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
        set_debug_frame(display_frame)

        # This mode does not stream directly anymore.
        # The shared stream_server.py handles /video_debug and /video_live.
        time.sleep(0.03)

    print("[PEDESTRIAN] Pedestrian mode stopped")
