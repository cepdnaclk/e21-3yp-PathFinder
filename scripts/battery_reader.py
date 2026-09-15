import time
import board
import busio
from adafruit_ina219 import INA219

INA219_ADDRESS = 0x42

FULL_VOLTAGE = 8.4
EMPTY_VOLTAGE = 6.0

i2c = busio.I2C(board.SCL, board.SDA)
ina219 = INA219(i2c, addr=INA219_ADDRESS)


def voltage_to_percent(voltage):
    percent = ((voltage - EMPTY_VOLTAGE) / (FULL_VOLTAGE - EMPTY_VOLTAGE)) * 100
    return round(max(0, min(100, percent)), 1)


def get_status(percent):
    if percent >= 60:
        return "good"
    elif percent >= 25:
        return "medium"
    elif percent >= 15:
        return "low"
    return "critical"


def read_battery():
    voltage = ina219.bus_voltage
    current_ma = ina219.current
    power_mw = ina219.power
    percent = voltage_to_percent(voltage)

    return {
        "percentage": percent,
        "voltage": round(voltage, 2),
        "current_ma": round(current_ma, 2),
        "power_mw": round(power_mw, 2),
        "status": get_status(percent),
        "timestamp": int(time.time())
    }


if __name__ == "__main__":
    while True:
        print(read_battery())
        time.sleep(2)
