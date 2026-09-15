import math

FULL_VOLTAGE = 8.4
EMPTY_VOLTAGE = 6.0


def voltage_to_percent(voltage):
    """
    Convert battery voltage into a percentage between 0 and 100.

    The PathFinder battery operating range is approximately:
    - 6.0 V = 0%
    - 8.4 V = 100%
    """

    if isinstance(voltage, bool) or not isinstance(voltage, (int, float)):
        raise TypeError("Voltage must be a numeric value")

    if not math.isfinite(voltage):
        raise ValueError("Voltage must be a finite value")

    percent = (
        (voltage - EMPTY_VOLTAGE)
        / (FULL_VOLTAGE - EMPTY_VOLTAGE)
    ) * 100

    return round(max(0, min(100, percent)), 1)