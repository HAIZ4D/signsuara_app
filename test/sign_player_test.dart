import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/signer/sign_player_view.dart';

/// A made-up clip: frame n is an image n pixels wide, so a test can see which frame is showing.
class _FakeClip implements ClipReader {
  _FakeClip(this.frames, this.times);

  final List<ui.Image> frames;
  final List<Duration> times;
  Completer<void>? slow; // when set, frames after the first wait for it (slow decoding)
  var _next = 0;
  var disposed = false;

  @override
  int get frameCount => frames.length;

  @override
  Future<(ui.Image, Duration)> nextFrame() async {
    final i = _next++ % frames.length;
    if (i > 0 && slow != null) await slow!.future;
    return (frames[i].clone(), times[i]);
  }

  @override
  void dispose() => disposed = true;
}

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ui.Image> images; // widths 1..5
  final clips = <String, _FakeClip>{};
  final opened = <String>[];

  Future<ClipReader?> open(String id) async {
    opened.add(id);
    return switch (id) {
      'a' => clips['a'] = _FakeClip(images.sublist(0, 3), [_ms(40), _ms(40), _ms(40)]),
      'b' => clips['b'] = _FakeClip(images.sublist(3, 5), [_ms(60), _ms(60)]),
      'still' => clips['still'] = _FakeClip(images.sublist(0, 1), [Duration.zero]),
      'slow' => clips['slow'] = _FakeClip(images.sublist(0, 3), [_ms(40), _ms(40), _ms(40)])..slow = Completer(),
      _ => null, // no clip for this sign yet
    };
  }

  setUpAll(() async {
    images = [for (var w = 1; w <= 5; w++) await createTestImage(width: w, height: 1, cache: false)];
  });

  setUp(() {
    clips.clear();
    opened.clear();
  });

  // One screen moment: decoding finishes, then time moves on.
  Future<void> step(SignPlayer player, int ms) async {
    await pumpEventQueue();
    player.advance(_ms(ms));
    await pumpEventQueue();
  }

  test('the placeholder clips decode: frames, times and a transparent background', () async {
    final a = CodecClipReader(
        await ui.instantiateImageCodec(File('test/fixtures/signs/placeholder_a.webp').readAsBytesSync()));
    expect(a.frameCount, 3);
    final (image, time) = await a.nextFrame();
    expect(time, _ms(40));
    expect([image.width, image.height], [48, 48]);
    final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    expect(pixels.getUint8(3), 0, reason: 'corner pixel is see-through');

    final still = CodecClipReader(
        await ui.instantiateImageCodec(File('test/fixtures/signs/placeholder_still.webp').readAsBytesSync()));
    expect(still.frameCount, 1);
  });

  test('app clips come from assets/signs/<id>.webp; a sign without a clip gives null', () async {
    final bundle = _Bundle({'assets/signs/placeholder_b.webp': File('test/fixtures/signs/placeholder_b.webp')});
    expect((await openAssetClip('placeholder_b', bundle: bundle))!.frameCount, 2);
    expect(await openAssetClip('terima_kasih', bundle: bundle), isNull);
  });

  test('plays each clip frame by frame, then the next; the last picture stays (rest pose)', () async {
    final player = SignPlayer(open: open);
    await player.play(['a', 'b']);
    expect([player.index, player.frame!.width], [0, 1]);
    await step(player, 39);
    expect(player.frame!.width, 1, reason: 'not yet its time');
    await step(player, 1);
    expect(player.frame!.width, 2);
    await step(player, 40);
    expect(player.frame!.width, 3);
    await step(player, 40);
    expect([player.index, player.frame!.width], [1, 4], reason: 'second clip');
    expect(clips['a']!.disposed, isTrue);
    await step(player, 60);
    await step(player, 60);
    expect([player.playing, player.index, player.frame!.width], [false, 2, 5]);
  });

  test('half speed takes twice as long', () async {
    final player = SignPlayer(open: open)..speed = 0.5;
    await player.play(['a']);
    await step(player, 40);
    expect(player.frame!.width, 1);
    await step(player, 40);
    expect(player.frame!.width, 2);
    player.speed = 3;
    expect(player.speed, 1, reason: 'never faster than normal');
  });

  test('a sign without a clip is skipped and reported', () async {
    final player = SignPlayer(open: open);
    await player.play(['zzz', 'b']);
    expect([player.index, player.frame!.width], [1, 4]);
    expect(player.missing, ['zzz']);

    await player.play(['zzz']);
    expect([player.playing, player.missing], [false, ['zzz']]);
  });

  test('a still picture is held for a moment', () async {
    final player = SignPlayer(open: open);
    await player.play(['still', 'b']);
    await step(player, SignPlayer.stillHold.inMilliseconds - 1);
    expect(player.index, 0);
    await step(player, 1);
    expect(player.index, 1);
  });

  test('slow decoding waits: no frame is skipped', () async {
    final player = SignPlayer(open: open);
    await player.play(['slow']);
    await step(player, 40);
    await step(player, 500);
    expect(player.frame!.width, 1, reason: 'frame 2 is not decoded yet');
    clips['slow']!.slow!.complete();
    await step(player, 1);
    expect(player.frame!.width, 2, reason: 'then frame 2, not frame 3');
  });

  test('a new sentence replaces the one playing; replay starts again', () async {
    final player = SignPlayer(open: open);
    await player.play(['a']);
    await player.play(['b']);
    expect([player.index, player.frame!.width], [0, 4]);
    expect(clips['a']!.disposed, isTrue);
    await step(player, 60);
    await step(player, 60);
    expect(player.playing, isFalse);

    await player.replay();
    expect([player.playing, player.frame!.width], [true, 4]);
    player.stop();
    expect(player.playing, isFalse);
  });

  testWidgets('the view shows the picture and drives the clock while playing', (tester) async {
    final player = SignPlayer(open: open);
    addTearDown(player.dispose);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: SignPlayerView(player: player)));
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);

    await player.play(['a']);
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 1);
    for (var i = 0; i < 6; i++) {
      await tester.pump(_ms(40));
    }
    expect(player.playing, isFalse, reason: 'the screen clock played it to the end');
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 3);
  });
}

/// Assets for the test: only the given files exist.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, File> files;

  @override
  Future<ByteData> load(String key) async {
    final file = files[key];
    if (file == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(file.readAsBytesSync());
  }
}
