# SignSuara

A smart glove and Flutter app that translate **Bahasa Isyarat Malaysia (BIM)** signs into speech
(Malay or English), and show what the hearing person says as text: two-way communication.

Final Year Project, Faculty of Computer Science and Information Technology (FCSIT),
Universiti Putra Malaysia (UPM).

## Features

- **Live sign recognition on the phone, offline**: a Random Forest exported to Dart; no server.
- **Speech output** in Malay or English (BM/EN switch, remembered after restart).
- **Speech-to-text** for the hearing person: in **Chat** tap to talk (daily two-way talk); in
  **Listen** the phone listens on and on (a meeting, a class, a program, a consultation) and every
  sentence is kept as a **note** (see "Listen and Notes").
- **Custom gestures**: record your own gesture on the phone and give it a Malay/English phrase.
- **Optional Google sign-in** (Firebase): the app greets you by name, keeps your
  **conversation history** (read back or delete past conversations) and **backs up your custom
  gestures** (they come back after a reinstall or on a new phone). Guests can use everything on
  the phone; their conversations are kept until the app closes.
- **Profile & settings**: your name and photo (change them when signed in), glove connection, speech
  language, voice test, conversation history (count, clear all), gesture backup (check now),
  Google account, about and licences. Home greets you by time of day ("Good morning", …).
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
phone stays silent while it is listening, so it never transcribes its own voice. Recogniser errors
are shown in plain words, except "error_client": many phones report it whenever a listen closes,
even when the words came through fine, so it is not shown.

## Listen and Notes

**Listen** is for listening for a long time, like a meeting, a class, a program or a doctor's
consultation. **Chat** is for daily two-way talk. They are separate: a Listen session is not part
of the chat or its history.

- **A session** (`lib/listen/listen_session.dart`): Start, then Pause / Continue, then Stop. The
  words show live; each finished sentence is kept as a line and signed by the avatar. Android's
  speech recogniser stops after every pause, so the session starts it again after each sentence
  (one listen lasts at most 60 s and waits 5 s through a pause). Silence just starts it again; a
  real problem (no internet, no microphone permission) pauses the session with the reason and a
  Continue button. The phone stays silent and the screen stays on for the whole session. While it
  runs, Chat's microphone is busy.
- **Kept as a note** (`lib/listen/listen_note.dart`): after Stop you choose what it was (Meeting,
  Class, Consultation, Program or Other) and a title, or throw it away. The note is also saved
  every 3 sentences while the session runs, so a closed app loses little. Signed in: in the
  account (`users/{uid}/notes`, see "Firebase setup"); guest: kept until the app closes.
- **Coming next:** a Notes tab to read the notes again, and summaries made by Gemini when you ask
  for one.
- **Limitations:** the restart after each sentence takes a moment, so a word said exactly then can
  be missed; some phones play a short sound each time listening starts; speech recognition needs
  internet, and a long session uses more battery.

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

## Signer (in progress)

The hearing person's words will be shown by a BIM signer avatar, next to the text.

- **Words → signs** (`lib/signer/sign_translator.dart`): known phrases first (the longest wins,
  "terima kasih" is one sign), then single words (also without a spoken -lah, -kah, -nya or
  -pun ending), and everything else is fingerspelled; digits use number signs. Malay and English
  speech use the same signs. Without sign clips, the Listen stage shows the result as sign chips
  (outlined "abc" chips are fingerspelled).
- **The dictionary** (`kBimSigns` in `lib/signer/bim_signs.dart`) lists meanings only: a sign
  id and the words signed with it. Adding a sign = one line there, then its clip
  `assets/signs/<id>.webp`. Every sign must be checked by a fluent BIM signer before its clip is
  added.
- **The player** (`lib/signer/sign_player.dart`, `sign_player_view.dart`) plays the clips one
  after another: animated WebP with a transparent background, decoded with Flutter's own image
  decoder (no extra package). Every clip starts and ends in the avatar's rest pose, so the joins
  don't jump. A sign without a clip is skipped and reported; a one-frame clip (a held handshape)
  stays 0.4 s; half speed is possible; a slow phone waits for the next frame instead of skipping.
  `tools/make_placeholder_clips.py` makes the tiny placeholder clips the tests use
  (`test/fixtures/signs/`: moving dots, not signs).
- **On the screens** (`lib/signer/signer.dart`): the hearing person's latest finished words are
  signed automatically; in Listen each sentence as soon as it is heard, while the next one is
  listened for. With clips in the app, the Listen stage shows the avatar with the words below it,
  the word being signed highlighted, plus "sign it again" and "slower"; in Chat the dock shows the avatar
  while it signs, and a tap on their bubble signs it again. Until the app contains clips, both
  screens stay as text ("BIM signer · coming soon").
- **Clips** go in `assets/signs/<id>.webp` (see `assets/signs/README.md`); the app finds them by
  itself (`lib/signer/sign_clips.dart`). A sign whose clip is not made yet is fingerspelled if the
  alphabet clips exist; a word that can be neither signed nor fully spelled is left out. An
  optional `rest.webp` shows the avatar standing ready.
