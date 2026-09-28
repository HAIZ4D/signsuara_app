import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/history/conversation_log.dart';
import 'package:signsuara_app/history/saved_conversation.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/ui/time_label.dart';

void main() {
  final t = DateTime(2026, 9, 29, 10, 32);
  final conversation = SavedConversation('c1', [
    SavedMessage.signed('TerimaKasih', const SignWords('Terima kasih', 'Thank you'), t),
    SavedMessage.heard('Sama-sama', t.add(const Duration(seconds: 20))),
  ]);

  test('a conversation survives the trip to the database and back', () {
    final back = SavedConversation.fromMap('c1', conversation.toMap())!;
    expect(back.startedAt, t);
    expect(back.updatedAt, t.add(const Duration(seconds: 20)));
    expect([for (final m in back.messages) m.side], [Side.me, Side.them]);
    expect(back.messages.first.label, 'TerimaKasih');
    expect(back.messages.first.shown(SpeechLanguage.english), 'Thank you');
    expect(back.messages.first.shown(SpeechLanguage.malay), 'Terima kasih');
    expect(back.messages.last.shown(SpeechLanguage.english), 'Sama-sama', reason: 'heard words as heard');
  });

  test('damaged saved data is skipped, never a crash', () {
    expect(SavedConversation.fromMap('x', {'messages': 'nope'}), isNull);
    expect(SavedConversation.fromMap('x', {'messages': <Object>[]}), isNull);
    expect(SavedConversation.fromMap('x', {}), isNull);
  });

  test('time labels', () {
    final now = DateTime(2026, 9, 29, 18);
    expect(clockTime(DateTime(2026, 9, 29, 0, 5)), '12:05 AM');
    expect(clockTime(DateTime(2026, 9, 29, 15, 0)), '3:00 PM');
    expect(dayAndTime(DateTime(2026, 9, 29, 10, 32), now: now), 'Today, 10:32 AM');
    expect(dayName(DateTime(2026, 9, 28, 23, 59), now: now), 'Yesterday');
    expect(dayName(DateTime(2026, 9, 21), now: now), 'Mon 21 Sep');
    expect(dayName(DateTime(2025, 12, 31), now: now), 'Wed 31 Dec 2025');
    expect(longDate(now), 'Tuesday, 29 September');
  });
}
