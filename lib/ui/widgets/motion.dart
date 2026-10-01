import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Soft drifting colour blobs behind the dark hero panels (design: .hx-aurora).
class Aurora extends StatefulWidget {
  const Aurora({super.key});

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          final drift = Offset(-30 * t, 24 * t);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(top: -90, right: -60, child: Transform.translate(offset: drift, child: _blob(260, AppColors.turq, 0.55))),
              Positioned(bottom: -70, left: -40, child: Transform.translate(offset: -drift, child: _blob(190, AppColors.yellow, 0.3))),
              Positioned(
                top: 60,
                left: 150,
                child: Transform.scale(scale: 1 + 0.15 * t, child: _blob(150, AppColors.royal, 0.4)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A few stars twinkling on the dark header in the evening (Home): fixed places, each with its own
/// rhythm. Still when motion is reduced.
class NightSky extends StatefulWidget {
  const NightSky({super.key});

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  // Where each star is (shares of the panel, upper part), its size and when it twinkles.
  late final _stars = [
    for (var i = 0; i < 14; i++)
      (x: Random(i * 31 + 7).nextDouble(), y: Random(i * 17 + 3).nextDouble() * 0.7, size: 1.1 + (i % 4) * 0.45, phase: i / 14),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _StarsPainter(_stars, _c))));
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.stars, this.time) : super(repaint: time);

  final List<({double x, double y, double size, double phase})> stars;
  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle = (sin(2 * pi * (time.value * 2 + star.phase)) + 1) / 2; // two twinkles a cycle
      final paint = Paint()..color = AppColors.onDark.withValues(alpha: 0.12 + 0.6 * twinkle * twinkle);
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false; // repaints with its animation
}

/// A band of light that sweeps across a card every few seconds (design: hxShine).
class ShineSweep extends StatefulWidget {
  const ShineSweep({super.key, this.strength = 0.28});

  final double strength;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Idle for the first 60 % of the cycle, then sweep left → right.
          final u = ((_c.value - 0.6) / 0.4).clamp(0.0, 1.0);
          return FractionalTranslation(
            translation: Offset(-1 + 2 * u, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1, -0.3),
                  end: const Alignment(1, 0.3),
                  colors: [
                    AppColors.onDark.withValues(alpha: 0),
                    AppColors.onDark.withValues(alpha: widget.strength),
                    AppColors.onDark.withValues(alpha: 0),
                  ],
                  stops: const [0.3, 0.48, 0.62],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

/// Fades and slides a child up when it first appears; [delay] staggers lists (design: .stagger).
class FadeUp extends StatefulWidget {
  const FadeUp({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.slow + widget.delay);
  late final _a = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.delay.inMilliseconds / _c.duration!.inMilliseconds, 1, curve: AppMotion.outCurve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, 14 * (1 - _a.value)), child: child),
        ),
        child: widget.child,
      );
}

/// A dot with a ring that pings outwards (design: `ping` animation on live dots).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 7, this.active = true});

  final Color color;
  final double size;
  final bool active;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() => widget.active && !AppMotion.reduced(context) ? _c.repeat() : _c.reset();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Opacity(
              opacity: (1 - _c.value) * 0.6,
              child: Transform.scale(scale: 1 + _c.value * 1.4, child: child),
            ),
            child: dot,
          ),
          dot,
        ],
      ),
    );
  }
}

/// Three dots that "flow" from one side to the other (design: .cv-link).
class FlowDots extends StatefulWidget {
  const FlowDots({super.key, required this.color, this.reverse = false});

  final Color color;
  final bool reverse;

  @override
  State<FlowDots> createState() => _FlowDotsState();
}

class _FlowDotsState extends State<FlowDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Builder(builder: (context) {
                final k = widget.reverse ? 2 - i : i;
                final wave = (sin((_c.value - k * 0.125) * 2 * pi) + 1) / 2; // 0..1
                return Opacity(
                  opacity: 0.25 + 0.75 * wave,
                  child: Transform.scale(
                    scale: 0.8 + 0.35 * wave,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      );
}

/// Slowly turns its child forever (design: hmSpin / conic borders). Still when motion is reduced.
class Spin extends StatefulWidget {
  const Spin({super.key, required this.child, this.period = const Duration(seconds: 6), this.active = true});

  final Widget child;
  final Duration period;
  final bool active;

  @override
  State<Spin> createState() => _SpinState();
}

class _SpinState extends State<Spin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Spin old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() => widget.active && !AppMotion.reduced(context) ? _c.repeat() : _c.stop();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}

/// Decorative animated bars (design: Waveform). Not a real audio level.
class Waveform extends StatefulWidget {
  const Waveform({super.key, required this.color, this.bars = 26, this.height = 64, this.active = true});

  final Color color;
  final int bars;
  final double height;
  final bool active;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));
  late final _phases = List.generate(widget.bars, (i) => Random(i * 7 + 3).nextDouble() * 2 * pi);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _WavePainter(_c.value * 1200, _phases, widget.color, widget.active),
          ),
        ),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.phases, this.color, this.active);

  final double t;
  final List<double> phases;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final bw = size.width / phases.length;
    for (var i = 0; i < phases.length; i++) {
      final energy = active ? 0.35 + 0.65 * (sin(t * 0.06 + phases[i]) * sin(t * 0.013 + i)).abs() : 0.12;
      final h = energy * size.height;
      final paint = Paint()..color = color.withValues(alpha: color.a * (active ? 0.55 + energy * 0.45 : 0.3));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * bw + bw * 0.22, (size.height - h) / 2, bw * 0.56, h),
          Radius.circular(bw * 0.28),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.active != active || old.color != color;
}
