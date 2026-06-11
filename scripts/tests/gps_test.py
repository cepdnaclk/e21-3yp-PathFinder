import serial
import time

GPS_PORT = "/dev/serial0"
GPS_BAUDRATE = 9600


def convert_to_decimal(raw_value, direction):
    if not raw_value or not direction:
        return None

    value = float(raw_value)

    degrees = int(value / 100)
    minutes = value - (degrees * 100)

    decimal = degrees + (minutes / 60)

    if direction in ["S", "W"]:
        decimal *= -1

    return round(decimal, 6)


def read_gps():
    ser = serial.Serial(GPS_PORT, GPS_BAUDRATE, timeout=1)

    while True:
        line = ser.readline().decode("utf-8", errors="ignore").strip()

        if line.startswith("$GNRMC") or line.startswith("$GPRMC"):
            parts = line.split(",")

            if len(parts) > 6 and parts[2] == "A":
                lat = convert_to_decimal(parts[3], parts[4])
                lon = convert_to_decimal(parts[5], parts[6])

                return {
                    "valid": True,
                    "latitude": lat,
                    "longitude": lon,
                    "raw": line,
                    "timestamp": int(time.time())
                }

        time.sleep(0.1)


if __name__ == "__main__":
    while True:
        gps = read_gps()
        print(gps)
        time.sleep(2)
