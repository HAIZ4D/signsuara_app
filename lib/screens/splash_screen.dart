import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../ui/widgets/brand.dart';
import '../ui/widgets/logo_mark.dart';

/// Animated logo reveal (design: screens1.jsx SplashScreen). Calls [onDone] when finished.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 1700);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // One frame moves the reveal on by at most this much. A slow start (a debug build can take
  // seconds per frame) then plays the whole animation instead of skipping to the end unseen.
  static const _maxStep = Duration(milliseconds: 100);
  // Less motion: the finished logo is shown this long, without the reveal and rings.
  static const _reducedHold = Duration(milliseconds: 600);

  late final _clock = createTicker(_tick);
  late final _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  var _shown = Duration.zero; // how long the splash has really been on screen
  var _lastTick = Duration.zero;
  var _reduced = false;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = AppMotion.reduced(context);
    if (!_reduced) _rings.repeat();
    _clock.start();
  }

  void _tick(Duration elapsed) {
    final step = elapsed - _lastTick;
    _lastTick = elapsed;
    setState(() => _shown += step > _maxStep ? _maxStep : step);
    if (_shown >= (_reduced ? _reducedHold : SplashScreen.duration)) {
      _clock.stop();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _rings.dispose();
    super.dispose();
  }

  /// 0 → 1 through the reveal.
  double get _progress => _reduced ? 1 : (_shown.inMicroseconds / SplashScreen.duration.inMicroseconds).clamp(0.0, 1.0);

  double _phase(double from, double to) => ((_progress - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Semantics(
          label: 'SignSuara. Your voice, in every gesture.',
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.deep),
            // Fill the screen: on its own the Stack is only as big as the rings.
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _rings,
                builder: (context, _) {
                  final logo = Curves.easeOutBack.transform(_phase(0, 0.45));
                  final word = AppMotion.outCurve.transform(_phase(0.35, 0.7));
                  final tag = AppMotion.outCurve.transform(_phase(0.5, 0.85));
                  final flag = AppMotion.outCurve.transform(_phase(0.6, 0.95));
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final (i, color) in [AppColors.turqBright, AppColors.yellow, AppColors.turqBright].indexed)
                        _Ring(t: (_rings.value + i * 0.2) % 1, color: color),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: logo.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.9 + 0.1 * logo,
                              child: LogoMark(size: 104, progress: _progress),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _FadeUp(
                            t: word,
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(text: 'Sign'),
                                  TextSpan(text: 'Suara', style: TextStyle(color: AppColors.yellow)),
                                ],
                              ),
                              style: AppText.heroTitle.copyWith(fontSize: 38),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FadeUp(
                            t: tag,
                            child: Text(
                              'Your voice, in every gesture',
                              style: AppText.body.copyWith(color: AppColors.onDarkSoft, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 54 + MediaQuery.paddingOf(context).bottom,
                        child: _FadeUp(t: flag, child: const FlagStrip()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child));
}

/// One expanding, fading ring behind the logo (design: .splash-rings).
class _Ring extends StatelessWidget {
  const _Ring({required this.t, required this.color});

  final double t; // 0..1 through one pulse
  final Color color;

  @override
  Widget build(BuildContext context) {
    final opacity = t < 0.4 ? t / 0.4 * 0.8 : (1 - t) / 0.6 * 0.8;
    return IgnorePointer(
      child: Transform.scale(
        scale: 0.4 + 0.85 * t,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35 * opacity), width: 1.5),
          ),
        ),
      ),
    );
  }
}
