import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/history/conversation_history.dart';
import 'package:signsuara_app/history/conversation_log.dart';
import 'package:signsuara_app/speech/sign_words.dart';

import 'fake_auth_backend.dart';

void main() {
  late DateTime now;
  late ConversationLog log;

  ConversationHistory historyFor(Account account) =>
      ConversationHistory(log: log, account: account, words: wordsFor);

  setUp(() {
    now = DateTime(2026, 9, 29, 10);
    log = ConversationLog(clock: () => now);
  });

  void later(Duration d) => now = now.add(d);

  List<List<String>> lines(ConversationHistory history) => [
        for (final c in history.recent) [for (final m in c.messages) m.shown(SpeechLanguage.english)]
      ];

  test('messages close together are one conversation; a 5-minute pause starts the next', () async {
    final history = historyFor(Account(FakeAuthBackend()));
    log.addSigned('Saya');
    later(const Duration(seconds: 30));
    log.addHeard('Please wait');
    later(ConversationHistory.quietGap);
    log.addSigned('TerimaKasih');
    await pumpEventQueue();

    expect(lines(history), [
      ['Thank you'], // newest first
      ['I / Me', 'Please wait'],
    ]);
    expect(history.kept, isFalse, reason: 'guest: this session only');
  });

  test('clearing the chat ends the conversation; the old one stays in the history', () async {
    final history = historyFor(Account(FakeAuthBackend()));
    log.addSigned('Nama');
    log.clear();
    later(const Duration(seconds: 5));
    log.addSigned('A');
    await pumpEventQueue();
    expect(lines(history), [
      ['A'],
      ['Name'],
    ]);
  });

  test('heard words that arrive late update the saved message', () async {
    final history = historyFor(Account(FakeAuthBackend()));
    log.transcript(listening: true, text: '');
    log.transcript(listening: false, text: 'Sila');
    log.transcript(listening: false, text: 'Sila tunggu');
    await pumpEventQueue();
    expect(lines(history), [
      ['Sila tunggu'],
    ]);
  });

  test('signing in during a conversation saves it to the account', () async {
    final backend = FakeAuthBackend();
    final account = Account(backend);
    final history = historyFor(account);
    log.addSigned('Saya');
    await account.signIn();
    await pumpEventQueue();

    expect(history.kept, isTrue);
    final saved = await backend.stores[testUser.uid]!.watch().first;
    expect(saved.single.messages.single.label, 'Saya');
    expect(lines(history), [
      ['I / Me'],
    ]);
  });

  test('after signing out, the conversations of the account are not shown', () async {
    final account = Account(FakeAuthBackend(currentUser: testUser));
    final history = historyFor(account);
    log.addSigned('Nama');
    await pumpEventQueue();
    expect(history.recent, hasLength(1));

    log.clear();
    await account.signOut();
    await pumpEventQueue();
    expect(history.kept, isFalse);
    expect(history.recent, isEmpty);
  });

  test('deleting the conversation still going on: later messages start a fresh one', () async {
    final history = historyFor(Account(FakeAuthBackend()));
    log.addSigned('Saya');
    await pumpEventQueue();
    await history.delete(history.recent.single.id);
    later(const Duration(seconds: 10));
    log.addSigned('Nama');
    await pumpEventQueue();
    expect(lines(history), [
      ['Name'],
    ], reason: 'the deleted "Saya" is not saved again');
  });

  test('a custom sign keeps its words as they were when it was signed', () async {
    var phrase = const SignWords('Saya lapar', 'I am hungry');
    final history = ConversationHistory(log: log, account: Account(FakeAuthBackend()), words: (_) => phrase);
    log.addSigned('custom:1');
    await pumpEventQueue();
    phrase = const SignWords('custom:1', 'custom:1'); // the custom sign was deleted
    later(const Duration(seconds: 10));
    log.addHeard('Okay'); // the whole conversation is saved again
    await pumpEventQueue();
    expect(lines(history), [
      ['I am hungry', 'Okay'],
    ]);
  });
}
