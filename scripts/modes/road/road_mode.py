import sys
import time
import cv2
import os

sys.path.append("/home/pathfinder/pathfinder/scripts")

from camera_service import get_latest_frame, set_debug_frame
from ultralytics import YOLO

CONF_THRESHOLD = 0.4
IMG_SIZE = 256

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
FRAME_AREA = FRAME_WIDTH * FRAME_HEIGHT

VEHICLE_CLASSES = {2, 3, 5, 7}

DANGER_BOTTOM_RATIO = 0.85
DANGER_AREA_RATIO = 0.30
WARNING_BOTTOM_RATIO = 0.65
WARNING_AREA_RATIO = 0.12

APPROACH_AREA_GROWTH = 800
APPROACH_BOTTOM_GROWTH = 8
CENTER_MATCH_THRESHOLD = FRAME_WIDTH * 0.25

TOP_VEHICLES = 3
GLOBAL_MOTION_THRESHOLD = 18
STATIC_AREA_CHANGE_TH = 200
STATIC_BOTTOM_CHANGE_TH = 3
STATIC_FRAME_LIMIT = 3

UNSAFE_COOLDOWN = 2.5
UNSAFE_CONFIRM_FRAMES = 2

AUDIO_DIR = "/home/pathfinder/pathfinder/scripts/modes/road/audio"

AUDIO_MAP = {
    "start": "road_mode.wav",
    "turn_left": "turn_left.wav",
    "turn_right": "turn_right.wav",
    "scanning": "scanning.wav",
    "safe": "safe.wav",
    "unsafe": "unsafe.wav",
}

display_status = "Road mode starting"

MODEL_PATH = "/home/pathfinder/pathfinder/scripts/modes/road/yolov8n.pt"
model = YOLO(MODEL_PATH)


def play_audio(key):
    file = AUDIO_MAP.get(key)

    if not file:
        return

    path = os.path.join(AUDIO_DIR, file)
    os.system(f"aplay '{path}' > /dev/null 2>&1")


def should_stop(stop_event):
    return stop_event is not None and stop_event.is_set()


def get_shared_frame():
    frame = get_latest_frame()

    if frame is None:
        return None

    return cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))


def get_global_motion_score(prev_gray, current_gray):
    if prev_gray is None:
        return 0

    diff = cv2.absdiff(prev_gray, current_gray)
    return diff.mean()


def extract_top_vehicles(frame):
    results = model.predict(
        frame,
        imgsz=IMG_SIZE,
        conf=CONF_THRESHOLD,
        device="cpu",
        verbose=False
    )

    boxes = results[0].boxes
    vehicles = []

    if boxes is None:
        return vehicles, frame

    for box in boxes:
        cls = int(box.cls[0])

        if cls not in VEHICLE_CLASSES:
            continue

        x1, y1, x2, y2 = map(int, box.xyxy[0])

        area = (x2 - x1) * (y2 - y1)
        bottom_y = y2
        center_x = (x1 + x2) / 2

        bottom_ratio = bottom_y / FRAME_HEIGHT
        area_ratio = area / FRAME_AREA
        score = (0.7 * bottom_ratio) + (0.3 * area_ratio)

        label = "VEHICLE"
        color = (0, 255, 0)

        if bottom_ratio > DANGER_BOTTOM_RATIO or area_ratio > DANGER_AREA_RATIO:
            label = "DANGER"
            color = (0, 0, 255)
        elif bottom_ratio > WARNING_BOTTOM_RATIO or area_ratio > WARNING_AREA_RATIO:
            label = "WARNING"
            color = (0, 165, 255)

        vehicles.append({
            "area": area,
            "bottom_y": bottom_y,
            "center_x": center_x,
            "bottom_ratio": bottom_ratio,
            "area_ratio": area_ratio,
            "score": score,
            "label": label,
            "box": (x1, y1, x2, y2),
        })

        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        cv2.putText(
            frame,
            label,
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            color,
            1
        )

    vehicles.sort(key=lambda v: v["score"], reverse=True)
    return vehicles[:TOP_VEHICLES], frame


def detect_approaching(current_vehicles, previous_vehicles):
    approaching_count = 0
    static_count = 0

    for current in current_vehicles:
        best_prev = None
        best_shift = None

        for prev in previous_vehicles:
            center_shift = abs(current["center_x"] - prev["center_x"])

            if center_shift < CENTER_MATCH_THRESHOLD:
                if best_shift is None or center_shift < best_shift:
                    best_prev = prev
                    best_shift = center_shift

        if best_prev is None:
            continue

        area_growth = current["area"] - best_prev["area"]
        bottom_growth = current["bottom_y"] - best_prev["bottom_y"]

        if abs(area_growth) < STATIC_AREA_CHANGE_TH and abs(bottom_growth) < STATIC_BOTTOM_CHANGE_TH:
            static_count += 1

        if area_growth > APPROACH_AREA_GROWTH or bottom_growth > APPROACH_BOTTOM_GROWTH:
            approaching_count += 1

    return approaching_count, static_count


