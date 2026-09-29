import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_translator.dart';

import 'fake_clips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image image;
  setUpAll(() async => image = await createTestImage(width: 2, height: 2, cache: false));

  Future<void> after(Duration d, void Function(Duration) advance) async {
    await pumpEventQueue();
    advance(d);
    await pumpEventQueue();
  }

  group('which clips to play', () {
    final steps = SignTranslator().translate('Terima kasih, ya Zad');

    test('a sign with a clip; a name spelled when all its letters have clips', () {
      final library = SignClipLibrary({'terima_kasih', 'ya', 'letter_z', 'letter_a', 'letter_d'});
      expect(library.plan(steps), [
        ('terima_kasih', 0),
        ('ya', 1),
        ('letter_z', 2),
        ('letter_a', 2),
        ('letter_d', 2),
      ]);
    });

    test('a sign without a clip yet is fingerspelled instead; half a word is never shown', () {
      final library = SignClipLibrary({'letter_y', 'letter_a', 'letter_z'});
      expect(library.plan(steps), [('letter_y', 1), ('letter_a', 1)], reason: 'YA spelled, Z·A·D lacks D');
      expect(const SignClipLibrary({}).plan(steps), isEmpty);
    });

    test('the clip list is read from the app assets (only .webp in assets/signs/)', () async {
      final manifest = {
        for (final path in ['assets/signs/ya.webp', 'assets/signs/README.md', 'assets/fonts/Sora-400.ttf'])
          path: [
            {'asset': path}
          ],
      };
      final library = await SignClipLibrary.fromAssets(_ManifestBundle(manifest));
      expect(library.ids, {'ya'});
      expect((await SignClipLibrary.fromAssets(_ManifestBundle(null))).isEmpty, isTrue, reason: 'no list');
    });
  });

  test('without clips nothing plays, but the words are still translated', () async {
    final signer = fakeSigner(image, {});
    await pumpEventQueue();
    signer.show('Terima kasih');
    expect(signer.hasClips, isFalse);
    expect(signer.steps.single.label, 'TERIMA KASIH');
    expect(signer.signing, isFalse);
  });

  test('signs a sentence, knowing which word is being signed', () async {
    final signer = fakeSigner(image, {'terima_kasih', 'letter_z', 'letter_a', 'letter_d'});
    await pumpEventQueue();
    signer.show('Terima kasih Zad');
    await pumpEventQueue();
    expect([signer.signing, signer.currentStep], [true, 0]);
    for (var i = 0; i < 3; i++) {
      await after(const Duration(milliseconds: 40), signer.player.advance);
    }
    expect(signer.currentStep, 1, reason: 'now spelling Zad');
    for (var i = 0; i < 9; i++) {
      await after(const Duration(milliseconds: 40), signer.player.advance);
    }
    expect([signer.signing, signer.currentStep], [false, null]);
  });

  test('knows which words are really signed, and whether there is anything to sign again', () async {
    final signer = fakeSigner(image, {'terima_kasih'});
    await pumpEventQueue();
    signer.show('Terima kasih Zad');
    expect([signer.isSigned(0), signer.isSigned(1), signer.canReplay], [true, false, true]);
    signer.show('Zad');
    expect([signer.isSigned(0), signer.canReplay], [false, false]);
  });

  test('the same words again do not restart it; signAgain and replay do', () async {
    final signer = fakeSigner(image, {'ya'});
    await pumpEventQueue();
    signer.show('Ya');
    await pumpEventQueue();
    for (var i = 0; i < 3; i++) {
      await after(const Duration(milliseconds: 40), signer.player.advance);
    }
    expect(signer.signing, isFalse);
    signer.show('Ya');
    await pumpEventQueue();
    expect(signer.signing, isFalse, reason: 'the same sentence does not start again by itself');
    await signer.signAgain('Ya');
    expect(signer.signing, isTrue);
  });

  test('words that arrive before the clip list is read are signed once it is', () async {
    final signer = fakeSigner(image, {'ya'});
    signer.show('Ya');
    expect(signer.signing, isFalse);
    await pumpEventQueue();
    expect(signer.signing, isTrue);
  });

  test('with a rest clip the avatar stands ready before anything is said; slower signing', () async {
    final signer = fakeSigner(image, {SignClipLibrary.rest});
    await pumpEventQueue();
    expect(signer.player.frame, isNotNull, reason: 'standing still');
    expect(signer.signing, isFalse, reason: 'standing is not signing');

    signer.toggleSlow();
    expect([signer.slow, signer.player.speed], [true, 0.5]);
    signer.toggleSlow();
    expect(signer.slow, isFalse);
  });
}

/// An asset bundle whose asset list is [manifest] (null = no list at all).
class _ManifestBundle extends CachingAssetBundle {
  _ManifestBundle(this.manifest);

  final Map<String, List<Map<String, String>>>? manifest;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin' && manifest != null) return const StandardMessageCodec().encodeMessage(manifest)!;
    throw FlutterError('Unable to load asset: $key');
  }
}
