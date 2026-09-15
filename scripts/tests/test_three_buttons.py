import RPi.GPIO as GPIO
import time

SOS_BUTTON_PIN = 17
MODE_BUTTON_PIN = 27
STREAM_BUTTON_PIN = 22

GPIO.setmode(GPIO.BCM)

GPIO.setup(SOS_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
GPIO.setup(MODE_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
GPIO.setup(STREAM_BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

print("Testing buttons. Press Ctrl+C to stop.")

try:
    while True:
        print(
            "SOS:",
            GPIO.input(SOS_BUTTON_PIN),
            "MODE:",
            GPIO.input(MODE_BUTTON_PIN),
            "STREAM:",
            GPIO.input(STREAM_BUTTON_PIN),
        )
        time.sleep(0.5)

except KeyboardInterrupt:
    GPIO.cleanup()
