import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/listen/listen_session.dart';
import 'package:signsuara_app/listen/note_store.dart';
import 'package:signsuara_app/speech/sign_words.dart';

void main() {
  late List<SpeechLanguage> listens;
  late int stops;
  late MemoryNoteStore store;
  late ListenSession session;
  var finished = 0; // Android's "done" count, as the transcriber reports it

  setUp(() {
    listens = [];
    stops = 0;
    finished = 0;
    store = MemoryNoteStore();
    session = ListenSession(
      listen: (language) async => listens.add(language),
      stopListening: () async => stops++,
      store: () => store,
      clock: () => DateTime(2026, 10, 1, 10),
      restartDelay: Duration.zero,
    );
  });
  tearDown(() => session.dispose());

  // What the microphone reports to the session.
  void mic({bool listening = true, String text = '', String? error, String? problem}) =>
      session.heard(listening: listening, text: text, finished: finished, error: error, problem: problem);

  // One sentence: heard live, then Android stops and says "done".
  void sentence(String words) {
    mic(); // the listen runs
    mic(text: words);
    mic(listening: false, text: words);
    finished++;
    mic(listening: false, text: words);
  }

  Future<void> later() => Future<void>.delayed(Duration.zero); // lets the restart timer run
  Future<List<ListenNote>> saved() => store.watch().first;
  List<String> lines() => [for (final l in session.lines) l.text];

  test('each finished sentence becomes a line, and listening starts again', () async {
    await session.start(SpeechLanguage.english);
    expect(listens, [SpeechLanguage.english]);
    mic();
    mic(text: 'Good morning');
    expect(session.live, 'Good morning', reason: 'shown while it is heard');
    mic(listening: false, text: 'Good morning everyone');
    finished++;
    mic(listening: false, text: 'Good morning everyone');
    expect(lines(), ['Good morning everyone']);
    expect(session.live, isEmpty);
    await later();
    expect(listens, hasLength(2), reason: 'Android stops after each pause: the session listens again');
  });

  test('late words of the listen before are not added twice', () async {
    await session.start(SpeechLanguage.malay);
    sentence('Selamat pagi');
    await later(); // the next listen is asked for, not running yet
    finished++;
    mic(listening: false, text: 'Selamat pagi'); // a late "done" with the old words
    mic(); // now the new listen runs
    sentence('Apa khabar');
    expect(lines(), ['Selamat pagi', 'Apa khabar']);
  });

  test('silence just starts listening again, quietly', () async {
    await session.start(SpeechLanguage.malay);
    mic();
    mic(listening: false, error: 'error_no_match', problem: "Didn't catch that.");
    expect(session.state, ListenState.listening);
    expect(session.problem, isNull);
    await later();
    expect(listens, hasLength(2));
  });

  test('a real problem pauses with plain words; Continue listens again', () async {
    await session.start(SpeechLanguage.malay);
    mic();
    mic(text: 'Makan ubat ini');
    mic(listening: false, text: 'Makan ubat ini', error: 'error_network');
    expect(session.state, ListenState.paused);
    expect(session.problem, contains('internet'));
    expect(lines(), ['Makan ubat ini'], reason: 'the words heard before the problem are kept');
    await later();
    expect(listens, hasLength(1), reason: 'no endless retries without internet');
    await session.resume();
    expect(session.state, ListenState.listening);
    expect(session.problem, isNull);
    expect(listens, hasLength(2));
  });

  test('when it cannot start at all, it pauses with the reason', () async {
    await session.start(SpeechLanguage.malay);
    mic(listening: false, problem: 'Speech recognition is not available.');
    expect(session.state, ListenState.paused);
    expect(session.problem, 'Speech recognition is not available.');
  });

  test('saved every 3 sentences while it runs, and at Stop; kind and title come after', () async {
    await session.start(SpeechLanguage.english);
    for (final words in ['One', 'Two']) {
      sentence(words);
      await later();
    }
    expect(await saved(), isEmpty);
    sentence('Three');
    expect((await saved()).single.lines, hasLength(3), reason: 'a closed app loses little');

    await later();
    mic();
    mic(text: 'Four, cut short');
    final note = (await session.stop())!;
    expect(stops, 1);
    expect([for (final l in note.lines) l.text], ['One', 'Two', 'Three', 'Four, cut short']);
    expect(session.state, ListenState.idle);

    final kept = await session.keep(note, kind: NoteKind.meeting, title: '  ');
    expect(kept.title, startsWith('Meeting · '), reason: 'an empty title gets the default');
    final only = (await saved()).single;
    expect(only.kind, NoteKind.meeting);
    expect(only.lines, hasLength(4));
  });

  test('Pause keeps the words so far; words after it are not used', () async {
    await session.start(SpeechLanguage.english);
    mic();
    mic(text: 'Please wait');
    await session.pause();
    expect(session.state, ListenState.paused);
    expect(lines(), ['Please wait']);
    expect(stops, 1);
    mic(listening: false, text: 'Please wait for me');
    expect(lines(), ['Please wait']);
  });

  test('nothing heard: Stop keeps nothing; a discarded note is deleted', () async {
    await session.start(SpeechLanguage.english);
    expect(await session.stop(), isNull);
    expect(await saved(), isEmpty);

    await session.start(SpeechLanguage.english);
    sentence('Hello');
    final note = (await session.stop())!;
    expect(await saved(), hasLength(1));
    await session.discard(note);
    expect(await saved(), isEmpty);
  });
}
