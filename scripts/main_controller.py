import time
import threading
import traceback
import RPi.GPIO as GPIO
import serial
import subprocess

from send_sos import send_sos_alert
from update_location import update_device_location
from battery_monitor import main as battery_monitor_main
from camera_service import start_camera, stop_camera
from stream_server import run_stream_server, set_stream_enabled
from modes.road.road_mode import run_road_mode
from modes.pedestrian.pedestrian_audio_pi_stream import run_pedestrian_mode
from stream_firebase import enable_stream, disable_stream
from webrtc_streamer import start_webrtc_service

# =========================
# GPIO CONFIG
# =========================
SOS_BUTTON_PIN = 17   # BCM 17 = Physical Pin 11
MODE_BUTTON_PIN = 27  # BCM 27 = Physical Pin 13
STREAM_BUTTON_PIN = 22  # BCM 22 = Physical Pin 15

# =========================
# GPS CONFIG
# =========================
GPS_PORT = "/dev/serial0"
GPS_BAUDRATE = 9600
GPS_PRINT_INTERVAL = 20.0
GPS_FIREBASE_UPDATE_INTERVAL = 20.0

# =========================
# BUTTON TIMING CONFIG
# =========================
DEBOUNCE_TIME = 0.3
HOLD_OFF_TIME = 2.0

# =========================
# SHARED STATE
# =========================
# Mode State
last_sos_time = 0
current_mode = "PEDESTRIAN"
last_mode_button_time = 0

# Stream state
stream_enabled = False
last_stream_button_time = 0

PEDESTRIAN_DIR = "/home/pathfinder/pathfinder/scripts/modes/pedestrian"
PEDESTRIAN_SCRIPT = "pedestrian_audio_pi_stream.py"

ROAD_DIR = "/home/pathfinder/pathfinder/scripts/modes/road"
ROAD_SCRIPT = "road_mode.py"

mode_process = None
mode_thread = None
mode_stop_event = None

latest_gps_data = {
    "lat": None,
    "lng": None,
    "fix": False,
    "last_raw": None,
    "last_print_time": 0,
    "last_firebase_update_time": 0
}


