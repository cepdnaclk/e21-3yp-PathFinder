import math


def is_valid_gps_coordinate(latitude, longitude):
    """
    Return True when latitude and longitude are valid numeric GPS coordinates.

    Latitude must be between -90 and 90.
    Longitude must be between -180 and 180.
    """

    # Reject Boolean values because bool is treated as an integer in Python.
    if isinstance(latitude, bool) or isinstance(longitude, bool):
        return False

    if not isinstance(latitude, (int, float)):
        return False

    if not isinstance(longitude, (int, float)):
        return False

    # Reject NaN and infinite values.
    if not math.isfinite(latitude) or not math.isfinite(longitude):
        return False

    return -90 <= latitude <= 90 and -180 <= longitude <= 180