# SignSuara

A smart glove and Flutter app that translate **Bahasa Isyarat Malaysia (BIM)** signs into speech
(Malay or English), and show what the hearing person says as text: two-way communication.

Final Year Project, Faculty of Computer Science and Information Technology (FCSIT),
Universiti Putra Malaysia (UPM).

## Features

- **Live sign recognition on the phone, offline**: a Random Forest exported to Dart; no server.
- **Speech output** in Malay or English (BM/EN switch, remembered after restart).
- **Speech-to-text** for the hearing person: tap to talk, the text is shown large.
- **Custom gestures**: record your own gesture on the phone and give it a Malay/English phrase.
- Motion-sensor drop-out detection, and the screen stays on while the glove is connected.

Built-in signs: **A, B, Saya** (I / me), **Nama** (name), **Terima kasih** (thank you).
`Rest` means "no sign" and is never spoken.

## How it works

```
Glove: ESP32 + 5 flex sensors + BNO055 motion sensor, 25 rows per second:
       thumb, index, middle, ring, pinky, yaw, pitch, roll, ax, ay, az
  ├── USB Serial (CSV) ──> Python recording / training pipeline (separate repository)
  └── BLE notifications ──> phone
        last 38 rows (1.5 s) → 40 features → custom-gesture matcher → Random Forest
        → live rules (confidence, stability, no repeats) → text on screen + speech
```

## Glove firmware

`firmware/signsuara_glove/signsuara_glove.ino`. Arduino IDE with ESP32 core 3.3.x, board
"ESP32 Dev Module", **Tools → Core Debug Level = None**. Flex sensors on pins 36, 34, 35, 32, 33
(ADC1, which keeps working while the radio is on); BNO055 on I2C pins 21/22, restarted
automatically when it freezes. The USB Serial CSV output is exactly the same as the recording
firmware, so the Python scripts keep working.

### BLE protocol

| | |
|---|---|
| Device name | `SignSuara-Glove` |
| Service UUID | `6b5384d0-483c-4d29-b3e7-4c404e3defce` |
| Characteristic (notify) | `2fce7dc7-6ea7-4d15-8e66-280c660ecb8b` |
| Payload | one row as text: `seq,thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az` |

- `seq` is the row number since power-on, so a jump means rows were lost.
- A row is up to ~85 bytes, more than the default 20-byte BLE packet. The glove accepts an MTU
  of up to 185 and the app requests a large MTU after connecting. Any notification that is not
  exactly 12 numbers is rejected.
- The name is in the advertising packet; the service UUID is in the scan response.

## Recognition

### Features (must match the Python pipeline exactly)

Eight channels: thumb, index, middle, ring, pinky, pitch, roll and `acc = √(ax² + ay² + az²)`.
Yaw is not used (it is a compass heading and changes with the direction the user faces).
For each channel: mean, min, max, population standard deviation, and delta (mean of the last 3
values − mean of the first 3). That gives 40 features (`lib/ml/features.dart`).

### Live prediction rules

Implemented in `lib/ml/gesture_classifier.dart`:

- Keep the last 38 rows; predict every 5 new rows (0.2 s) once the buffer is full.
- A prediction only counts with confidence ≥ 0.70.
- A label is accepted only when it wins **2 predictions in a row**, and announced only when the
  accepted label **changes**.
- `Rest` is accepted but never spoken, so the same word can be signed again after resting.
- If yaw, pitch, roll, ax, ay and az are all exactly 0, the BNO055 has dropped out: no
  predictions while such a row is in the window, and the app shows "Motion sensor disconnected".

## Speech

| Label | Malay | English |
|---|---|---|
| A | A | A |
| B | B | B |
| Saya | Saya | I / Me (spoken: "Me") |
| Nama | Nama | Name |
| TerimaKasih | Terima kasih | Thank you |
| Rest | (silent) | (silent) |

The mapping lives in one place, `kSignWords` in `lib/speech/sign_words.dart`; a label missing
from it is spoken as-is. The phone's text-to-speech engine is used; for Malay, "Speech Services by
Google" is recommended. Speech-to-text uses Google's recogniser and normally needs internet. The
phone stays silent while it is listening, so it never transcribes its own voice.

## Custom gestures

- The user records a gesture **5 times × 3 s** and chooses **Still** or **Moving**. Windows are
  taken exactly like in training: still = the last 1.5 s, moving = centred on the movement peak
  (shifted −6, −3, 0, +3, +6 rows).