def setup_gpio():
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(SOS_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.setup(MODE_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.setup(STREAM_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    print("[INFO] GPIO setup complete")
    print(f"[INFO] SOS button pin: BCM {SOS_BUTTON_PIN} (Physical Pin 11)")
    print(f"[INFO] Mode button pin: BCM {MODE_BUTTON_PIN} (Physical Pin 13)")
    print(f"[INFO] Stream button pin: BCM {STREAM_BUTTON_PIN} (Physical Pin 15)")


def convert_to_decimal(raw_value, direction):
    if not raw_value or not direction:
        return None

    try:
        value = float(raw_value)
        degrees = int(value // 100)
        minutes = value - (degrees * 100)
        decimal = degrees + (minutes / 60)

        if direction in ["S", "W"]:
            decimal = -decimal

        return round(decimal, 6)
    except Exception:
        return None


def parse_gpgga(line):
    parts = line.split(",")

    if len(parts) < 7:
        return None, None, False

    lat_raw = parts[2]
    lat_dir = parts[3]
    lng_raw = parts[4]
    lng_dir = parts[5]
    fix_quality = parts[6]

    if fix_quality == "0":
        return None, None, False

    lat = convert_to_decimal(lat_raw, lat_dir)
    lng = convert_to_decimal(lng_raw, lng_dir)

    if lat is None or lng is None:
        return None, None, False

    return lat, lng, True


def parse_gprmc(line):
    parts = line.split(",")

    if len(parts) < 7:
        return None, None, False

    status = parts[2]
    lat_raw = parts[3]
    lat_dir = parts[4]
    lng_raw = parts[5]
    lng_dir = parts[6]

    if status != "A":
        return None, None, False

    lat = convert_to_decimal(lat_raw, lat_dir)
    lng = convert_to_decimal(lng_raw, lng_dir)

    if lat is None or lng is None:
        return None, None, False

    return lat, lng, True


def gps_reader_thread():
    try:
        ser = serial.Serial(GPS_PORT, GPS_BAUDRATE, timeout=1)
        print(f"[GPS] Connected to {GPS_PORT} at {GPS_BAUDRATE} baud")

        while True:
            try:
                line = ser.readline().decode("utf-8", errors="ignore").strip()

                if not line:
                    continue

                latest_gps_data["last_raw"] = line

                lat, lng, fix = None, None, False

                if line.startswith("$GPGGA") or line.startswith("$GNGGA"):
                    lat, lng, fix = parse_gpgga(line)

                elif line.startswith("$GPRMC") or line.startswith("$GNRMC"):
                    lat, lng, fix = parse_gprmc(line)

                current_time = time.time()

                if fix:
                    latest_gps_data["lat"] = lat
                    latest_gps_data["lng"] = lng
                    latest_gps_data["fix"] = True

                    if current_time - latest_gps_data["last_firebase_update_time"] >= GPS_FIREBASE_UPDATE_INTERVAL:
                        try:
                            update_device_location(lat, lng)
                            latest_gps_data["last_firebase_update_time"] = current_time
                        except Exception as e:
                            print("[FIREBASE ERROR] Failed to update GPS location")
                            print(str(e))

                if current_time - latest_gps_data["last_print_time"] >= GPS_PRINT_INTERVAL:
                    if latest_gps_data["fix"]:
                        print(f"[GPS] lat={latest_gps_data['lat']}, lng={latest_gps_data['lng']}")
                    else:
                        print("[GPS] Waiting for valid GPS fix...")

                    latest_gps_data["last_print_time"] = current_time

            except Exception as e:
                print("[GPS WARNING] Error reading GPS data")
                print(str(e))

    except Exception as e:
        print("[GPS ERROR] Could not open GPS serial port")
        print(str(e))
        traceback.print_exc()


def handle_sos_button():
    global last_sos_time

    current_time = time.time()

    if current_time - last_sos_time < HOLD_OFF_TIME:
        return

    print("[INFO] SOS button press detected")

    try:
        lat = latest_gps_data["lat"]
        lng = latest_gps_data["lng"]

        send_sos_alert(lat=lat, lng=lng)

        last_sos_time = current_time
        print("[INFO] SOS workflow completed")

    except Exception as e:
        print("[ERROR] Failed to send SOS")
        print(str(e))
        traceback.print_exc()

def start_pedestrian_mode():
    global mode_thread
    global mode_stop_event

    if mode_thread is not None and mode_thread.is_alive():
        print("[MODE] Pedestrian mode already running")
        return

    print("[MODE] Starting PEDESTRIAN mode thread")
    print("[PEDESTRIAN] Local monitoring URL : http://172.20.10.6:5050/video_debug")
    print("[STREAM] Caretaker stream URL: http://172.20.10.6:5050/video_live")

    mode_stop_event = threading.Event()

    mode_thread = threading.Thread(
        target=run_pedestrian_mode,
        args=(mode_stop_event,),
        daemon=True
    )

    mode_thread.start()


def start_road_mode():
    global mode_thread
    global mode_stop_event

    if mode_thread is not None and mode_thread.is_alive():
        print("[MODE] Road mode already running")
        return

    print("[MODE] Starting ROAD mode thread")
    print("[ROAD] Local monitoring URL : http://172.20.10.6:5050/video_debug")
    print("[STREAM] Caretaker stream URL: http://172.20.10.6:5050/video_live")

    mode_stop_event = threading.Event()

    mode_thread = threading.Thread(
        target=run_road_mode,
        args=(mode_stop_event,),
        daemon=True
    )

    mode_thread.start()

def stop_current_mode_process():
    global mode_thread
    global mode_stop_event

    if mode_thread is not None and mode_thread.is_alive():
        print("[MODE] Stopping current mode thread")

        if mode_stop_event is not None:
            mode_stop_event.set()

        mode_thread.join(timeout=3)

        if mode_thread.is_alive():
            print("[MODE] Warning: mode thread did not stop immediately")

    mode_thread = None
    mode_stop_event = None


def handle_mode_button():
    global current_mode
    global last_mode_button_time

    current_time = time.time()

    if current_time - last_mode_button_time < HOLD_OFF_TIME:
        return

    print("[MODE] Mode button press detected")

    if current_mode == "PEDESTRIAN":
        stop_current_mode_process()
        current_mode = "ROAD"
        print("[MODE] Switched to ROAD mode")
        start_road_mode()

    else:
        stop_current_mode_process()
        current_mode = "PEDESTRIAN"
        print("[MODE] Switched to PEDESTRIAN mode")
        start_pedestrian_mode()

    last_mode_button_time = current_time

def handle_stream_button():
    global stream_enabled
    global last_stream_button_time

    current_time = time.time()

    if current_time - last_stream_button_time < HOLD_OFF_TIME:
        return

    print("[STREAM] Stream button press detected")

    stream_enabled = not stream_enabled
    set_stream_enabled(stream_enabled)

    if stream_enabled:
        enable_stream()
        print("[STREAM] Live stream ENABLED")
        print("[STREAM] WebRTC room: streamRooms/test_room")
        print("[STREAM] Debug URL: http://172.20.10.6:5050/video_debug")
    else:
        disable_stream()
        print("[STREAM] Live stream DISABLED")

    last_stream_button_time = current_time

def main():
    try:
        setup_gpio()

        camera_thread = threading.Thread(target=start_camera, daemon=True)
        camera_thread.start()

        # STREAM SERVER THREAD
        stream_thread = threading.Thread(
            target=run_stream_server,
            kwargs={"port": 5050},
            daemon=True
        )

        stream_thread.start()

        webrtc_thread = threading.Thread(
            target=start_webrtc_service,
            daemon=True
        )
        webrtc_thread.start()

        gps_thread = threading.Thread(target=gps_reader_thread, daemon=True)
        gps_thread.start()

        battery_thread = threading.Thread(target=battery_monitor_main, daemon=True)
        battery_thread.start()

        print("[INFO] Main controller started")
        print("[INFO] GPS thread started")
        print("[INFO] Battery monitor thread started")
        print("[INFO] Waiting for SOS button press...")
        print(f"[MODE] Starting in {current_mode} mode")
        print("[INFO] Shared camera thread started")
        print("[INFO] Stream server thread started")
        print("[INFO] WebRTC service thread started")
        start_pedestrian_mode()

        while True:
            if GPIO.input(SOS_BUTTON_PIN) == GPIO.LOW:
                time.sleep(DEBOUNCE_TIME)

                if GPIO.input(SOS_BUTTON_PIN) == GPIO.LOW:
                    handle_sos_button()

                    while GPIO.input(SOS_BUTTON_PIN) == GPIO.LOW:
                        time.sleep(0.05)

                    print("[INFO] SOS button released")

            if GPIO.input(MODE_BUTTON_PIN) == GPIO.LOW:
                time.sleep(DEBOUNCE_TIME)

                if GPIO.input(MODE_BUTTON_PIN) == GPIO.LOW:
                    handle_mode_button()

                    while GPIO.input(MODE_BUTTON_PIN) == GPIO.LOW:
                        time.sleep(0.05)

                    print("[MODE] Mode button released")
            # STREAM BUTTON
            if GPIO.input(STREAM_BUTTON_PIN) == GPIO.LOW:
                time.sleep(DEBOUNCE_TIME)

                if GPIO.input(STREAM_BUTTON_PIN) == GPIO.LOW:
                    handle_stream_button()

                    while GPIO.input(STREAM_BUTTON_PIN) == GPIO.LOW:
                        time.sleep(0.05)

                    print("[STREAM] Stream button released")

            time.sleep(0.05)

    except KeyboardInterrupt:
        print("\n[INFO] Main controller stopped by user")

    except Exception as e:
        print("[ERROR] Main controller crashed")
        print(str(e))
        traceback.print_exc()

    finally:
        stop_current_mode_process()
        GPIO.cleanup()
        print("[INFO] GPIO cleaned up")


if __name__ == "__main__":
    main()
