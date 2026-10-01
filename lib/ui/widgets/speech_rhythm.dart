import 'dart:math';

import 'package:flutter/material.dart';

import '../../listen/listen_note.dart';
import '../../theme/app_theme.dart';

/// When things were said in a Listen session (README "Listen and Notes"): the session cut into
/// [bars] equal slices of time, each bar as tall as the words heard in it. Real data, not a sound
/// level. The bars rise once, left to right, when it first shows (not when motion is reduced).
class SpeechRhythm extends StatefulWidget {
  const SpeechRhythm({super.key, required this.note, required this.color, this.bars = 32, this.height = 28});

  final ListenNote note;
  final Color color;
  final int bars;
  final double height;

  /// The words in each slice of time, 0..1 (1 = the busiest slice).
  static List<double> levels(ListenNote note, int bars) {
    final total = max(note.endedAt.difference(note.startedAt).inMilliseconds, 1);
    final words = List<double>.filled(bars, 0);
    for (final line in note.lines) {
      final slice = line.at.difference(note.startedAt).inMilliseconds * bars ~/ total;
      words[min(max(slice, 0), bars - 1)] += line.text.split(' ').where((w) => w.isNotEmpty).length;
    }
    final most = words.reduce(max);
    return [for (final w in words) most == 0 ? 0 : w / most];
  }

  @override
  State<SpeechRhythm> createState() => _SpeechRhythmState();
}

class _SpeechRhythmState extends State<SpeechRhythm> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _rise.value = 1;
    } else if (_rise.value == 0 && !_rise.isAnimating) {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _RhythmPainter(SpeechRhythm.levels(widget.note, widget.bars), widget.color, _rise),
            ),
          ),
        ),
      );
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter(this.levels, this.color, this.rise) : super(repaint: rise);

  final List<double> levels;
  final Color color;
  final Animation<double> rise;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / levels.length;
    final width = max(slot * 0.58, 2.0);
    for (var i = 0; i < levels.length; i++) {
      // A wave from the left: each bar starts a little after the one before.
      final start = 0.4 * i / levels.length;
      final grow = AppMotion.outCurve.transform(((rise.value - start) / 0.6).clamp(0.0, 1.0));
      final level = levels[i];
      final height = (width + (size.height - width) * level) * grow; // a silent slice stays a dot
      final paint = Paint()..color = color.withValues(alpha: color.a * (level == 0 ? 0.3 : 0.55 + 0.45 * level));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(slot * (i + 0.5), size.height / 2), width: width, height: height),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter old) => old.color != color || !_same(old.levels, levels);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
