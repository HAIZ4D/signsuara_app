import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/learn/learn_progress.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('XP makes levels: one level per 100 XP', () async {
    final progress = LearnProgress();
    expect((progress.xp, progress.level, progress.xpInLevel), (0, 1, 0));
    expect((await progress.finishRound(xp: 80)).levelUp, isFalse);
    final reward = await progress.finishRound(xp: 40);
    expect((progress.xp, progress.level, progress.xpInLevel, reward.xp, reward.levelUp), (120, 2, 20, 40, true));
  });

  test('streak: +1 on the next day, the same on the same day, 0 after a missed day, then 1 again', () async {
    var now = DateTime(2026, 10, 31, 22); // across the end of a month
    final progress = LearnProgress(clock: () => now);
    expect(progress.streak, 0);
    await progress.finishRound(xp: 10);
    await progress.finishRound(xp: 10);
    expect(progress.streak, 1, reason: 'two rounds on one day');

    now = DateTime(2026, 11, 1, 7);
    expect((progress.streak, progress.playedToday), (1, false), reason: 'yesterday counts until today is over');
    await progress.finishRound(xp: 10);
    expect(progress.streak, 2);

    now = DateTime(2026, 11, 3, 9);
    expect(progress.streak, 0, reason: 'a whole day was missed');
    await progress.finishRound(xp: 10);
    expect(progress.streak, 1);
  });

  test('badges: every letter right once = Alphabet master; 7 days in a row; only new ones are reported', () async {
    var now = DateTime(2026, 11, 1);
    final progress = LearnProgress(clock: () => now);
    expect((await progress.finishRound(xp: 10, letters: 'abcdefghijklm'.split(''))).badges, isEmpty);
    expect((await progress.finishRound(xp: 10, letters: 'nopqrstuvwxyz'.split(''))).badges, [LearnBadge.alphabetMaster]);
    expect((await progress.finishRound(xp: 10, letters: ['a'])).badges, isEmpty, reason: 'already unlocked');

    late RoundReward reward;
    for (var day = 2; day <= 7; day++) {
      now = DateTime(2026, 11, day);
      reward = await progress.finishRound(xp: 10);
    }
    expect(progress.streak, 7);
    expect(reward.badges, [LearnBadge.streak7]);
    expect(progress.has(LearnBadge.firstSign), isFalse, reason: 'Sign Quest gives that one');
  });

  test('progress is still there after the app restarts; damaged data starts from zero', () async {
    DateTime today() => DateTime(2026, 11, 8);
    final progress = LearnProgress(clock: today)..load(await AppStorage.open());
    await progress.finishRound(xp: 30, letters: ['a'], earned: [LearnBadge.firstSign]);

    final restarted = LearnProgress(clock: today)..load(await AppStorage.open());
    expect((restarted.xp, restarted.streak, restarted.has(LearnBadge.firstSign)), (30, 1, true));
    expect(restarted.lettersRight, {'a'});

    for (final damaged in ['not json', '{"xp": "lots"}', '{"badges": 7}']) {
      SharedPreferences.setMockInitialValues({'learn_progress': damaged});
      final progress = LearnProgress()..load(await AppStorage.open());
      expect((progress.xp, progress.streak, progress.has(LearnBadge.firstSign)), (0, 0, false), reason: damaged);
    }
  });
}
