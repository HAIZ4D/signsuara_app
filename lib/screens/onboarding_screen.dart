import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/motion.dart';

/// Three welcome pages, shown once (design: screens1.jsx OnboardingScreen).
/// The texts only promise what the app really does.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Art { wave, swap, terms }

class _Page {
  const _Page(this.art, this.accent, this.title, this.body);

  final _Art art;
  final Color accent;
  final String title;
  final String body;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _Page(_Art.wave, AppColors.turqBright, 'Speak with your hands',
        'Your smart glove reads every sign and turns it into speech and text, the moment you sign.'),
    _Page(_Art.swap, AppColors.yellow, 'A real two-way talk',
        'Hearing friends reply by voice. SignSuara shows their words to you instantly, big and clear. '
            'No one is left out.'),
    _Page(_Art.terms, AppColors.turqBright, 'Built for your world',
        'Bahasa Melayu and English, plus your own custom signs. '
            'Islamic learning with the Arabic letters and PAFA is coming soon.'),
  ];

  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) return widget.onDone();
    _controller.nextPage(
      duration: AppMotion.reduced(context) ? const Duration(milliseconds: 1) : AppMotion.medium,
      curve: AppMotion.outCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    final sun = _index == 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.deep),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, AppSpace.s, 22, 0),
                    child: TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.glass,
                        foregroundColor: AppColors.onDarkSoft,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text('Skip', style: AppText.label.copyWith(fontSize: 13)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [for (final p in _pages) _PageView(page: p)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 32),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Page ${_index + 1} of ${_pages.length}',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _pages.length; i++) ...[
                              if (i > 0) const SizedBox(width: 7),
                              AnimatedContainer(
                                duration: AppMotion.medium,
                                curve: AppMotion.outCurve,
                                width: i == _index ? 26 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i == _index ? AppColors.turqBright : AppColors.onDark.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: last ? 'Get started' : 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        gradient: sun ? AppGradients.sun : AppGradients.turq,
                        shadow: sun ? AppShadows.sunGlow : AppShadows.turqTile,
                        foreground: sun ? AppColors.onYellow : AppColors.onDark,
                        onTap: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Blob(color: page.accent),
              FadeUp(
                child: SizedBox(
                  width: 250,
                  child: switch (page.art) {
                    _Art.wave => Waveform(color: page.accent, bars: 28, height: 120),
                    _Art.swap => const _SwapArt(),
                    _Art.terms => const _TermsArt(),
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: FadeUp(
            delay: const Duration(milliseconds: 100),
            child: Column(
              children: [
                Text(page.title, textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(fontSize: 28)),
                const SizedBox(height: 12),
                Text(page.body,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.onDarkSoft, fontSize: 16, height: 1.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft coloured blob that slowly breathes behind the page art (design: .onb-blob).
class _Blob extends StatefulWidget {
  const _Blob({required this.color});

  final Color color;

  @override
  State<_Blob> createState() => _BlobState();
}

class _BlobState extends State<_Blob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform.rotate(
            angle: t * 18 * pi / 180,
            child: Transform.scale(scale: 1 + 0.08 * t, child: child),
          );
        },
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [
              widget.color.withValues(alpha: 0.32),
              widget.color.withValues(alpha: 0),
            ]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(110),
              topRight: Radius.circular(130),
              bottomLeft: Radius.circular(140),
              bottomRight: Radius.circular(100),
            ),
          ),
        ),
      );
}

/// A sign bubble and a speaker bubble with arrows between them (design: .onb-swap).
class _SwapArt extends StatelessWidget {
  const _SwapArt();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Floaty(
            delay: 0,
            child: _Bubble(gradient: AppGradients.turq, icon: Icons.waving_hand_rounded, color: AppColors.onDark, size: 32),
          ),
          SizedBox(width: 18),
          Icon(Icons.swap_horiz_rounded, size: 34, color: AppColors.onDark),
          SizedBox(width: 18),
          _Floaty(
            delay: 0.2,
            child: _Bubble(gradient: AppGradients.sun, icon: Icons.volume_up_rounded, color: AppColors.onYellow, size: 28),
          ),
        ],
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.gradient, required this.icon, required this.color, required this.size});

  final Gradient gradient;
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24)),
        child: Icon(icon, color: color, size: size),
      );
}

/// Gently bobs its child up and down (design: floaty).
class _Floaty extends StatefulWidget {
  const _Floaty({required this.child, required this.delay});

  final Widget child;
  final double delay; // 0..1 of the cycle

  @override
  State<_Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<_Floaty> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

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
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -9 * (0.5 - 0.5 * cos((_c.value + widget.delay) * 2 * pi))),
          child: child,
        ),
        child: widget.child,
      );
}

/// Words the app speaks, and one that is coming (design: .onb-terms).
class _TermsArt extends StatelessWidget {
  const _TermsArt();

  static const _terms = ['Terima kasih', 'Saya', 'Nama', 'مرحبا', 'PAFA · soon'];

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (i, t) in _terms.indexed)
            FadeUp(
              delay: Duration(milliseconds: 120 * i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(t,
                    style: AppText.strong.copyWith(color: i.isOdd ? AppColors.yellow : AppColors.onDark, fontSize: 15)),
              ),
            ),
        ],
      );
}