- Matching is nearest-neighbour on the 40 features, each divided by its spread in the training
  data.
- A custom gesture wins only if the live window is (1) within 1.5 × the largest distance between
  its own recordings **and** (2) closer to its own recordings than to **any** built-in training
  example, including Rest (`lib/custom/reference_bank.dart`, generated from the training data).
- The app warns when a new gesture looks like a built-in sign.

Validation on the real recordings (`tools/eval_custom_matcher.py`): each built-in sign pretends
to be a new custom gesture, enrolled from 5 random recordings, 20 trials, with live replay of all
other recordings.

| Rule | Found | False announcements | …during Rest |
|---|---|---|---|
| Limit only | 95.7 % | 28.1 % | 27.5 % |
| **Limit + closer than any built-in example** | **95.1 %** | **0.2 %** | **0.0 %** |

## Measurements

- **Python ↔ Dart parity**: for one real window per sign, the Dart features match Python within
  1e-6 and the class probabilities within 1e-9 (`test/parity_test.dart`).
- **BLE does not disturb the flex readings**: glove lying still, phone connected with
  notifications on vs not connected: largest average shift 1.0 ADC count, same jitter
  (2–4 counts), 25 rows/s kept (`firmware/check_flex_noise.py`).
- Hardware note: the thumb flex sensor occasionally reads 4095 (5 of 170 recordings), which
  suggests a loose contact.

## Project structure

| Path | Contents |
|---|---|
| `lib/ml/` | `signsuara_model.dart` (generated model), `features.dart`, `gesture_classifier.dart` |
| `lib/glove/` | `glove_ble.dart` (Bluetooth), `glove_session.dart` (packets → classifier) |
| `lib/speech/` | speech map, text-to-speech, speech-to-text |
| `lib/custom/` | custom gestures: model, matcher, generated reference bank, screens |
| `lib/app/` | app shell (5 tabs + floating capsule nav) and the shared services (one glove connection) |
| `lib/screens/` | redesigned screens (Home, Conversation, Learn, …) |
| `lib/history/` | the conversation shown as chat bubbles (signed and heard messages) |
| `lib/theme/app_theme.dart` | all colours, gradients, fonts, spacing, radii and shadows |
| `lib/ui/` | shared widgets (hero panel, glove card, hand-sensor visual, motion) |
| `lib/home_page.dart` | the previous single screen, still used by tabs not yet redesigned |
| `lib/app_storage.dart` | saved data (custom gestures, BM/EN choice) |
| `firmware/` | ESP32 firmware and the BLE noise check |
| `tools/` | custom-gesture matcher validation (Python) |
| `test/` | 61 tests, including parity and replays of real recordings (`test/fixtures/`) |

## Build and run

Requirements: Flutter 3.29 (Dart 3.7), an Android phone with Android 7.0 or newer and
Bluetooth LE.

```
flutter pub get
flutter test
flutter run
```

The app asks for the "Nearby devices" (Bluetooth) and microphone permissions when first needed.

## Adding a new built-in sign

In the Python pipeline (separate repository): record → retrain → `python export.py`, which
regenerates `lib/ml/signsuara_model.dart`, `test/parity_cases.json` and
`lib/custom/reference_bank.dart`. Then add the sign's words to `kSignWords` and rebuild.
`flutter test` fails until the words are added. No other code changes are needed: the app
never hardcodes the labels, the number of classes or the window size.

## Limitations and future work

- **Single user**: the model is trained on one person's recordings. Supporting other users would
  need recordings from more people and/or a per-user calibration step.
- Speech-to-text normally needs internet; the Malay voice depends on the phone's TTS engine.
- Custom gestures are compared with the built-in signs, not with each other, so keep them
  clearly different.

## Packages and licences

| Package | Use | Licence |
|---|---|---|
| `flutter_blue_plus` | Bluetooth LE | FlutterBluePlus License: free for personal, educational and non-profit use; commercial use needs a paid licence |
| `flutter_tts` | text-to-speech | MIT |
| `speech_to_text` | speech recognition | BSD-3-Clause |
| `wakelock_plus` | keep the screen on | BSD-3-Clause |
| `shared_preferences` | saved data | BSD-3-Clause |
| Sora, Plus Jakarta Sans | fonts, bundled in `assets/fonts/` so the app works offline | SIL Open Font License 1.1 |
