import pytest

from gps_validator import is_valid_gps_coordinate


@pytest.mark.parametrize(
    "latitude, longitude, expected",
    [
        # Valid equivalence class
        (7.2906, 80.6337, True),
        (0, 0, True),
        (-45.5, 120.5, True),

        # Latitude lower boundary
        (-90.1, 80, False),
        (-90, 80, True),
        (-89.9, 80, True),

        # Latitude upper boundary
        (89.9, 80, True),
        (90, 80, True),
        (90.1, 80, False),

        # Longitude lower boundary
        (7, -180.1, False),
        (7, -180, True),
        (7, -179.9, True),

        # Longitude upper boundary
        (7, 179.9, True),
        (7, 180, True),
        (7, 180.1, False),

        # Invalid latitude types and values
        (None, 80, False),
        ("7.2906", 80, False),
        ("", 80, False),
        ([7.2906], 80, False),

        # Invalid longitude types and values
        (7.2906, None, False),
        (7.2906, "80.6337", False),
        (7.2906, "", False),
        (7.2906, [80.6337], False),

        # Both inputs invalid
        (None, None, False),
        ("", "", False),
    ],
)
def test_is_valid_gps_coordinate(latitude, longitude, expected):
    result = is_valid_gps_coordinate(latitude, longitude)

    assert result is expected