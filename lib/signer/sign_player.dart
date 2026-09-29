import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The frames of one sign clip, decoded one after another.
abstract class ClipReader {
  int get frameCount;

  /// The next picture and how long it stays on screen.
  Future<(ui.Image, Duration)> nextFrame();

  void dispose();
}

/// Finds the clip of a sign; null when that sign has no clip yet (it is then skipped).
typedef ClipOpener = Future<ClipReader?> Function(String signId);

/// Clips bundled with the app: `assets/signs/<id>.webp`, animated WebP with a transparent
/// background (README "Signer").
Future<ClipReader?> openAssetClip(String signId, {AssetBundle? bundle}) async {
  final ByteData data;
  try {
    data = await (bundle ?? rootBundle).load('assets/signs/$signId.webp');
  } catch (_) {
    return null; // no clip for this sign yet
  }
  return CodecClipReader(await ui.instantiateImageCodec(data.buffer.asUint8List()));
}

/// Reads a clip with Flutter's own image decoder (no package needed).
class CodecClipReader implements ClipReader {
  CodecClipReader(this._codec);

  final ui.Codec _codec;

  @override
  int get frameCount => _codec.frameCount;

  @override
  Future<(ui.Image, Duration)> nextFrame() async {
    final frame = await _codec.getNextFrame();
    return (frame.image, frame.duration);
  }

  @override
  void dispose() => _codec.dispose();
}

/// Plays sign clips one after another. Every clip starts and ends in the avatar's rest pose, so
/// the joins don't jump. It has no clock of its own: [advance] moves it on (the view calls it
/// every screen frame; tests call it directly).
class SignPlayer extends ChangeNotifier {
  SignPlayer({ClipOpener open = openAssetClip}) : _open = open;

  final ClipOpener _open;

  /// A picture without a time (a one-frame clip, e.g. a held handshape) stays this long.
  static const stillHold = Duration(milliseconds: 400);
  static const _fallbackFrame = Duration(milliseconds: 42); // 24 fps

  List<String> _signs = const [];
  var _index = -1; // the sign now showing; -1 = nothing played yet
  final _missing = <String>[];
  var _speed = 1.0;
  var _run = 0; // a new play() makes older, still-running loading work stale

  ClipReader? _reader;
  var _shown = 0; // frames of this clip shown so far
  (ui.Image, Duration)? _next; // the next frame, decoded ahead
  ui.Image? _frame;
  var _clock = Duration.zero;
  var _due = Duration.zero; // when the frame on screen has had its time

  /// The picture to show now (the last one stays after the end: the rest pose).
  ui.Image? get frame => _frame;

  /// Which of the signs is playing, `signs.length` when finished, -1 before the first.
  int get index => _index;

  List<String> get signs => _signs;

  bool get playing => _index >= 0 && _index < _signs.length;

  /// Signs that were skipped because they have no clip yet.
  List<String> get missing => List.unmodifiable(_missing);

  /// 1 = normal, down to 0.5 = half speed (easier to follow).
  double get speed => _speed;
  set speed(double value) {
    _speed = value.clamp(0.5, 1.0);
    notifyListeners();
  }

  /// Plays [signs] (clip ids) from the start, replacing anything playing.
  Future<void> play(List<String> signs) async {
    _run++;
    _closeClip();
    _signs = List.unmodifiable(signs);
    _missing.clear();
    _index = -1;
    _clock = _due = Duration.zero;
    await _startClip(0, _run);
  }

  Future<void> replay() => play(_signs);

  void stop() {
    _run++;
    _closeClip();
    _index = _signs.length;
    notifyListeners();
  }

  /// Moves the clips on by [step] of real time (slower when [speed] < 1).
  void advance(Duration step) {
    if (!playing || _reader == null) return;
    _clock += step * _speed;
    if (_clock < _due) return;
    final next = _next;
    if (next != null) {
      _show(next);
    } else if (_shown >= _reader!.frameCount) {
      _startClip(_index + 1, _run); // this clip is over
    } else {
      _clock = _due; // the next frame is still decoding: wait for it, don't skip ahead
    }
  }

  Future<void> _startClip(int index, int run) async {
    _closeClip();
    for (var i = index; i < _signs.length; i++) {
      final reader = await _open(_signs[i]);
      if (run != _run) {
        reader?.dispose();
        return;
      }
      if (reader == null || reader.frameCount == 0) {
        reader?.dispose();
        _missing.add(_signs[i]);
        continue;
      }
      _index = i;
      _reader = reader;
      _shown = 0;
      final first = await reader.nextFrame();
      if (run != _run) return;
      _due = _clock;
      _show(first);
      return;
    }
    _index = _signs.length; // all played
    notifyListeners();
  }

  void _show((ui.Image, Duration) frame) {
    final (image, time) = frame;
    final old = _frame;
    _frame = image;
    if (old != null && !identical(old, image)) old.dispose();
    final reader = _reader!;
    _due += time > Duration.zero ? time : (reader.frameCount == 1 ? stillHold : _fallbackFrame);
    _shown++;
    _next = null;
    if (_shown < reader.frameCount) {
      final run = _run;
      reader.nextFrame().then((f) {
        if (run == _run && identical(reader, _reader)) _next = f;
      });
    }
    notifyListeners();
  }

  void _closeClip() {
    _reader?.dispose();
    _reader = null;
    _next = null;
    _shown = 0;
  }

  @override
  void dispose() {
    _run++;
    _closeClip();
    _frame?.dispose();
    super.dispose();
  }
}
