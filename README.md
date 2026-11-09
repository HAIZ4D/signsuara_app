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
  sentence is kept as a **note**, which Gemini turns into clear, simple notes when you ask
  (see "Listen and Notes").
- **Custom gestures**: record your own gesture on the phone and give it a Malay/English phrase.
- **Optional Google sign-in** (Firebase): the app greets you by name, keeps your
  **conversation history** (read back or delete past conversations) and **backs up your custom
  gestures** (they come back after a reinstall or on a new phone). Guests can use everything on
  the phone; their conversations are kept until the app closes.
- **Profile & settings**: your name and photo (change them when signed in), glove connection, speech
  language, voice test, conversation history (count, clear all), gesture backup (check now),
  Google account, about and licences. Home greets you by time of day ("Good morning", …).
- **Home** (`lib/screens/home_screen.dart`): under the greeting, a **voice line**
  (`lib/ui/widgets/voice_ribbon.dart`, three glowing waves in the Deaf Flag colours) follows the
  glove: calm while it is off, livelier while it is connected, and a burst each time a sign is
  spoken; the glove card then shows the last sign. In the evening a few stars twinkle in the
  header. Every animation stands still when the phone's "remove animations" setting is on.
- **Learn mode** (see "Learn"): games to learn BIM with the signer avatar, with XP, levels, a
  daily streak, badges and a **learning path** of units (watch, quiz, practise; 3 stars each):
  **Teka Isyarat** (guess the sign), **Sign Quest** (copy the sign with
  the glove, with a live finger meter), **Eja Nama** (any name fingerspelled; **Baca Jari**: read
  her fingers and type the word), **Learn the signs you heard** (a lesson made from the signs said
  in a Listen note) and **Gemini Quiz** (a quiz made from your Listen notes).
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
  Class, Consultation, Program or Other) and a title (by default the kind, date and time, like
  "Meeting · Thu 1 Oct, 3:51 PM": a real date, as titles are read again later), or throw it away.
  The note is also saved
  every 3 sentences while the session runs, so a closed app loses little. Signed in: in the
  account (`users/{uid}/notes`, see "Firebase setup"); guest: kept until the app closes.
- **Notes tab** (`lib/screens/notes_screen.dart`, replaces the old Learn placeholder): every note,
  newest first and grouped by day. The numbers at the top are real (notes, time listened, notes
  with Gemini notes). **Search** looks in titles, sentences and Gemini's notes as you type and
  marks the words it found; **chips** show one kind of note. Each card is kept quiet: a small icon
  for its kind, the title, Gemini's summary or the first words, and one line with how long it was
  and "Gemini notes" when there are some; ⋮ opens, copies, edits or deletes it without opening it
  (no swipe gestures). Home shows the latest note, and a Notes tile with the count.
- **A note** (`lib/screens/note_screen.dart`, `note_summary_view.dart`): a dark header with the
  kind, date, title, length and language, and a **speech timeline** ("when words were said",
  `lib/ui/widgets/speech_rhythm.dart`: the session cut into equal slices of time, each bar as tall
  as the words heard in it; real data, not a sound level); a floating switch at the bottom
  between **Gemini notes** and **What was said** (every sentence on a timeline with its time); and
  **Aa** for bigger words (three steps, on top of the phone's own text size). Copy as text, edit
  (kind and title, with the same sheet as after Stop) or delete. Every animation stands still when
  the phone's "remove animations" setting is on.
- **Summaries by Gemini** (`lib/listen/note_summary.dart`, `lib/cloud/gemini_summarizer.dart`):
  only when you tap **Summarise with Gemini** in a note. Gemini (model `gemini-3.8-flash`, through
  Firebase AI Logic) gets the note's sentences with their times and is asked to write, in the
  note's language, in short simple sentences, only what was said, keeping every number, date,
  time and dose exactly. Its answer comes back as JSON with a fixed shape and is shown as cards:
  **Summary**, **Key points** (numbered), **Advice & to do** (a list to tick off, with how much is
  done; the ticks are kept in the note), **Important details** (yellow chips; a tap copies one, for
  a calendar or a message) and **Words explained** (hard, medical, scientific or religious words
  with a simple meaning); empty parts are left out. While Gemini writes, light sweeps over
  placeholder lines. The summary is saved in the note (also offline, sent later), shown in the
  Notes list and on Home, and part of the copied text. "Summarise again" asks first (it replaces
  the notes and their ticks, and costs a request); the full transcript always stays.
- **Privacy:** before the first summary the app says what happens and asks: the note's words are
  sent to Google's Gemini. SignSuara uses the **paid** Agent Platform Gemini API (formerly Vertex
  AI), whose terms say requests are not used to train Google's models (the free tier of the Gemini
  Developer API may use them and let people read them, so it is not used). Nothing is sent before
  you tap.
