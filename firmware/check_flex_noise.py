# Checks whether BLE changes the flex readings (one-off hardware test for the firmware).
# 1. Lay the glove flat on the table and don't touch it during the test.
# 2. Close Serial Monitor. Disconnect the phone in nRF Connect.
# 3. Run: python check_flex_noise.py   (opening COM12 restarts the ESP32, that's normal)
import serial, statistics, time

PORT, SECONDS = "COM12", 10
FINGERS = ["thumb", "index", "middle", "ring", "pinky"]


def measure(ser):
    ser.reset_input_buffer()
    rows, end = [], time.time() + SECONDS
    while time.time() < end:
        parts = ser.readline().decode(errors="ignore").strip().split(",")
        if len(parts) == 11 and not parts[0].startswith("#"):
            try:
                rows.append([float(p) for p in parts[:5]])
            except ValueError:
                pass
    return rows


ser = serial.Serial(PORT, 115200, timeout=1)
time.sleep(3)  # ESP32 restarts when the port opens

phases = {"A": "phone NOT connected", "B": "phone CONNECTED + notifications ON"}
data = {}
for key, text in phases.items():
    input(f"\n[{key}] {text}. Press Enter to measure {SECONDS} s...")
    data[key] = measure(ser)
    print(f"    got {len(data[key])} rows")
ser.close()

print(f"\n{'finger':8} {'avg A':>8} {'avg B':>8} {'diff':>6} {'jitter A':>9} {'jitter B':>9}")
worst = 0
for i, name in enumerate(FINGERS):
    a = [r[i] for r in data["A"]]
    b = [r[i] for r in data["B"]]
    diff = statistics.mean(b) - statistics.mean(a)
    worst = max(worst, abs(diff))
    print(f"{name:8} {statistics.mean(a):8.1f} {statistics.mean(b):8.1f} {diff:+6.1f} "
          f"{statistics.pstdev(a):9.1f} {statistics.pstdev(b):9.1f}")

# Bent vs straight is ~300 ADC counts, so a shift of a few counts doesn't matter to the model.
print("\nRESULT:", "OK - BLE does not disturb the flex readings" if worst <= 15
      else "SHIFT - BLE changes the readings, tell Claude")
