import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Soft colour layers ([layers], painted in this order, inside [borderRadius]) drawn once into a
/// picture that every frame then only copies. Big gradients are slow on simple graphics chips: the
/// three on the Listen stage took a Galaxy A13 about 10 ms of each 16.7 ms frame, while copying a
/// picture costs a small part of that (README "Smoothness"). The picture is only made again when
/// the size changes. Fills its parent, so give it a bounded size (e.g. inside Positioned.fill).
class BakedGradients extends LeafRenderObjectWidget {
  const BakedGradients({super.key, required this.layers, this.borderRadius = BorderRadius.zero});

  final List<Gradient> layers;
  final BorderRadius borderRadius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBakedGradients(layers, borderRadius, MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderBakedGradients).update(layers, borderRadius, MediaQuery.devicePixelRatioOf(context));
}

class _RenderBakedGradients extends RenderBox {
  _RenderBakedGradients(this._layers, this._radius, this._ratio);

  List<Gradient> _layers;
  BorderRadius _radius;
  double _ratio; // physical pixels per logical pixel: the picture is made at the screen's own sharpness
  ui.Image? _picture;
  Size _pictureSize = Size.zero;

  void update(List<Gradient> layers, BorderRadius radius, double ratio) {
    if (listEquals(layers, _layers) && radius == _radius && ratio == _ratio) return;
    _layers = layers;
    _radius = radius;
    _ratio = ratio;
    _forget();
    markNeedsPaint();
  }

  void _forget() {
    _picture?.dispose(); // frames already drawn keep their own reference
    _picture = null;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    if (size != _pictureSize) _forget();
    final picture = _picture ??= _bake();
    _pictureSize = size;
    context.canvas.drawImageRect(
      picture,
      Rect.fromLTWH(0, 0, size.width * _ratio, size.height * _ratio), // one picture pixel per screen pixel
      offset & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  ui.Image _bake() {
    final area = Offset.zero & size;
    final shape = _radius.toRRect(area);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_ratio);
    for (final layer in _layers) {
      canvas.drawRRect(shape, Paint()..shader = layer.createShader(area));
    }
    final drawing = recorder.endRecording();
    try {
      return drawing.toImageSync((size.width * _ratio).ceil(), (size.height * _ratio).ceil());
    } finally {
      drawing.dispose();
    }
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }
}