- **Not medical advice:** Gemini can make mistakes, so each summary says "Made by Gemini: check
  important details", and doses and dates should be checked against what was said.
- **Limitations:** the restart after each sentence takes a moment, so a word said exactly then can
  be missed; some phones play a short sound each time listening starts; speech recognition and
  summaries need internet, and a long session uses more battery.

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
- **Categories** (`GestureCategory` in `lib/custom/custom_gesture.dart`): BIM often has no sign for
  religious, scientific or technical words, which is where custom gestures help most, so each
  gesture is **Religious**, **Science**, **Technical** or **Personal**. It is chosen when recording
  (`lib/custom/gesture_category_ui.dart`) and can be changed later; it only sorts the gestures
  (recognition does not use it). Gestures saved before categories existed are Personal.
- **The Gestures tab** (`lib/custom/custom_gestures_page.dart`): real numbers (your signs, built-in
  signs), "Record a new gesture", the four categories with how many gestures each has (a tap shows
  only that category; an empty one offers to record a gesture straight into it), and each gesture
  like a dictionary entry: the Malay phrase, its English, its category and Still or Moving. ⋮
  changes the category or deletes the gesture (after asking). The built-in signs are listed at the
  end, as a reminder to make custom gestures clearly different.

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
  the elbow does not swing out (`track_frames()`: both arms at once, each with its own keys, and the
  handshape blending from one to the next, e.g. fingers opening while the hand moves). An action `face:<id>` on the face's shape keys gives a sign a
  facial expression (TERIMA KASIH: a small smile; the questions APA, BUAT APA and APA KHABAR: a
  questioning face as in the reference pictures and video, with the inner eyebrows raised, the eyes
  a little wider and the lips pushed slightly forward, coming in as the hands rise and relaxing at
  the end); other signs keep a neutral face. The
  character's jacket sleeves are very wide (a radius of about 5.3 cm round an arm of about 2.4 cm):
  they made the forearms look big, and the cuffs hid the hand whenever the wrist bent (SAYA pointing
  at the chest). So the forearm part of the sleeves is slimmed with a shape key (`slim_sleeves()`:
  about a quarter slimmer from just above the elbow, more towards the cuff, which ends at the wrist;
  jacket and shirt get the same factors, so the shirt never shows through the jacket, and both stay
  at least 8 and 4 mm outside the arm, measured all round it). The model's own mesh is unchanged,
  and its licence allows changes. The posing helpers only ever turn bones: a scale error that had
  slowly built up on the right hand (it bent that hand's fingers and thumb out of shape) is gone,
  and `render_signs.py` clears any stray bone location or scale before it renders. The hair and eyebrows are
  recoloured from blue to brown the same way: `hair_colour()` swaps in brown copies of their
  textures (shading kept) and keeps the originals.
  1. `tools/blender/render_signs.py` (run inside Blender) renders every `sign:` action to
     `character/renders/<id>/0001.png …`;
  2. `python tools/make_sign_clips.py [id …]` turns those frames into `assets/signs/<id>.webp`
     (560 px; the bottom tenth of each frame fades out, because the picture is cut at the skirt).
     The app picks the new clips up by itself; run `flutter clean` before the next build, or
     Flutter's build cache can leave newly added clip files out of the app.
- **Recorded so far:** `rest`, `spell_in`, `spell_out`, `terima_kasih`, `saya`, `nama`, `ya`,
  `tidak`, and then `awak`, `apa`, `sudah`, `buat_apa`, `apa_khabar`, `makan_tengahari` (posed from
  BIM Sign Bank pictures, right hand; NAMA, APA, SUDAH, BUAT APA, APA KHABAR and MAKAN TENGAHARI
  with both hands), and the whole alphabet `letter_a` … `letter_z` (see Fingerspelling below).
  The newer signs: AWAK = index finger pointing
  at the person in front, a small push; APA = left hand open, fingers up, the right index pointing
  at its palm and moving down along it; SUDAH = loose fists at the chest flick down and open, palms
  down, fingers spread; APA KHABAR = flat hands (thumbs up) on the upper chest move down and close
  into thumbs-up fists. BUAT APA and MAKAN TENGAHARI follow videos of signers: BUAT APA = both
  hands at mid-chest, palms up with the knuckles towards the viewer (turned a little towards each
  other so the pinch shows from the front), the other fingers in a fist, the thumb up on the
  outer side and the index rising (bent mainly at its knuckle) to pinch the thumb tip above the
  fist; the hands swing together to her left and right and the pinch closes and opens with them,
  twice (closed to the left; open to the right: the thumb drawn back and the index a little
  straighter, tips about 2.5 cm apart, so both fingers move), then holds; MAKAN TENGAHARI = MAKAN (the bunched fingertips touch the lips twice, the hand coming
  from her right side), then the hand opens and goes up: TENGAH HARI = the right forearm upright,
  palm towards the middle, the elbow low; only then the left forearm comes across under that
  elbow. The character's arms are short for her chest and jacket, so TENGAH HARI sits a little
  higher and the left elbow comes forward: that way the left forearm lies across the front of the
  jacket instead of through it. `parts_clash()` (in `sign_pose.py`: skin and sleeve triangles of
  a forearm passing through the torso) finds no forearm inside the body on any frame, and the right
  arm comes back down in front of her.
  SAYA and NAMA were then refined from a description of the signs: SAYA = index-finger fist at the
  middle of the chest, one small light touch; NAMA = two H hands (index and middle finger straight
  and together, ring and little finger curled, thumb folded across them) in front of the lower
  chest, palms facing the body and a little down; the left hand stays still, the right hand starts
  9 cm above, taps twice across the middle of the left fingers (a small X; right fingers tilted
  ~27°), lifting 3.5 cm between the taps, then moves away before both hands go back to rest.
  `hands_clash()` (in `sign_pose.py`) counts skin triangles of one hand that pass through the
  other: 0 on every NAMA frame. Clips are 560 px; the camera frames the upper
  body from just above the head to just below the resting hands.
- **Fingerspelling:** the letters follow fingerspelling charts of the one-handed alphabet, with
  the right hand at the place beside the face where letters are signed (the open hand of
  `spell_in`); every letter clip starts and ends there, and holds its handshape for a quarter of a
  second (14 frames, about 0.6 s a letter). Most letters only change the handshape: the hand is
  turned a little where the chart shows it from the side, so the shape reads from the front
  (C and O open towards the middle, F's ring of index and thumb is turned towards the viewer,
  G and H point sideways towards her middle). P and Q point down: the forearm comes across from
  the side and the hand bends down at the wrist (an upright forearm cannot bend the hand that far).
  J and Z move, and are written the signer's own way, so the viewer sees them mirrored, as in the
  charts: J = the I hand drops while the palm turns towards her, so the little finger draws a J
  (a 7 cm stem down, then a 5.5 cm hook towards her middle); Z = the index draws a 7 cm Z (from
  her view: along the top, diagonally down, along the bottom). A, S, E, M, N and T are all fists
  that differ in where the thumb is (up beside the fist, across the front, under the curled
  fingertips, or peeking out between two fingers); the thumb was placed where the camera can see
  it (checked by tracing lines of sight from the camera to the thumb), but in the toon style these
  six stay subtle on a small screen.
- **Words without a sign clip** are fingerspelled when all their letters have clips, which is now
  every word written with the letters a–z; only words with digits (no number clips yet) are shown
  grey under the avatar, with a note.

## Learn

SignSuara has two sides: **Talk** (Chat, Listen, Gestures, Notes: help to communicate) and
**Learn** (games to learn BIM). Learn opens from the **Learn BIM** card on Home (the capsule nav
has no room for a sixth tab). Code: `lib/learn/`.

- **The hub** (`learn_screen.dart`), built like a game's home screen:
  - **Cikgu Suara** (the avatar) waves hello (`wave` clip, else the rest pose) beside a **speech
    bubble**: "Jom belajar, Haizad!" and ONE suggestion with its button, in this order: today's
    sign of the day (mentioning the streak when it would end today), the next unit of the path,
    the XP still missing for today's goal, or "Today's goal is done".
  - **Counters**: Level (a ring = XP in this level), Today (a ring = today's XP of the 50 XP daily
    goal) and the streak (a flame). The rings fill up when the screen opens.
  - **Sign of the day**: one word sign a day (the same all day, going round all word signs;
    `signOfTheDay`), with the date; watching it gives +5 XP once a day and counts for the streak.
  - **Your path**: the next units on a short dotted line (the next one marked NEXT); "See all"
    opens the whole path.
  - **Play**: the games as a grid of solid-coloured tiles of two sizes (dark turquoise, yellow,
    dark blue, royal blue, white; no glows), each with its icon (also big and faint in a corner),
    name, what you do and a real detail ("37 signs", "1 note with signs"); a tile sinks a little
    while pressed. Sign Quest says "Glove is off" and explains instead of opening without the
    glove. The tiles grow with the phone's text size.
  - **Badges** with how close each one is: "4/26 letters", "1/7 days" (and a ring), or the game
    that gives it.
  All of it is real progress, kept on the phone (today's XP and the sign of the day are saved with
  it).
  - **Motion** ("playful": 150–400 ms, a small overshoot, each with a job): **tap Cikgu Suara and
    she waves again** (cheers every other time, with a light buzz); her bubble pops out from her
    side after she starts waving, and again when her tip changes, its arrow nudging twice; a kept
    streak's flame lights up with a pop; a ring pings from the sign of the day's ▶ until it is
    watched, then "Watched" pops in; the path's dotted trail draws itself in and the NEXT tag bobs
    like a map marker; the game tiles pop in one after another (50 ms apart) and spring back when
    let go; the badges' progress rings fill and unlocked badges pop in. Only the ping and the NEXT
    tag loop, each redrawn on its own; everything stands still with "remove animations" (tapping
    her still works: her signing is content). Measured on the Galaxy A13 (release build): 59.9 fps,
    0 % late frames, at the top of the hub and at the path and games.
- **Learning path** (`learn_units.dart`, `learn_path_screen.dart`): the signs in **units**, in
  order, words and letters taking turns: Kenali Diri (introduce yourself), Huruf A–I, Jawab &
  Tanya (answer and ask), Huruf J–R, Berbual (chatting), Huruf S–Z, Agama (religion). A unit lists
  more signs than have clips today (e.g. ASSALAMUALAIKUM, BAIK, MAKAN, TOLONG); those with a clip
  are taught, the others join by themselves when their clip is added, and a unit appears once 2 of
  its signs have clips (Agama waits for ISLAM, SOLAT, PUASA, ZAKAT). Each unit: **watch** the
  signs (a lesson, ★), its **quiz** (a Teka Isyarat round of just these signs; 70 % passes, ★★,
  and opens the next unit; all right, ★★★), and, for the glove's own signs, **practise with the
  glove** (Sign Quest, optional, so the path works without the glove). The hub's **Continue**
  card opens the unit to do next; "See all" shows the path: the units zig-zag down the page on a
  dotted line (turquoise once passed), locked ones grey with a lock (a tap says which unit opens
  it), the next one yellow. After a unit quiz, Results say what happened ("Unit passed! "Huruf
  A–I" is open now."). Stars are kept with the rest of the progress, on the phone.
- **Teka Isyarat** ("guess the sign", no glove needed; `teka_isyarat.dart`): the avatar signs, you
  pick its meaning from 4 answers. A round is 10 signs, about 5 letters and 5 words, none twice; the
  3 wrong answers come from the same group (letters with letters). Every clip in `assets/signs/`
  can be asked except `rest`, `spell_in`, `spell_out` and the avatar's reactions (`wave`, `cheer`,
  `try_again`), so **a new clip joins the game by itself**. Words show their gloss with the first
  English meaning (`kBimSigns`), letters "Huruf A". 10 seconds a question; with fewer than 4 clips
  the game explains why it can't start.
  Letters are shown as in Listen: the hand rises to the spelling place (`spell_in`), makes the
  letter, and comes down (`spell_out`).
