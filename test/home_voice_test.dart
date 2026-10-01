import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/glove/glove_ble.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/theme/app_theme.dart';
import 'package:signsuara_app/ui/widgets/glove_card.dart';
import 'package:signsuara_app/ui/widgets/voice_ribbon.dart';

void main() {
  testWidgets('the glove card shows the last spoken sign, only while the glove is connected', (tester) async {
    final session = GloveSession();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: session,
          builder: (context, _) => GloveCard(session: session, ble: GloveBle(session), lastSign: 'Terima kasih'),
        ),
      ),
    ));
    expect(find.text('Tap Connect to start'), findsOneWidget);
    expect(find.textContaining('Last sign', findRichText: true), findsNothing, reason: 'not connected');

    session.setStatus('Streaming', link: GloveLink.connected);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Last sign: Terima kasih', findRichText: true), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets('the voice line follows the glove and bursts on a sign (motion ${reduced ? 'reduced' : 'on'})',
        (tester) async {
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      Widget ribbon(double energy, Object? burst) =>
          MaterialApp(home: Scaffold(body: Center(child: VoiceRibbon(energy: energy, burst: burst))));
      await tester.pumpWidget(ribbon(0.2, null));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(ribbon(1.0, 'a sign')); // connected, and a sign was spoken
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(VoiceRibbon), findsOneWidget);
    });
  }
}
