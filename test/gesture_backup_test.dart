import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/custom_gestures.dart';
import 'package:signsuara_app/custom/custom_gestures_page.dart';
import 'package:signsuara_app/custom/gesture_backup.dart';
import 'package:signsuara_app/custom/gesture_store.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_auth_backend.dart';

CustomGesture _gesture(String id, String malay) => CustomGesture(
      id: id,
      malay: malay,
      english: 'in English',
      moving: false,
      recordings: [
        for (var r = 0; r < 2; r++)
          [
            for (var i = 0; i < CustomGesture.recordingRows; i++)
              [900.0 - r, 850, 700.5, 640, 610, 12, -3.25, 88, 0.1, -0.2, 0.05]
          ]
      ],
    );

void main() {
  late FakeAuthBackend backend;
  late CustomGestures gestures;

  FakeGestureStore cloud() => backend.gestureStores.putIfAbsent(testUser.uid, FakeGestureStore.new);

  GestureBackup started(Account account) => GestureBackup(gestures: gestures, account: account)..start();

  setUp(() {
    backend = FakeAuthBackend();
    gestures = CustomGestures();
  });

  test('the database format gives back exactly the same gesture', () {
    final g = _gesture('7', 'Saya lapar');
    final back = gestureFromBackup('7', gestureToBackup(g))!;
    expect(back.toJson(), g.toJson());
    expect(gestureFromBackup('7', {'malay': 'x'}), isNull, reason: 'damaged: skipped, never a crash');
  });

  test('signing in on a new phone brings the gestures back', () async {
    await cloud().save(_gesture('1', 'Zad'));
    await cloud().save(_gesture('2', 'Saya lapar'));
    backend.currentUser = testUser;
    final backup = started(Account(backend));
    await pumpEventQueue();

    expect([for (final g in gestures.all) g.malay], ['Zad', 'Saya lapar']);
    expect(gestures.all.first.recordings, _gesture('1', 'Zad').recordings);
    expect(backup.restored, 2);
    expect(backup.state, BackupState.done);
    expect(cloud().saved.keys, ['1', '2'], reason: 'nothing uploaded twice');
  });

  test('a guest is not backed up; signing in uploads what is on the phone', () async {
    final account = Account(backend);
    await gestures.add(_gesture('1', 'Zad'));
    final backup = started(account);
    await pumpEventQueue();
    expect(backup.state, BackupState.off);
    expect(backend.gestureStores, isEmpty);

    await account.signIn();
    await pumpEventQueue();
    expect(cloud().saved.keys, ['1']);
    expect(backup.state, BackupState.done);
    expect(backup.restored, 0);
  });

  test('while signed in: new gestures go up, deleted ones come out; signed out: nothing', () async {
    backend.currentUser = testUser;
    final account = Account(backend);
    started(account);
    await pumpEventQueue();

    await gestures.add(_gesture('3', 'Minum'));
    await pumpEventQueue();
    expect(cloud().saved.keys, ['3']);
    await gestures.remove('3');
    await pumpEventQueue();
    expect(cloud().saved, isEmpty);

    await account.signOut();
    await gestures.add(_gesture('4', 'Makan'));
    await pumpEventQueue();
    expect(cloud().saved, isEmpty);
  });

  test('the category is saved on the phone; gestures from before categories are Personal', () {
    final g = _gesture('8', 'Atom').copyWith(category: GestureCategory.science);
    final back = CustomGesture.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(back.category, GestureCategory.science);
    expect(back.recordings, g.recordings);
    final old = g.toJson()..remove('category');
    expect(CustomGesture.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).category, GestureCategory.personal);
  });

  test('a changed category goes up again; an older backup without one reads as Personal', () async {
    backend.currentUser = testUser;
    started(Account(backend));
    await pumpEventQueue();
    await gestures.add(_gesture('5', 'Solat'));
    await pumpEventQueue();
    expect(cloud().saved['5']!['category'], 'personal');

    await gestures.update(gestures.all.single.copyWith(category: GestureCategory.religious));
    await pumpEventQueue();
    expect(cloud().saved['5']!['category'], 'religious', reason: 'uploaded again');
    expect(gestures.all.single.category, GestureCategory.religious);
    expect(gestures.all.single.recordings, _gesture('5', 'Solat').recordings, reason: 'only the category changed');

    final older = gestureToBackup(_gesture('6', 'Lama'))..remove('category');
    expect(gestureFromBackup('6', older)!.category, GestureCategory.personal);
  });

  test('when the backup fails, the gestures stay on the phone and it says so', () async {
    cloud().failing = true;
    backend.currentUser = testUser;
    await gestures.add(_gesture('1', 'Zad'));
    final backup = started(Account(backend));
    await pumpEventQueue();
    expect(backup.state, BackupState.failed);
    expect(gestures.all.single.malay, 'Zad');
  });

  testWidgets('the Gestures tab says whether the gestures are backed up', (tester) async {
    final account = Account(backend);
    final backup = started(account);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: CustomGesturesPage(gestures: gestures, session: GloveSession(), backup: backup)),
    ));
    expect(find.textContaining('Not backed up'), findsOneWidget);

    await tester.runAsync(() async {
      await cloud().save(_gesture('1', 'Zad'));
      await account.signIn();
      await pumpEventQueue();
    });
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Backed up to your Google account. 1 brought back from it.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Zad'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Zad'), findsOneWidget);
  });
}
