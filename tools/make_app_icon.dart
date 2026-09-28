// Draws the Android launcher icon from the app's own LogoMark, so icon and logo never differ.
// Run again after changing the logo:   flutter test tools/make_app_icon.dart
//
// Writes into android/app/src/main/res/:
//   mipmap-*/ic_launcher.png             the whole logo (blue tile), for Android 7 (API 24-25)
//   mipmap-*/ic_launcher_foreground.png  arcs and dots only, for the adaptive icon (Android 8+,
//                                        also shown on the Android 12+ start screen)
// The adaptive icon itself is mipmap-anydpi-v26/ic_launcher.xml (background colour in colors.xml).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ui/widgets/logo_mark.dart';

const _res = 'android/app/src/main/res';

// Pixels per dp for each Android density folder.
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

Future<void> _writePng(String path, int pixels, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('make the SignSuara launcher icons', () async {
    for (final MapEntry(key: folder, value: scale) in _densities.entries) {
      // Classic icon: 48 dp, the logo with its tile.
      final legacy = (48 * scale).round();
      await _writePng('$_res/mipmap-$folder/ic_launcher.png', legacy, (canvas) {
        LogoPainter().paint(canvas, Size.square(legacy.toDouble()));
      });

      // Adaptive foreground: a 108 dp layer, the launcher shows the middle 72 dp through its mask.
      // The logo's 60-unit tile is mapped onto those 72 dp, so the arcs look like the in-app logo
      // and stay inside the 66 dp safe circle.
      final layer = (108 * scale).round();
      await _writePng('$_res/mipmap-$folder/ic_launcher_foreground.png', layer, (canvas) {
        final unit = 72 * scale / 60; // pixels per logo unit
        canvas.translate(layer / 2 - 32 * unit, layer / 2 - 32 * unit);
        LogoPainter(tile: false).paint(canvas, Size.square(64 * unit));
      });
    }
  });
}
