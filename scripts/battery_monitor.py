import time
import firebase_admin
from firebase_admin import credentials, firestore
from battery_reader import read_battery

# ==============================
# CONFIG
# ==============================

SERVICE_KEY_PATH = "/home/pathfinder/pathfinder/firebase/ServiceAccountKey.json"

DEVICE_ID = "pathfinder_001"  # CHANGE THIS to your real device document ID

DEVICE_COLLECTION = "devices"

NORMAL_UPDATE_INTERVAL = 10  # 2 minutes

LOW_BATTERY_LIMIT = 20
CRITICAL_BATTERY_LIMIT = 10

# If current is above this, charger/external power is considered connected
CHARGING_CURRENT_THRESHOLD_MA = 50

# Prevent repeated low battery notification spam
LOW_ALERT_REPEAT_INTERVAL = 30 * 60  # 30 minutes


# ==============================
# FIREBASE INIT
# ==============================

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()
device_ref = db.collection(DEVICE_COLLECTION).document(DEVICE_ID)


# ==============================
# STATE MEMORY
# ==============================

last_charging_state = None
last_low_alert_time = 0


# ==============================
# HELPERS
# ==============================

def detect_charging(current_ma):
    """
    INA219 current behavior can vary by board.
    In many UPS HATs:
    positive current = charging/external power connected
    negative current = discharging from battery
    """
    return current_ma > CHARGING_CURRENT_THRESHOLD_MA


def get_power_state(is_charging):
    if is_charging:
        return "charging"
    return "unplugged"


def should_send_low_battery_alert(percentage):
    global last_low_alert_time

    now = time.time()

    if percentage > LOW_BATTERY_LIMIT:
        return False

    if now - last_low_alert_time >= LOW_ALERT_REPEAT_INTERVAL:
        last_low_alert_time = now
        return True

    return False


def create_low_battery_notification(percentage, power_state):
    notification_data = {
        "type": "LOW_BATTERY",
        "title": "Low Battery Alert",
        "message": f"PathFinder battery is low: {percentage}%",
        "batteryLevel": percentage,
        "powerState": power_state,
        "deviceId": DEVICE_ID,
        "isRead": False,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }

    db.collection("notifications").add(notification_data)
    print("Low battery notification created.")


def update_firebase(force_reason="normal"):
    battery = read_battery()

    percentage = battery["percentage"]
    voltage = battery["voltage"]
    current_ma = battery["current_ma"]
    power_mw = battery["power_mw"]

    is_charging = detect_charging(current_ma)
    power_state = get_power_state(is_charging)

    if percentage <= CRITICAL_BATTERY_LIMIT:
        battery_status = "critical"
    elif percentage <= LOW_BATTERY_LIMIT:
        battery_status = "low"
    elif percentage < 60:
        battery_status = "medium"
    else:
        battery_status = "good"

    firebase_data = {
        "batteryLevel": percentage,
        "batteryVoltage": voltage,
        "batteryCurrentMa": current_ma,
        "batteryPowerMw": power_mw,

        # App/web can show these
        "isCharging": is_charging,
        "powerState": power_state,
        "batteryStatus": battery_status,

        # Useful for refresh/time display
        "batteryLastUpdated": firestore.SERVER_TIMESTAMP,
        "batteryUpdateReason": force_reason,

        # Alert flags
        "lowBattery": percentage <= LOW_BATTERY_LIMIT,
        "criticalBattery": percentage <= CRITICAL_BATTERY_LIMIT,
    }

    # merge=True avoids deleting other fields in the device document
    device_ref.set(firebase_data, merge=True)

    print(
        f"Firebase updated | "
        f"Battery: {percentage}% | "
        f"Voltage: {voltage}V | "
        f"Current: {current_ma}mA | "
        f"State: {power_state} | "
        f"Reason: {force_reason}"
    )

    if should_send_low_battery_alert(percentage):
        create_low_battery_notification(percentage, power_state)

    return is_charging


# ==============================
# MAIN LOOP
# ==============================

def main():
    global last_charging_state

    print("UPS Firebase service started.")
    print(f"Using device ID: {DEVICE_ID}")
    print("Normal update rate: once per 2 minutes.")
    print("Charging/unplugging changes are pushed immediately.")

    # First update immediately
    try:
        last_charging_state = update_firebase(force_reason="startup")
    except Exception as e:
        print("Startup update error:", e)

    while True:
        try:
            battery = read_battery()
            current_ma = battery["current_ma"]
            current_charging_state = detect_charging(current_ma)

            # Immediate Firebase update if charger state changed
            if last_charging_state is not None and current_charging_state != last_charging_state:
                reason = "charger_connected" if current_charging_state else "charger_unplugged"
                last_charging_state = update_firebase(force_reason=reason)

            else:
                # Normal scheduled update once per 2 minutes
                last_charging_state = update_firebase(force_reason="normal")

        except Exception as e:
            print("UPS Firebase service error:", e)

        time.sleep(NORMAL_UPDATE_INTERVAL)


if __name__ == "__main__":
    main()