- **Sign Quest** (copy the sign with the glove; `sign_quest_screen.dart`): the avatar shows a sign,
  you tap **I'm ready**, a 3-2-1 countdown, then you sign it. **The glove's own recogniser
  decides** (the same model and live rules as Chat; no new recogniser). 5 signs a round, 3 tries
  each. The signs are the model's labels (not Rest) that have a clip: the label's clip is found by
  one rule (`A` → `letter_a`, `TerimaKasih` → `terima_kasih`; `sign_targets.dart`), so a newly
  trained sign joins once its clip is added.
  - **While the game is open, signs go only to the game** (`AppServices.gestureOverride`): Chat
    neither speaks them nor adds them to the conversation. **Custom gestures are off** during the
    game (`AppServices.customGesturesOn`), so one can't take the place of the sign asked. Both are
    back as soon as the game closes.
  - Recognition is paused outside the signing moment and **starts with an empty window at "Go"**,
    so nothing signed before counts. From an empty start the recogniser needs 1.8 s (a full 38-row
    window plus the same answer twice), so **stars are counted from that moment**: under 2 s = 3★,
    under 4 s = 2★, later = 1★, and the try lasts 6 s after it (a 7.8 s bar).
  - **Another sign seen on the way costs nothing**: the screen shows "The glove sees Nama. Keep
    going!" (a hand passes through other shapes while forming a sign). A try is used up only when
    time runs out; then the avatar shows the sign again. A try the glove can't follow (connection
    lost, motion sensor out: all six motion values 0) is cancelled and not counted.
  - **Finger meter** (`finger_meter.dart`): the five fingers live from the glove, a yellow line
    where each should be, green when a finger is within `kFingerTolerance` (80 ADC counts) of the
    sign's average. A finger moves only ~350–420 counts from straight to bent on this glove, so a
    larger tolerance (300 was the first idea) made almost every finger "in place". The ring around
    the meter fills while 4 or 5 fingers are in place and closes when the glove accepts the sign; it
    only guides. The averages (`kSignFingerTargets`) come from **all training rows** of each sign
    (`tools/export_finger_targets.py`: 26,250 rows, 30–40 recordings a sign; rows with a 4095
    reading would be left out, there were none). Most fingers vary less than 80 across recordings;
    a few vary more (MakanTengahari's index 96, Nama's thumb 88), so those can flicker between in
    place and not.
  - Right: strong vibration, the stars and the word pop up, the phone says the word, +5 XP a star.
    Time up: light vibration, the meter shakes. The hub's card is greyed out with "Connect the
    glove on Home first" until the glove is connected.
