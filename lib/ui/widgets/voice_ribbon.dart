import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// SignSuara's voice line on Home (README "Home"): three glowing waves in the Deaf Flag colours that
/// fade out at both ends. They follow the glove: calm while it is off ([energy] low), livelier while
/// it is connected, and a burst each time a sign is spoken ([burst] changes). Decorative: the glove
/// card says the same in words. Still when the phone asks for less motion.
class VoiceRibbon extends StatefulWidget {
  const VoiceRibbon({super.key, required this.energy, this.burst, this.height = 64});

  final double energy; // 0 … 1
  final Object? burst; // a new value = a sign was just spoken
  final double height;

  @override
  State<VoiceRibbon> createState() => _VoiceRibbonState();
}

class _VoiceRibbonState extends State<VoiceRibbon> with TickerProviderStateMixin {
  late final _flow = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final _energy = AnimationController(vsync: this, value: widget.energy, duration: AppMotion.slow);
  late final _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _flow.stop() : _flow.repeat();
  }

  @override
  void didUpdateWidget(VoiceRibbon old) {
    super.didUpdateWidget(old);
    final reduced = AppMotion.reduced(context);
    if (widget.energy != old.energy) {
      reduced ? _energy.value = widget.energy : _energy.animateTo(widget.energy, curve: AppMotion.outCurve);
    }
    if (widget.burst != old.burst && widget.burst != null && !reduced) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _flow.dispose();
    _energy.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(painter: _RibbonPainter(_flow, _energy, _burst)),
          ),
        ),
      );
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.flow, this.energy, this.burst) : super(repaint: Listenable.merge([flow, energy, burst]));

  final Animation<double> flow;
  final Animation<double> energy;
  final Animation<double> burst;

  // Each wave: colour, how fast and which way it travels, how many crests, its height, its shift.
  static const _waves = [
    (color: AppColors.turqBright, speed: 1.0, crests: 1.7, height: 1.0, shift: 0.0, width: 3.0),
    (color: AppColors.yellow, speed: -0.6, crests: 2.4, height: 0.72, shift: 1.9, width: 2.4),
    (color: AppColors.onDark, speed: 0.45, crests: 1.2, height: 0.55, shift: 4.1, width: 1.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = flow.value * 2 * pi;
    // A spoken sign: a quick rise, then a slow settle.
    final b = burst.value;
    final surge =
        b == 0 ? 0.0 : (b < 0.18 ? b / 0.18 : 1 - Curves.easeOut.transform(((b - 0.18) / 0.82).clamp(0.0, 1.0)));
    final amplitude = size.height / 2 * min(0.95, 0.3 + 0.45 * energy.value + 0.4 * surge);
    final middle = size.height / 2;
    for (final wave in _waves) {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 3) {
        final u = x / size.width;
        final taper = pow(sin(pi * u), 1.4).toDouble(); // the wave fades into both edges
        final y = middle +
            amplitude * wave.height * taper * sin(2 * pi * wave.crests * u + t * wave.speed * 2 + wave.shift);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      // Faded at both ends; [strength] = how opaque in the middle.
      Shader fade(double strength) {
        final c = wave.color.withValues(alpha: strength);
        return LinearGradient(
          colors: [c.withValues(alpha: 0), c, c, c.withValues(alpha: 0)],
          stops: const [0, 0.2, 0.8, 1],
        ).createShader(Offset.zero & size);
      }

      // A soft glow under a fine line.
      canvas.drawPath(
        path,
        Paint()
          ..shader = fade(0.38 + 0.3 * surge)
          ..style = PaintingStyle.stroke
          ..strokeWidth = wave.width * 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = fade(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = wave.width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false; // repaints with its animations
}
