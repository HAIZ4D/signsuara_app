import 'package:flutter/foundation.dart';

import '../app_storage.dart';

/// A badge in Learn mode; [id] is what is saved.
enum LearnBadge {
  firstSign('first_sign', 'First sign', 'Copy a sign with the glove'),
  alphabetMaster('alphabet_master', 'Alphabet master', 'Get every letter A–Z right'),
  studyBuddy('study_buddy', 'Study buddy', 'Finish a quiz from your notes'),
  streak7('streak_7', '7-day streak', 'Play 7 days in a row');

  const LearnBadge(this.id, this.title, this.how);

  final String id;
  final String title;
  final String how; // how to unlock it
}

/// What a finished round gave (the Results screen shows it).
typedef RoundReward = ({int xp, bool levelUp, List<LearnBadge> badges});

/// Learn mode's progress: XP, level, daily streak and badges (README "Learn"). Kept on the phone
/// only (no account needed). Saved when a round is finished; a round left halfway counts nothing.
class LearnProgress extends ChangeNotifier {
  LearnProgress({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const xpPerLevel = 100;
  static const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  static const dailyGoal = 50; // XP a day (the hub's "Today" ring)
  static const signOfTheDayXp = 5;

  final DateTime Function() _clock;
  AppStorage? _storage;
  var _xp = 0;
  var _streak = 0;
  String? _lastDay; // the day of the last finished round, 'yyyy-mm-dd'
  var _badges = <String>{};
  var _letters = <String>{}; // letters (a–z) answered right at least once
  var _units = <String, int>{}; // stars (1–3) of each unit of the learning path
  var _todayXp = 0; // XP earned on [_xpDay]
  String? _xpDay;
  String? _signDay; // the day the sign of the day was last watched

  int get xp => _xp;

  /// XP earned today (towards [dailyGoal]).
  int get xpToday => _xpDay == _day(_clock()) ? _todayXp : 0;

  /// True once today's sign of the day has been watched.
  bool get watchedSignToday => _signDay == _day(_clock());

  /// Watching the sign of the day: +[signOfTheDayXp] once a day; it counts for the streak too.
  Future<RoundReward?> watchSignOfTheDay() async {
    if (watchedSignToday) return null;
    _signDay = _day(_clock());
    return finishRound(xp: signOfTheDayXp);
  }
  int get level => _xp ~/ xpPerLevel + 1;
  int get xpInLevel => _xp % xpPerLevel;

  /// Days in a row with a finished round; 0 once a whole day was missed.
  int get streak => playedToday || _lastDay == _day(_yesterday) ? _streak : 0;

  bool get playedToday => _lastDay == _day(_clock());

  bool has(LearnBadge badge) => _badges.contains(badge.id);

  Set<String> get lettersRight => Set.unmodifiable(_letters);

  /// The stars a unit of the learning path has (0 = none yet).
  int unitStars(String unit) => _units[unit] ?? 0;

  /// Keeps the best stars a unit has had (1 = watched, 2 = quiz passed, 3 = perfect); saved at once.
  Future<void> rateUnit(String unit, int stars) async {
    if (stars <= unitStars(unit)) return;
    _units[unit] = stars.clamp(1, 3);
    notifyListeners();
    await _save();
  }

  void load(AppStorage storage) {
    _storage = storage;
    final saved = storage.loadLearnProgress();
    try {
      _xp = (saved['xp'] as int?) ?? 0;
      _streak = (saved['streak'] as int?) ?? 0;
      _lastDay = saved['lastDay'] as String?;
      _badges = {...(saved['badges'] as List? ?? const []).cast<String>()};
      _letters = {...(saved['letters'] as List? ?? const []).cast<String>()};
      _units = {...(saved['units'] as Map? ?? const {}).cast<String, int>()};
      _todayXp = (saved['todayXp'] as int?) ?? 0;
      _xpDay = saved['xpDay'] as String?;
      _signDay = saved['signDay'] as String?;
    } catch (_) {
      _xp = _streak = _todayXp = 0; // damaged data: start again rather than crash
      _lastDay = _xpDay = _signDay = null;
      _badges = {};
      _letters = {};
      _units = {};
    }
    notifyListeners();
  }

  /// Counts a finished round: the [xp] it earned, the [letters] answered right, and badges the game
  /// itself awards ([earned]). Returns what was new, for the Results screen.
  Future<RoundReward> finishRound({required int xp, Iterable<String> letters = const [], Iterable<LearnBadge> earned = const []}) async {
    final levelBefore = level;
    final had = {..._badges};
    _xp += xp;
    final today = _day(_clock());
    _todayXp = (_xpDay == today ? _todayXp : 0) + xp;
    _xpDay = today;
    _countToday();
    _letters.addAll(letters);
    _badges.addAll([
      for (final badge in earned) badge.id,
      if (alphabet.split('').every(_letters.contains)) LearnBadge.alphabetMaster.id,
      if (_streak >= 7) LearnBadge.streak7.id,
    ]);
    notifyListeners();
    await _save();
    return (
      xp: xp,
      levelUp: level > levelBefore,
      badges: [for (final badge in LearnBadge.values) if (has(badge) && !had.contains(badge.id)) badge],
    );
  }

  Future<void> _save() async => _storage?.saveLearnProgress({
        'xp': _xp,
        'streak': _streak,
        'lastDay': _lastDay,
        'badges': [..._badges],
        'letters': [..._letters],
        'units': _units,
        'todayXp': _todayXp,
        'xpDay': _xpDay,
        'signDay': _signDay,
      });

  /// A new day after yesterday adds one; after a missed day the streak starts again at 1.
  void _countToday() {
    final today = _day(_clock());
    if (_lastDay == today) return;
    _streak = _lastDay == _day(_yesterday) ? _streak + 1 : 1;
    _lastDay = today;
  }

  DateTime get _yesterday {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - 1); // day 0 = the last day of the month before
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
