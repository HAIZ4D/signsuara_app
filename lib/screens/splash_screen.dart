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
  late final _intro = AnimationController(vsync: this, duration: SplashScreen.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  late final _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      // Less motion: show the finished logo for ~0.6 s (the last 1 % of a 60 s run), no rings.
      _intro.duration = const Duration(seconds: 60);
      _intro.forward(from: 0.99);
    } else {
      _rings.repeat();
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _rings.dispose();
    super.dispose();
  }

  double _phase(double from, double to) => ((_intro.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Semantics(
          label: 'SignSuara. Your voice, in every gesture.',
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.deep),
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _rings]),
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
                            child: LogoMark(size: 104, progress: _intro.value),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FadeUp(
                          t: word,
                          child: Text.rich(
                            const TextSpan(children: [
                              TextSpan(text: 'Sign'),
                              TextSpan(text: 'Suara', style: TextStyle(color: AppColors.yellow)),
                            ]),
                            style: AppText.heroTitle.copyWith(fontSize: 38),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FadeUp(
                          t: tag,
                          child: Text('Your voice, in every gesture',
                              style: AppText.body.copyWith(color: AppColors.onDarkSoft, letterSpacing: 0.5)),
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
