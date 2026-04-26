from picamera2 import Picamera2
from ultralytics import YOLO
import time
import cv2
import os

# -----------------------------
# CONFIG
# -----------------------------
CONF_THRESHOLD = 0.4
IMG_SIZE = 256

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
FRAME_AREA = FRAME_WIDTH * FRAME_HEIGHT

VEHICLE_CLASSES = {2, 3, 5, 7}  # car, motorcycle, bus, truck

# -----------------------------
# AUDIO
# -----------------------------
AUDIO_DIR = "/home/pathfinder/yolo-baseline/audio"

AUDIO_MAP = {
    "start": "road_mode.wav",
    "turn_left": "turn_left.wav",
    "turn_right": "turn_right.wav",
    "scanning": "scanning.wav",
    "safe": "safe.wav",
    "unsafe": "unsafe.wav",
}

def play_audio(key):
    file = AUDIO_MAP.get(key)
    if file:
        path = os.path.join(AUDIO_DIR, file)
        os.system(f"aplay '{path}' > /dev/null 2>&1")

# -----------------------------
# MODEL
# -----------------------------
model = YOLO("yolov8n.pt")

# -----------------------------
# CAMERA
# -----------------------------
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (FRAME_WIDTH, FRAME_HEIGHT), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()

time.sleep(2)

# -----------------------------
# EVALUATE ROAD SIDE
# -----------------------------
def evaluate_direction(total_duration=2.5, ignore_initial=0.5):
    start_time = time.time()

    danger_count = 0
    warning_count = 0
    approaching_count = 0

    previous_vehicle = None

    while time.time() - start_time < total_duration:
        frame = picam2.capture_array()
        frame = cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))

        elapsed = time.time() - start_time
        if elapsed < ignore_initial:
            continue

        results = model.predict(
            frame,
            imgsz=IMG_SIZE,
            conf=CONF_THRESHOLD,
            device="cpu",
            verbose=False
        )

        boxes = results[0].boxes
        if boxes is None:
            continue

        current_best = None

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

            if current_best is None or score > current_best["score"]:
                current_best = {
                    "area": area,
                    "bottom_y": bottom_y,
                    "center_x": center_x,
                    "score": score
                }

            if bottom_ratio > 0.85 or area_ratio > 0.30:
                danger_count += 1
            elif bottom_ratio > 0.65 or area_ratio > 0.12:
                warning_count += 1

        if current_best and previous_vehicle:
            area_growth = current_best["area"] - previous_vehicle["area"]
            bottom_growth = current_best["bottom_y"] - previous_vehicle["bottom_y"]
            center_shift = abs(current_best["center_x"] - previous_vehicle["center_x"])

            if center_shift < FRAME_WIDTH * 0.25:
                if area_growth > 800 or bottom_growth > 8:
                    approaching_count += 1

        if current_best:
            previous_vehicle = current_best

    if danger_count > 0:
        return "UNSAFE"
    if approaching_count >= 2:
        return "UNSAFE"
    if warning_count >= 3:
        return "UNSAFE"

    return "SAFE"

# -----------------------------
# MAIN FLOW
# -----------------------------
try:
    play_audio("start")
    time.sleep(1)

    play_audio("turn_left")
    time.sleep(1)

    play_audio("scanning")
    left_result = evaluate_direction()

    play_audio("safe" if left_result == "SAFE" else "unsafe")

    time.sleep(1)

    play_audio("turn_right")
    time.sleep(1)

    play_audio("scanning")
    right_result = evaluate_direction()

    play_audio("safe" if right_result == "SAFE" else "unsafe")

finally:
    picam2.stop()