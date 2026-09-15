import threading
import time

from camera_service import start_camera, stop_camera, get_latest_frame
from stream_server import run_stream_server


def frame_debug_loop():
    while True:
        frame = get_latest_frame()

        if frame is None:
            print("[TEST] Waiting for camera frame...")
        else:
            print(f"[TEST] Frame OK: {frame.shape}")

        time.sleep(2)


if __name__ == "__main__":
    try:
        camera_thread = threading.Thread(target=start_camera, daemon=True)
        camera_thread.start()

        debug_thread = threading.Thread(target=frame_debug_loop, daemon=True)
        debug_thread.start()

        run_stream_server(port=5050)

    except KeyboardInterrupt:
        print("[TEST] Stopped by user")

    finally:
        stop_camera()
