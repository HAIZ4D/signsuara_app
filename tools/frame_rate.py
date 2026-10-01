"""Frame rate of SignSuara on a connected Android phone (README "Smoothness").

Reads the times at which Android showed the app's frames (SurfaceFlinger), so the app needs no
changes. Open the screen to measure, keep the phone still, then run:

    python tools/frame_rate.py "Home" 3

It prints the frames per second, the screen's refresh rate, and how many frames came late (more
than 1.5 refreshes after the one before). Measure a release build: debug builds are much slower.
"""
import os
import subprocess
import sys
import time

ADB = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Android', 'Sdk', 'platform-tools', 'adb.exe')
if not os.path.exists(ADB):
    ADB = 'adb'  # on the PATH


def sh(cmd):
    return subprocess.run([ADB, 'shell', cmd], capture_output=True, text=True).stdout


def main():
    layers = [l.strip() for l in sh('dumpsys SurfaceFlinger --list').splitlines()
              if l.strip().startswith('SurfaceView[com.haizad.signsuara')]
    if not layers:
        sys.exit('SignSuara is not on the screen')
    layer = layers[-1]
    label = sys.argv[1] if len(sys.argv) > 1 else 'screen'
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 3
    sh(f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
    time.sleep(seconds)
    out = sh(f"dumpsys SurfaceFlinger --latency '{layer}'").split()
    refresh = int(out[0]) / 1e6  # ms between screen refreshes
    shown = sorted(int(out[i + 1]) for i in range(1, len(out) - 2, 3) if 0 < int(out[i + 1]) < 2**62)
    gaps = [(b - a) / 1e6 for a, b in zip(shown, shown[1:])]
    if len(gaps) < 5:
        sys.exit(f'{label}: only {len(shown)} frames: nothing was moving')
    span = (shown[-1] - shown[0]) / 1e9
    late = [g for g in gaps if g > refresh * 1.5]
    print(f'{label}: {(len(shown) - 1) / span:.1f} fps (screen {1000 / refresh:.0f} Hz), '
          f'late frames {100 * len(late) / len(gaps):.0f}%, worst {max(gaps):.1f} ms')


if __name__ == '__main__':
    main()
