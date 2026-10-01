import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ui/widgets/baked_gradients.dart';

void main() {
  const turq = Color(0xFF00A4B4);
  final key = GlobalKey();

  /// Shows [layers] in a [width] × 60 box and returns its pixels (RGBA, one per logical pixel).
  Future<ByteData> shot(WidgetTester tester, double width, List<Gradient> layers, {BorderRadius? radius}) async {
    await tester.pumpWidget(Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: width,
          height: 60,
          child: BakedGradients(layers: layers, borderRadius: radius ?? BorderRadius.zero),
        ),
      ),
    ));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final pixels = await image.toByteData();
      image.dispose();
      return pixels;
    }))!;
  }

  Color pixel(ByteData pixels, double width, int x, int y) {
    final i = (y * width.toInt() + x) * 4;
    return Color.fromARGB(pixels.getUint8(i + 3), pixels.getUint8(i), pixels.getUint8(i + 1), pixels.getUint8(i + 2));
  }

  testWidgets('paints its colours inside the round corners', (tester) async {
    final pixels = await shot(tester, 100, const [LinearGradient(colors: [turq, turq])],
        radius: const BorderRadius.all(Radius.circular(20)));
    expect(pixel(pixels, 100, 50, 30), turq);
    expect(pixel(pixels, 100, 1, 1).a, 0, reason: 'outside the round corner');
  });

  testWidgets('a new size gets a new picture, not the old one stretched', (tester) async {
    // A turquoise circle as wide as the box is high (radius 30 around the middle).
    const circle = RadialGradient(colors: [turq, turq, Color(0x0000A4B4)], stops: [0, 0.98, 1]);
    await shot(tester, 100, const [circle]);
    final pixels = await shot(tester, 160, const [circle]);
    expect(pixel(pixels, 160, 100, 30), turq, reason: '20 px from the middle: inside');
    expect(pixel(pixels, 160, 120, 30).a, 0, reason: '40 px from the middle: outside (stretched it would be inside)');
  });
}
