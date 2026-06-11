import time
import cv2
from flask import Flask, Response
from camera_service import get_latest_frame, get_debug_frame

app = Flask(__name__)

stream_enabled = False


def set_stream_enabled(value):
    global stream_enabled
    stream_enabled = value
    print(f"[STREAM] stream_enabled = {stream_enabled}")


def generate_frames(require_enabled=False):
    while True:
        if require_enabled and not stream_enabled:
            time.sleep(0.1)
            continue

        if require_enabled:
            frame = get_latest_frame()
        else:
            frame = get_debug_frame()

            if frame is None:
                frame = get_latest_frame()

        if frame is None:
            time.sleep(0.05)
            continue

        ok, buffer = cv2.imencode(
            ".jpg",
            frame,
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

        time.sleep(0.05)


@app.route("/")
def index():
    return """
    <html>
      <body>
        <h2>PathFinder Stream Server</h2>
        <p>Debug stream: <a href="/video_debug">/video_debug</a></p>
        <p>Live stream: <a href="/video_live">/video_live</a></p>
      </body>
    </html>
    """


@app.route("/video_debug")
def video_debug():
    return Response(
        generate_frames(require_enabled=False),
        mimetype="multipart/x-mixed-replace; boundary=frame"
    )


@app.route("/video_live")
def video_live():
    return Response(
        generate_frames(require_enabled=True),
        mimetype="multipart/x-mixed-replace; boundary=frame"
    )


@app.route("/video")
def video():
    return video_live()


@app.route("/status")
def status():
    return {
        "status": "running",
        "liveStreamEnabled": stream_enabled
    }


def run_stream_server(host="0.0.0.0", port=5050):
    print(f"[STREAM] Server running at http://{host}:{port}")
    print(f"[STREAM] Debug stream: http://<PI_IP>:{port}/video_debug")
    print(f"[STREAM] Live stream : http://<PI_IP>:{port}/video_live")
    app.run(host=host, port=port, debug=False, threaded=True)


if __name__ == "__main__":
    run_stream_server()