def evaluate_direction(stop_event=None, total_duration=2.5, ignore_initial=0.5):
    global display_status

    start_time = time.time()

    danger_count = 0
    warning_count = 0
    approaching_count = 0

    previous_vehicles = []
    prev_gray = None
    static_frames = 0

    while time.time() - start_time < total_duration:
        if should_stop(stop_event):
            return "STOPPED"

        frame = get_shared_frame()

        if frame is None:
            time.sleep(0.05)
            continue

        elapsed = time.time() - start_time

        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        motion_score = get_global_motion_score(prev_gray, gray)
        prev_gray = gray

        cv2.putText(
            frame,
            display_status,
            (10, 25),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (0, 0, 255),
            2
        )
        set_debug_frame(frame)

        if elapsed < ignore_initial:
            continue

        if motion_score > GLOBAL_MOTION_THRESHOLD:
            cv2.putText(
                frame,
                "Camera moving",
                (10, 50),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.45,
                (0, 165, 255),
                1
            )

            set_debug_frame(frame)
            continue

        current_vehicles, frame = extract_top_vehicles(frame)
        set_debug_frame(frame)

        for v in current_vehicles:
            if v["bottom_ratio"] > DANGER_BOTTOM_RATIO or v["area_ratio"] > DANGER_AREA_RATIO:
                danger_count += 1
            elif v["bottom_ratio"] > WARNING_BOTTOM_RATIO or v["area_ratio"] > WARNING_AREA_RATIO:
                warning_count += 1

        approaching, static_count = detect_approaching(current_vehicles, previous_vehicles)
        approaching_count += approaching

        if static_count >= len(current_vehicles) and len(current_vehicles) > 0:
            static_frames += 1
        else:
            static_frames = 0

        previous_vehicles = current_vehicles

    if danger_count > 0 and static_frames < STATIC_FRAME_LIMIT:
        return "UNSAFE"

    if approaching_count >= 2:
        return "UNSAFE"

    if warning_count >= 3:
        return "UNSAFE"

    return "SAFE"


def monitor_crossing(stop_event=None):
    global display_status

    display_status = "Crossing monitor"
    print("[ROAD] Crossing monitor started")

    last_unsafe_time = 0
    unsafe_frames = 0

    previous_vehicles = []
    prev_gray = None
    static_frames = 0

    while not should_stop(stop_event):
        frame = get_shared_frame()

        if frame is None:
            time.sleep(0.05)
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        motion_score = get_global_motion_score(prev_gray, gray)
        prev_gray = gray

        if motion_score > GLOBAL_MOTION_THRESHOLD:
            continue

        current_vehicles, frame = extract_top_vehicles(frame)
        set_debug_frame(frame)

        unsafe_now = False

        for v in current_vehicles:
            if v["bottom_ratio"] > WARNING_BOTTOM_RATIO or v["area_ratio"] > WARNING_AREA_RATIO:
                unsafe_now = True

        approaching, static_count = detect_approaching(current_vehicles, previous_vehicles)

        if approaching > 0:
            unsafe_now = True

        if static_count >= len(current_vehicles) and len(current_vehicles) > 0:
            static_frames += 1
        else:
            static_frames = 0

        if static_frames >= STATIC_FRAME_LIMIT and approaching == 0:
            unsafe_now = False

        if unsafe_now:
            unsafe_frames += 1
        else:
            unsafe_frames = 0

        now = time.time()

        if unsafe_frames >= UNSAFE_CONFIRM_FRAMES:
            if now - last_unsafe_time > UNSAFE_COOLDOWN:
                print("[ROAD] Unsafe vehicle detected")
                play_audio("unsafe")
                last_unsafe_time = now

        previous_vehicles = current_vehicles
        time.sleep(0.03)

    print("[ROAD] Crossing monitor stopped")


def run_road_mode(stop_event=None):
    global display_status

    print("[ROAD] Road mode started")

    play_audio("start")
    display_status = "Road crossing mode"
    time.sleep(1)

    if should_stop(stop_event):
        return

    display_status = "Turn left"
    print("[ROAD] Turn left")
    play_audio("turn_left")
    time.sleep(1)

    display_status = "Scanning left"
    print("[ROAD] Scanning left")
    play_audio("scanning")
    left_result = evaluate_direction(stop_event)

    if should_stop(stop_event):
        return

    display_status = f"Left: {left_result}"
    print(f"[ROAD] Left result: {left_result}")
    play_audio("safe" if left_result == "SAFE" else "unsafe")
    time.sleep(1)

    display_status = "Turn right"
    print("[ROAD] Turn right")
    play_audio("turn_right")
    time.sleep(1)

    display_status = "Scanning right"
    print("[ROAD] Scanning right")
    play_audio("scanning")
    right_result = evaluate_direction(stop_event)

    if should_stop(stop_event):
        return

    display_status = f"Right: {right_result}"
    print(f"[ROAD] Right result: {right_result}")
    play_audio("safe" if right_result == "SAFE" else "unsafe")
    time.sleep(1)

    monitor_crossing(stop_event)
    print("[ROAD] Road mode ended")