- **Eja Nama** (fingerspelling, no glove needed; `eja_nama.dart`, `eja_nama_screen.dart`): type
  any name and the avatar fingerspells it: the hand rises to the spelling place (`spell_in`),
  makes each letter and comes down (`spell_out`), so a name of two words gets a short break. Tiles
  under the stage show the letters, the one being made in yellow. Only the letters A–Z are spelled
  (digits, ' and - are left out, and the screen says so); at most 24 letters. Signed in, the first
  name is already typed. **Baca Jari** ("read the fingers", `read_fingers_screen.dart`): she
  fingerspells one of 35 short everyday Malay words (IBU, KUCING, NASI, …; `kSpellWords`), one box
  per letter shows its length, and you type what you saw (capitals and spaces don't matter). After
  each answer the word and its English are shown; a wrong answer is spelled once more. 5 words a
  round, +10 XP each, and the letters of words read right count for *Alphabet master*.
- **Learn the signs you heard** (`note_signs.dart`, `note_lesson_screen.dart`): it turns what was
  said in a class or a meeting into a BIM lesson. A note's sentences go through the signer's
  translator (phrases first, Malay or English: "thank you" and "terima kasih" are both TERIMA
  KASIH, "I" is SAYA), and every sign with a clip is kept once, in the order first said, with how
  often it was heard. Names and other words that would be fingerspelled are left out (that is Eja
  Nama). The note shows a **Learn the signs you heard** card (only when it has such signs) listing
  them; the hub has **Signs in your notes** (a list of notes with how many signs each has). The
  lesson shows the signs one by one: the avatar signs it, its gloss and English, "Heard 2×", and
  the sentence it was heard in with its words marked. Then **Quiz me on these** (a Teka Isyarat
  round asking only these signs; the wrong answers come from every clip) and, for the glove's own
  signs among them, **Practise with the glove** (Sign Quest). Limit: only the words that have a
  sign clip (11 today) can be taught.
- **Gemini Quiz** (a quiz from a Listen note; `note_quiz.dart`, `gemini_quiz_screen.dart`,
  `lib/cloud/gemini_quiz_maker.dart`): from the hub (pick a note) or from a note's **Quiz yourself**
  card (Make quiz; once one is kept: Play quiz, or New quiz from Gemini). Gemini is asked like for
  summaries (same model, paid service, App Check, the same notice the first time, and the same
  plain error messages, e.g. without internet): for a Deaf learner, in the note's language, only
  from what was said (plus the note's summary, if it has one, to find what matters), short simple
  sentences, 4 answers with one right, no trick questions, one line explaining the answer. **5
  questions, or 3 for a note under 80 words.** The phone checks every question (a question, exactly
  4 different non-empty answers, an answer 0–3) and drops bad ones; none left = "Try again". The
  answers are shuffled on the phone (models like to put the right one first). While Gemini works:
  "Cikgu Suara is reading your notes…". The quiz is **kept on the phone** per note (`AppStorage`),
  so playing it again sends nothing to Gemini. No timer; after each answer its explanation is
  shown. +10 XP per right answer; the first one finished wins *Study buddy*.
- **The quiz screen** (`quiz_screen.dart`, shared by Teka Isyarat and Gemini Quiz): the stage with
  "sign it again" and "slower", a timer bar with the seconds, one dot per question, and the combo.
  Every answer is shown in **three ways** for Deaf users: colour (green right, red wrong; these are
  state colours like the live dot), an icon (✓ / ✗), and words ("Not quite. It's SAYA."), plus a
  vibration (light = right, strong = wrong). A wrong answer or time up shows the right one and
  signs it again; **Next** waits for a tap so it can be watched. "+10 XP" floats up from the stage.
- **Results** (`results_screen.dart`): the score, the XP counting up, level, streak, new badges,
  Play again (a new round) and Back to Learn.
- **Progress** (`learn_progress.dart`), kept **on the phone only** (`AppStorage`, no account
  needed): +10 XP per right answer, one level per 100 XP; the streak grows by one on each new day
  with a finished round, shows 0 once a whole day was missed and starts again at 1. Progress is
  saved when a round is finished; a round left halfway counts nothing. Badges: *First sign* (a sign
  copied in Sign Quest), *Alphabet master* (every letter A–Z right at least once in Teka Isyarat),
  *Study buddy* (a Gemini quiz finished) and *7-day streak*.
- **Motion** (`flutter_animate`): short bounces, shakes and the XP float, 400 ms or less, none of
  them blocking the game; all left out when the phone's "remove animations" setting is on. The
  10-second timer keeps its real speed with that setting (Flutter would otherwise run it 20 times
  faster). A perfect score or a new level gets a second of **confetti** (`confetti`, Deaf Flag
  colours) on Results, also left out with that setting.
- **Felt as well as seen** (vibration, for Deaf users who keep their eyes on the hand or the
  avatar): light = right, strong = wrong or a sign copied; in Sign Quest a tick for each of 3, 2,
  1 and a stronger buzz at "Go"; one buzz on Results for a perfect score, a new level or a badge.
- **The avatar's reactions** (`assets/signs/wave.webp`, `cheer.webp`, `try_again.webp`; the games
  also work without them). None of them is a BIM sign:
  - `wave` (the hub says hello): the right hand rises beside the face, palm forward, and waves
    side to side, with a smile.
  - `cheer` (a sign copied in Sign Quest): **Deaf applause**, both hands up beside the head,
    fingers spread, wrists twisting back and forth (50° each way), with a big smile.
  - `try_again` (time up in Sign Quest, before the sign is shown again): "Semangat!", both closed
    fists in front of the chest pumped twice, a head tilt and a nod, a kind smile. A palms-up
    shrug was tried first and dropped: open palms turned up read as a question ("what?"). The
    fists are closed with the thumb across the fingers: the A fist (thumb up) read as a thumbs-up.
  Like the signs they start and end in the rest pose; the hands first move apart sideways (they
  touch at rest) and no forearm passes through the body (checked on every frame). They are made
  with the same tools (`tools/blender/render_signs.py`, then `python tools/make_sign_clips.py
  <id>`, then `flutter clean`) and are never asked in Teka Isyarat.

## Measurements

- **Python ↔ Dart parity**: for one real window per sign, the Dart features match Python within
  1e-6 and the class probabilities within 1e-9 (`test/parity_test.dart`).
- **BLE does not disturb the flex readings**: glove lying still, phone connected with
  notifications on vs not connected: largest average shift 1.0 ADC count, same jitter
  (2–4 counts), 25 rows/s kept (`firmware/check_flex_noise.py`).
- Hardware note: the thumb flex sensor occasionally reads 4095 (5 of 170 recordings), which
  suggests a loose contact.

## Smoothness

Measured on the development phone, a Samsung Galaxy A13 (Exynos 850, Mali-G52 graphics, 60 Hz
screen), release build, power saving on, with `tools/frame_rate.py` (the times Android showed the
app's frames; no app changes) while the screen's animations run:

| Screen | Before | After | Late frames |
|---|---|---|---|
| Home | 34 fps | 49–50 fps | 78 % → about 20 % |
| Gestures | 51 fps | 54 fps | 16 % → 10 % |
| Notes | 60 fps | 60 fps | 0 % |

Flutter's own frame timings showed why: building a frame took about 2.5 ms, but drawing it on the
graphics chip took about 21 ms on Home (a frame has 16.7 ms). What helped, without changing the
look:

- **No blur on moving things**: the Home voice line's glow is drawn with wide faint lines instead
  of a blur filter (34 → 45 fps on Home by itself).
- **Moderate shadow blurs** (`AppShadows`): a big blur costs work for every pixel it covers, in
  every frame (another ~1.5 ms per frame on every screen).
- **Moving parts on their own layers** (`lib/ui/widgets/motion.dart`): the header's colour blobs
  and the shine are drawn once and only moved; out-of-sight tabs pause their animations
  (`TickerMode` in `lib/app/app_shell.dart`), which also saves battery.
- Small things: the dotted pattern drawn in one call, no extra transparency layer on the waveform.

A second round (power saving off) worked on Listen and Chat, measured the same way. Here building a
frame was cheap again, except while the signer signed:

| Screen | Before | After |
|---|---|---|
| Listen, signer standing | 30 fps | 60 fps |
| Listen, signer signing | 40 fps (already with the cheaper border) | 59 fps |
| Chat, signer signing | 41 fps | 60 fps |
| Chat, idle | 60 fps | 60 fps |
| Home | 49 fps | 53 fps |
| Gestures | – | 59 fps |
| Notes | 60 fps | 60 fps |

- **Soft colour layers painted once** (`BakedGradients`, `lib/ui/widgets/baked_gradients.dart`):
  the graphics chip works out a big gradient pixel by pixel in every frame. The Listen stage's
  three layers (white-to-blue, turquoise spotlight, warm glow) took about 10 ms of the 16.7 ms a
  frame has, the dark header behind the title about 4 ms. They are now painted once into a picture
  that every frame only copies (made again only when the size changes); the look is the same.
  Used for the Listen stage, the dark headers (Home, Chat, Gestures, Notes, Listen) and Chat's
  signing stage. Listen: 24 → 14 ms of drawing per frame.
- **The turning border is only an edge** (`TurningBorder` in `motion.dart`): before, a big
  gradient turned behind the card and was cut to its shape. The stages are no longer cut
  (clipped) to their round corners either: their layers are drawn round already.
- **The avatar's fade is in the clips** (`tools/make_sign_clips.py`): the bottom tenth of each
  frame fades out once, when the clip is made, instead of a mask over the avatar in every frame.
- **The signer no longer rebuilds the whole app for each picture** (`lib/signer/signer.dart`):
  the screens only hear when signing starts or stops, the next sign begins or the speed changes
  (24 times a second before, for all five tabs; the work per frame while signing went from ~9 ms
  to ~2 ms). The avatar has its own layer (`sign_player_view.dart`).
- Tried and dropped: painting the header's drifting blobs once as well made no difference.

For the smoothest app (e.g. a demo): install a **release build** (`flutter build apk --release`,
then `adb install -r build/app/outputs/flutter-apk/app-release.apk`, or `flutter run --release`;
debug builds are much slower), turn **power saving off**, and avoid a phone that is hot from
charging. Home stays the busiest screen: everything on it is redrawn while its animations run.

## Project structure

| Path | Contents |
|---|---|
| `lib/ml/` | `signsuara_model.dart` (generated model), `features.dart`, `gesture_classifier.dart` |
| `lib/glove/` | `glove_ble.dart` (Bluetooth), `glove_session.dart` (packets → classifier) |
| `lib/speech/` | speech map, text-to-speech, speech-to-text |
| `lib/custom/` | custom gestures: model, matcher, generated reference bank, screens, account backup (`gesture_backup.dart`) |
| `lib/app/` | app shell (5 tabs + floating capsule nav) and the shared services (one glove connection) |
| `lib/learn/` | Learn mode: the hub, the learning path (units, lessons), Teka Isyarat, Sign Quest (with the finger meter and the sign targets), Eja Nama and Baca Jari, the lesson of the signs heard in a note, Gemini Quiz, the shared note list, quiz and results screens, progress (XP, streak, badges) |
| `lib/listen/` | Listen sessions and their notes (the note, its store, the list for Notes and Home, the summary and what Gemini is asked) |
| `lib/screens/` | screens: splash, welcome pages, sign-in, Home, Chat (conversation), Listen (hearing), Notes (list + one note), history, Profile & settings |
| `lib/cloud/` | the only folder using Firebase: `account.dart` (Google account or guest), `firebase_auth_backend.dart` (sign-in, profile), `firestore_history_store.dart` (saved conversations), `firestore_gesture_store.dart` (gesture backup), `firestore_note_store.dart` (Listen notes), `gemini_summarizer.dart` and `gemini_quiz_maker.dart` (the only two files using Gemini / `firebase_ai`) |
| `lib/signer/` | words → BIM signs: the sign dictionary, the translator and the clip player |
| `lib/history/` | the conversation shown as chat bubbles (`conversation_log.dart`) and its history (`conversation_history.dart`: when a conversation starts and ends, where it is saved) |
| `lib/theme/app_theme.dart` | all colours, gradients, fonts, spacing, radii and shadows |
| `lib/ui/` | shared widgets (hero panel, glove card, hand-sensor visual, motion) |
| `lib/app_storage.dart` | saved data (custom gestures, BM/EN choice, Learn progress) |
| `firmware/` | ESP32 firmware and the BLE noise check |
| `tools/` | custom-gesture matcher validation (Python); `make_app_icon.dart` draws the launcher icon from the in-app logo (`flutter test tools/make_app_icon.dart`); `make_placeholder_clips.py` makes the test sign clips; `make_sign_clips.py` and `blender/render_signs.py` make the real ones; `frame_rate.py` measures how smooth the app runs on a phone; `export_finger_targets.py` makes Sign Quest's finger guides from the training data |
| `test/` | 245 tests, including parity and replays of real recordings (`test/fixtures/`) |

## Build and run

Requirements: Flutter 3.47 (Dart 3.13), an Android phone with Android 7.0 or newer and
Bluetooth LE. The Android build uses the versions Flutter 3.47 gives new projects: Gradle 9.3,
the Android Gradle Plugin 9.1, Kotlin 2.4 and NDK 28.2. Flutter still warns that several plugins
(the Firebase ones, `flutter_tts`, `speech_to_text`, …) load Kotlin the old way; only their
authors can change that, and the build works.

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

7. **AI Logic** (Gemini summaries of notes): Firebase console → AI Services → AI Logic → Get
   started → choose the **Agent Platform Gemini API** (formerly Vertex AI) and enable the APIs it
   asks for. It is paid per use on the Blaze plan, so also set a **budget with alerts** in Google
   Cloud Billing (for example RM10 a month). No API key goes in the app: Firebase AI Logic uses
   the app's own Firebase project. The model is one constant, `GeminiSummarizer.model`; Google
   retires old Gemini models, so check that it is still offered.
8. **App Check** (only phones you allow may use Gemini; Gemini requires it): the app starts App
   Check with its **debug provider** in every build, because it is not installed from Google Play
   (where the Play Integrity provider would vouch for it). At its first start on a phone, the log
   shows `Firebase App Check debug token: <token>` and a link to the right console page
   (`flutter run` output, or `adb logcat | grep "App Check debug token"`). Add that token in the
   Firebase console → App Check → Apps → the Android app → ⋮ → **Manage debug tokens**. The token
   stays the same while the app stays installed; uninstalling it or clearing its data makes a new
   one. Debug tokens are secrets: never commit them. Without an added token, Gemini refuses the
   phone ("Firebase App Check token is invalid"), and the app says so.

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
  `{text, at}` (one per sentence heard); after Summarise also `summary`: `overview`, the lists
  `keyPoints`, `actions`, `details` and `terms` (`{term, meaning}`), `madeAt` and `model`, and
  `done` (the numbers of the actions ticked off) once something is ticked.
- `users/{uid}/gestures/{id}`: `malay`, `english`, `moving`, `category` (religious, science,
  technical or personal; missing in older backups = personal), `savedAt` and `recordings` (the raw
  recordings as one JSON text, because Firestore can't store lists inside lists).
  The list on the phone is the one the app uses; the account keeps a copy
  (`lib/custom/gesture_backup.dart`): at sign-in, gestures only in the account are added to the
  phone and gestures only on the phone are uploaded; while signed in, every new gesture is
  uploaded (again when its category changes) and every deleted one removed. While signed out nothing is copied, so a gesture
  deleted then comes back at the next sign-in.

Without an account (guest) nothing is saved in Firebase: conversations and notes are kept only
until the app closes. A summary still needs Gemini, so Summarise sends that note's words to it
(through Firebase AI Logic), for guests too.

## Adding a new built-in sign

In the Python pipeline (separate repository): record → retrain → `python export.py`, which
regenerates `lib/ml/signsuara_model.dart`, `test/parity_cases.json` and
`lib/custom/reference_bank.dart`. Then add the sign's words to `kSignWords` and rebuild.
`flutter test` fails until the words are added. No other code changes are needed: the app
never hardcodes the labels, the number of classes or the window size.

For Learn mode (both optional; the sign is recognised without them):
- **Sign Quest asks for it once the avatar can show it:** add its clip as `assets/signs/<id>.webp`,
  where the id is the label in snake_case (`TerimaKasih` → `terima_kasih`; one letter `A` →
  `letter_a`), then `flutter clean` (see "Signer"). The clip also joins Teka Isyarat.
- **Its finger guide** (the yellow lines in Sign Quest): `python tools/export_finger_targets.py`
  prints the averages of all training rows per sign; paste its output over `kSignFingerTargets`
  in `lib/learn/sign_targets.dart`. Without an entry the meter shows the fingers without a guide.

## Limitations and future work

- **Single user**: the model is trained on one person's recordings. Supporting other users would
  need recordings from more people and/or a per-user calibration step.
- Google sign-in needs internet (the rest of the app works without an account).
- Speech-to-text normally needs internet; the Malay voice depends on the phone's TTS engine.
- Custom gestures are compared with the built-in signs, not with each other, so keep them
  clearly different.
- Summaries need internet, and Gemini can make mistakes or miss something (the transcript always
  stays).
- App Check uses the debug provider (the app is not on Google Play), so every phone that should use
  Gemini needs its token added in the console once (see "Firebase setup", step 8).

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
| `firebase_ai` | Gemini summaries of notes and quizzes from notes (Firebase AI Logic) | Apache-2.0 |
| `firebase_app_check` | App Check: proves requests come from this app on an allowed phone | BSD-3-Clause |
| `image_picker` | take or choose a profile photo | Apache-2.0 / BSD-3-Clause |
| `flutter_animate` (+ `flutter_shaders`, which it uses) | Learn mode's short bounces, shakes and floats | BSD-3-Clause |
| `confetti` | Learn mode's confetti for a perfect score or a new level | MIT |
| BIM signer character | "FREE MODEL 青髪三つ編みメガネっ子" by 水銀メイド (VRoid Hub); only rendered clips are included | VRoid Hub conditions set by the author (credit required, no redistribution of the model) |
| Sora, Plus Jakarta Sans | fonts, bundled in `assets/fonts/` so the app works offline; their licence text is in the app too (Profile → About → View licenses) | SIL Open Font License 1.1 |
