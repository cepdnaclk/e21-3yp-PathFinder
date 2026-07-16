import pytest

from battery_percentage import voltage_to_percent


@pytest.mark.parametrize(
    "voltage, expected",
    [
        # Below lower boundary
        (5.5, 0.0),
        (5.9, 0.0),

        # Lower boundary
        (6.0, 0.0),
        (6.1, 4.2),

        # Valid range
        (6.6, 25.0),
        (7.2, 50.0),
        (7.8, 75.0),

        # Upper boundary
        (8.3, 95.8),
        (8.4, 100.0),
        (8.5, 100.0),

        # Above upper boundary
        (9.0, 100.0),
    ],
)
def test_voltage_to_percent_valid_values(voltage, expected):
    assert voltage_to_percent(voltage) == expected


@pytest.mark.parametrize(
    "invalid_input",
    [
        None,
        "7.2",
        "",
        [7.2],
        True,
    ],
)
def test_voltage_to_percent_invalid_types(invalid_input):
    with pytest.raises(TypeError):
        voltage_to_percent(invalid_input)


@pytest.mark.parametrize(
    "invalid_voltage",
    [
        float("nan"),
        float("inf"),
        float("-inf"),
    ],
)
def test_voltage_to_percent_non_finite_values(invalid_voltage):
    with pytest.raises(ValueError):
        voltage_to_percent(invalid_voltage)