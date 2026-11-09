import '../signer/sign_clips.dart';
import 'learn_progress.dart';

/// A unit of Learn's path (README "Learn"): a few signs learned together. [signs] are clip ids and
/// may list more than the app has clips for today: those with a clip are taught, the others join
/// by themselves when their clip is added.
class LearnUnit {
  const LearnUnit(this.id, this.title, this.english, this.signs);

  final String id; // saved with the stars: never change it
  final String title; // Malay
  final String english;
  final List<String> signs;

  /// The signs the avatar can show now.
  List<String> available(SignClipLibrary library) => [for (final s in signs) if (library.ids.contains(s)) s];
}

List<String> _letters(String from, String to) =>
    [for (var c = from.codeUnitAt(0); c <= to.codeUnitAt(0); c++) 'letter_${String.fromCharCode(c)}'];

/// THE path, in order: words and letters take turns, so it never gets long-winded.
final kLearnUnits = <LearnUnit>[
  LearnUnit('kenali_diri', 'Kenali Diri', 'Introduce yourself', ['assalamualaikum', 'saya', 'nama', 'awak', 'terima_kasih']),
  LearnUnit('huruf_ai', 'Huruf A–I', 'Letters A to I', _letters('a', 'i')),
  LearnUnit('jawab_tanya', 'Jawab & Tanya', 'Answer and ask', ['ya', 'tidak', 'apa', 'baik', 'boleh', 'faham', 'mana']),
  LearnUnit('huruf_jr', 'Huruf J–R', 'Letters J to R', _letters('j', 'r')),
  LearnUnit('berbual', 'Berbual', 'Chatting',
      ['apa_khabar', 'buat_apa', 'sudah', 'makan_tengahari', 'makan', 'minum', 'tolong', 'maaf', 'tandas', 'sakit']),
  LearnUnit('huruf_sz', 'Huruf S–Z', 'Letters S to Z', _letters('s', 'z')),
  LearnUnit('agama', 'Agama', 'Religion', ['islam', 'solat', 'puasa', 'zakat']),
];

/// A unit is shown once the avatar can show at least this many of its signs.
const unitMinSigns = 2;

/// The share of a unit's quiz to get right to pass it (and open the next unit).
const unitPassShare = 0.7;

/// The units on the path now: those with enough signs the avatar can show.
List<LearnUnit> pathUnits(SignClipLibrary library) =>
    [for (final u in kLearnUnits) if (u.available(library).length >= unitMinSigns) u];

/// How many of [total] questions must be right to pass.
int unitPassMark(int total) => (total * unitPassShare).ceil();

/// A unit quiz's stars: 3 all right, 2 passed, 0 not passed.
int quizStars(int right, int total) => right >= total ? 3 : (right >= unitPassMark(total) ? 2 : 0);

/// The first unit is always open; any other once the one before is passed (2 stars or more).
bool unitOpen(List<LearnUnit> units, LearnProgress progress, int i) => i == 0 || progress.unitStars(units[i - 1].id) >= 2;

int unitsPassed(List<LearnUnit> units, LearnProgress progress) => units.where((u) => progress.unitStars(u.id) >= 2).length;

/// The unit to do next: the first open one not passed yet; when all are passed, the first without 3
/// stars; null when every unit is perfect (or there are none).
int? currentUnit(List<LearnUnit> units, LearnProgress progress) {
  for (var i = 0; i < units.length; i++) {
    if (unitOpen(units, progress, i) && progress.unitStars(units[i].id) < 2) return i;
  }
  for (var i = 0; i < units.length; i++) {
    if (progress.unitStars(units[i].id) < 3) return i;
  }
  return null;
}
