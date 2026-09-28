import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/history/conversation_log.dart';

void main() {
  test('signed labels become my messages', () {
    final log = ConversationLog()..addSigned('Saya')..addSigned('Nama');
    expect([for (final m in log.messages) (m.side, m.label)], [(Side.me, 'Saya'), (Side.me, 'Nama')]);
  });

  test('heard text is added when listening stops, and nothing while still listening', () {
    final log = ConversationLog();
    log.transcript(listening: true, text: '');
    log.transcript(listening: true, text: 'Selamat');
    expect(log.messages, isEmpty, reason: 'the live text is only a draft');

    log.transcript(listening: false, text: 'Selamat pagi');
    expect([for (final m in log.messages) (m.side, m.text)], [(Side.them, 'Selamat pagi')]);
  });

  test('final words arriving just after listening stops update the same message', () {
    final log = ConversationLog()
      ..transcript(listening: true, text: '')
      ..transcript(listening: false, text: 'Please wait')
      ..transcript(listening: false, text: 'Please wait here');
    expect(log.messages.single.text, 'Please wait here');
  });

  test('a new listen starts a new heard message', () {
    final log = ConversationLog()
      ..transcript(listening: true, text: '')
      ..transcript(listening: false, text: 'Hello')
      ..addSigned('Saya')
      ..transcript(listening: true, text: '')
      ..transcript(listening: false, text: 'Thank you');
    expect([for (final m in log.messages) m.label ?? m.text], ['Hello', 'Saya', 'Thank you']);
  });

  test('empty results (nobody spoke) add nothing; repeats do not notify', () {
    final log = ConversationLog();
    var notified = 0;
    log.addListener(() => notified++);
    log
      ..transcript(listening: true, text: '')
      ..transcript(listening: false, text: '   ');
    expect(log.messages, isEmpty);

    log
      ..transcript(listening: false, text: 'Hi')
      ..transcript(listening: false, text: 'Hi');
    expect(log.messages, hasLength(1));
    expect(notified, 1);
  });

  test('after a quick reply or clear, the old transcriber text is never added again', () {
    final log = ConversationLog()
      ..transcript(listening: true, text: '')
      ..transcript(listening: false, text: 'Hello')
      ..addHeard('Yes.')
      ..transcript(listening: false, text: 'Hello'); // transcriber still holds old text
    expect([for (final m in log.messages) m.text], ['Hello', 'Yes.']);

    log
      ..clear()
      ..transcript(listening: false, text: 'Hello');
    expect(log.messages, isEmpty);

    log
      ..transcript(listening: true, text: '') // a new listen works normally again
      ..transcript(listening: false, text: 'Hello again');
    expect([for (final m in log.messages) m.text], ['Hello again']);
  });
}