- **Limitation:** the signing follows the spoken word order (signed Malay or English, word by
  word). Full BIM grammar, facial grammar and use of space are not modelled.
- **The avatar** is the VRoid character "FREE MODEL 青髪三つ編みメガネっ子" by 水銀メイド (VRoid Hub),
  animated in Blender and rendered to clips. Its licence requires credit (in the app: Profile →
  About → View licenses) and does not allow sharing the model file, so the model and the Blender
  file are not in this repository (`character/` and `*.vrm` are git-ignored); the app contains
  only rendered clips.
- **Making clips:** in Blender, each sign is an action named `sign:<id>` on the character's
  armature (with a manual frame range, starting and ending in the rest pose; `sign:rest` is the
  avatar standing ready, hands together in front of the waist). The scene has a front camera on
  the signing space, soft lights and a transparent background at 800 px, 24 fps.
  Fingerspelling: `sign:spell_in` raises the right hand to the shoulder, letters
  (`sign:letter_a`, …) start and end there with a relaxed hand, and `sign:spell_out` brings it back
  down; the app wraps each run of spelled words in spell_in … spell_out, so the hand does not drop
  between letters. The posing helpers (`tools/blender/sign_pose.py`) place a hand by its wrist
  position and direction (the arm is worked out), can move a fingertip onto a touch point (SAYA:
  the index on the chest), find the thumb for a handshape by a quick search, and key every frame
  in between (shortest turns, eased); moves between two signing poses are placed frame by frame so
  the elbow does not swing out. An action `face:<id>` on the face's shape keys gives a sign a
  facial expression (TERIMA KASIH: a small smile); other signs keep a neutral face. The
  character's very wide jacket cuffs hid the hand whenever the wrist bent (SAYA pointing at the
  chest), so the sleeves are slimmed to end at the wrist with a shape key (`slim_sleeves()`; the
  model's own mesh is unchanged, and its licence allows changes). The hair and eyebrows are
  recoloured from blue to brown the same way: `hair_colour()` swaps in brown copies of their
  textures (shading kept) and keeps the originals.
  1. `tools/blender/render_signs.py` (run inside Blender) renders every `sign:` action to
     `character/renders/<id>/0001.png …`;
  2. `python tools/make_sign_clips.py [id …]` turns those frames into `assets/signs/<id>.webp`
     (560 px). The app picks the new clips up by itself.
- **Recorded so far:** `rest`, `spell_in`, `spell_out`, `letter_a`, `letter_b`, `terima_kasih`,
  `saya`, `nama`, `ya`, `tidak` (posed from BIM Sign Bank pictures, right hand; NAMA with
  both hands).
  SAYA and NAMA were then refined from a description of the signs: SAYA = index-finger fist at the
  middle of the chest, one small light touch; NAMA = two H hands (index and middle finger straight
  and together, ring and little finger curled, thumb folded across them) in front of the lower
  chest, palms facing the body and a little down; the left hand stays still, the right hand starts
  9 cm above, taps twice across the middle of the left fingers (a small X; right fingers tilted
  ~27°), lifting 3.5 cm between the taps, then moves away before both hands go back to rest.
  `hands_clash()` (in `sign_pose.py`) counts skin triangles of one hand that pass through the
  other: 0 on every NAMA frame. Clips are 560 px; the camera frames the upper
  body from just above the head to just below the resting hands.
- **Partly recorded:** words whose sign has no clip yet are shown grey under the avatar, with a
  note; the avatar signs the rest.

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
| `lib/custom/` | custom gestures: model, matcher, generated reference bank, screens, account backup (`gesture_backup.dart`) |
| `lib/app/` | app shell (5 tabs + floating capsule nav) and the shared services (one glove connection) |
| `lib/listen/` | Listen sessions and their notes (the note, its store) |
| `lib/screens/` | screens: splash, welcome pages, sign-in, Home, Chat (conversation), Listen (hearing), Learn, history, Profile & settings |
| `lib/cloud/` | the only folder using Firebase: `account.dart` (Google account or guest), `firebase_auth_backend.dart` (sign-in, profile), `firestore_history_store.dart` (saved conversations), `firestore_gesture_store.dart` (gesture backup) |
| `lib/signer/` | words → BIM signs: the sign dictionary, the translator and the clip player |
| `lib/history/` | the conversation shown as chat bubbles (`conversation_log.dart`) and its history (`conversation_history.dart`: when a conversation starts and ends, where it is saved) |
| `lib/theme/app_theme.dart` | all colours, gradients, fonts, spacing, radii and shadows |
| `lib/ui/` | shared widgets (hero panel, glove card, hand-sensor visual, motion) |
| `lib/app_storage.dart` | saved data (custom gestures, BM/EN choice) |
| `firmware/` | ESP32 firmware and the BLE noise check |
| `tools/` | custom-gesture matcher validation (Python); `make_app_icon.dart` draws the launcher icon from the in-app logo (`flutter test tools/make_app_icon.dart`); `make_placeholder_clips.py` makes the test sign clips; `make_sign_clips.py` and `blender/render_signs.py` make the real ones |
| `test/` | 153 tests, including parity and replays of real recordings (`test/fixtures/`) |

## Build and run

Requirements: Flutter 3.29 (Dart 3.7), an Android phone with Android 7.0 or newer and
Bluetooth LE.

```
flutter pub get
flutter test
flutter run
```

The app asks for the "Nearby devices" (Bluetooth) and microphone permissions when first needed.
The Android build needs `android/app/google-services.json`, which is not in this repository:
see [Firebase setup](#firebase-setup).

## Firebase setup

Google sign-in uses Firebase Authentication; the profile is saved in Cloud Firestore. The config
file `android/app/google-services.json` is git-ignored, so each copy of the project uses its own
Firebase project:

1. Firebase console → Project settings → add an **Android app** with package
   `com.haizad.signsuara`.
2. Add the **SHA-1** (and SHA-256) of the key that signs the app. For debug builds (release builds
   are signed with the same debug key for now):
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
3. Authentication → Sign-in method → enable **Google**.
4. Download `google-services.json` **after** steps 2 and 3 (only then does it contain the
   `oauth_client` entries that Google sign-in needs) and put it in `android/app/`.
5. Firestore → Rules: each user may only read and write their own data:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```

6. **Storage** (profile photos): Firebase console → Storage → get started. Cloud Storage needs
   the Blaze (pay-as-you-go) plan; a profile photo is small (at most 800 px, well inside the free
   quota). Rules: each user may only use their own folder, images under 5 MB:
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /users/{uid}/{allPaths=**} {
         allow read, delete: if request.auth != null && request.auth.uid == uid;
         allow create, update: if request.auth != null && request.auth.uid == uid
           && request.resource.size < 5 * 1024 * 1024
           && request.resource.contentType.matches('image/.*');
       }
     }
   }
   ```

Saved per user:
- `users/{uid}`: name, email, photo link, first and last sign-in time, `username` when the name
  was changed in Profile and `customPhotoUrl` when the photo was (the app puts them back if a later
  Google sign-in resets them).
- Storage `users/{uid}/photos/<time>.jpg`: the chosen profile photo (a new file each change; the
  previous one is deleted).
- `users/{uid}/conversations/{id}`: `startedAt`, `updatedAt` and `messages`, a list of
  `{who: "me", label, malay, english, at}` (a sign, with its words at that moment) or
  `{who: "them", text, at}` (heard words). A conversation starts with the first message after
  the app opens, after the chat is cleared, or after 5 minutes without messages.
  Firestore keeps a copy on the phone, so saving works offline and is sent later.
- `users/{uid}/notes/{id}`: a Listen session: `kind` (meeting, lesson, consultation, program,
  other), `title`, `language` (malay or english), `startedAt`, `endedAt` and `lines`, a list of
  `{text, at}` (one per sentence heard).
- `users/{uid}/gestures/{id}`: `malay`, `english`, `moving`, `savedAt` and `recordings` (the raw
  recordings as one JSON text, because Firestore can't store lists inside lists).
  The list on the phone is the one the app uses; the account keeps a copy
  (`lib/custom/gesture_backup.dart`): at sign-in, gestures only in the account are added to the
  phone and gestures only on the phone are uploaded; while signed in, every new gesture is
  uploaded and every deleted one removed. While signed out nothing is copied, so a gesture
  deleted then comes back at the next sign-in.

Without an account (guest) nothing is sent to Firebase: conversations are kept only until the app
closes.

## Adding a new built-in sign

In the Python pipeline (separate repository): record → retrain → `python export.py`, which
regenerates `lib/ml/signsuara_model.dart`, `test/parity_cases.json` and
`lib/custom/reference_bank.dart`. Then add the sign's words to `kSignWords` and rebuild.
`flutter test` fails until the words are added. No other code changes are needed: the app
never hardcodes the labels, the number of classes or the window size.

## Limitations and future work

- **Single user**: the model is trained on one person's recordings. Supporting other users would
  need recordings from more people and/or a per-user calibration step.
- Google sign-in needs internet (the rest of the app works without an account).
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
| `firebase_core`, `firebase_auth`, `cloud_firestore` | Firebase: sign-in, cloud data | BSD-3-Clause |
| `google_sign_in` | Google account picker | BSD-3-Clause |
| `firebase_storage` | profile photos | BSD-3-Clause |
| `image_picker` | take or choose a profile photo | Apache-2.0 / BSD-3-Clause |
| BIM signer character | "FREE MODEL 青髪三つ編みメガネっ子" by 水銀メイド (VRoid Hub); only rendered clips are included | VRoid Hub conditions set by the author (credit required, no redistribution of the model) |
| Sora, Plus Jakarta Sans | fonts, bundled in `assets/fonts/` so the app works offline; their licence text is in the app too (Profile → About → View licenses) | SIL Open Font License 1.1 |
