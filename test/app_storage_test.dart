import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/custom_gestures.dart';
import 'package:signsuara_app/speech/sign_words.dart';

CustomGesture _gesture(String id) => CustomGesture(
      id: id,
      malay: 'Saya lapar',
      english: 'I am hungry',
      moving: false,
      recordings: [
        for (var r = 0; r < 2; r++)
          [
            for (var i = 0; i < CustomGesture.recordingRows; i++)
              [500.0 + r, 600, 700, 800, 900, 10, 20, 30, 0.1, 0.2, 0.3]
          ]
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('custom gestures are still there after the app restarts', () async {
    final gestures = CustomGestures()..load(await AppStorage.open());
    await gestures.add(_gesture('1'));
    await gestures.add(_gesture('2'));
    await gestures.remove('1');

    final afterRestart = CustomGestures()..load(await AppStorage.open());
    expect([for (final g in afterRestart.all) g.id], ['2']);
    expect(afterRestart.all.single.recordings, _gesture('2').recordings);
    expect(afterRestart.customWords('custom:2')?.english, 'I am hungry');
    expect(afterRestart.customWords('Saya'), isNull, reason: 'built-in labels are not custom');
  });

  test('the BM/EN choice is remembered', () async {
    final storage = await AppStorage.open();
    expect(storage.loadLanguage(), isNull);
    await storage.saveLanguage(SpeechLanguage.english);
    expect((await AppStorage.open()).loadLanguage(), SpeechLanguage.english);
  });

  test('the welcome pages are remembered as seen', () async {
    expect((await AppStorage.open()).loadOnboardingSeen(), isFalse);
    await (await AppStorage.open()).saveOnboardingSeen();
    expect((await AppStorage.open()).loadOnboardingSeen(), isTrue);
  });

  test('damaged saved data does not crash the app', () async {
    SharedPreferences.setMockInitialValues({'custom_gestures': 'not json'});
    expect((await AppStorage.open()).loadGestures(), isEmpty);
  });
}
