import time
import threading
from picamera2 import Picamera2

FRAME_WIDTH = 320
FRAME_HEIGHT = 240

latest_frame = None
latest_debug_frame = None
frame_lock = threading.Lock()

camera_running = False
picam2 = None


def start_camera():
    global latest_frame
    global camera_running
    global picam2

    if camera_running:
        print("[CAMERA] Already running")
        return

    print("[CAMERA] Starting shared camera")

    picam2 = Picamera2()
    config = picam2.create_preview_configuration(
        main={"size": (FRAME_WIDTH, FRAME_HEIGHT), "format": "RGB888"}
    )
    picam2.configure(config)
    picam2.start()

    time.sleep(2)

    camera_running = True
    print("[CAMERA] Shared camera started")

    while camera_running:
        frame = picam2.capture_array()

        with frame_lock:
            latest_frame = frame.copy()

        time.sleep(0.03)


def set_debug_frame(frame):
    global latest_debug_frame

    if frame is None:
        return

    with frame_lock:
        latest_debug_frame = frame.copy()


def get_debug_frame():
    with frame_lock:
        if latest_debug_frame is None:
            return None
        return latest_debug_frame.copy()


def get_latest_frame():
    with frame_lock:
        if latest_frame is None:
            return None
        return latest_frame.copy()


def stop_camera():
    global camera_running
    global picam2

    camera_running = False

    if picam2 is not None:
        try:
            picam2.stop()
            print("[CAMERA] Shared camera stopped")
        except Exception as e:
            print("[CAMERA ERROR]", str(e))
