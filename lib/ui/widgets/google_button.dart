import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// White "Continue with Google" button with the Google "G", as Google's sign-in branding asks.
/// Shows a spinner and is disabled while [busy].
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap, this.busy = false});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: busy ? 'Signing in with Google' : 'Continue with Google',
      excludeSemantics: true,
      child: Material(
        color: AppColors.googleFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.googleBlue),
                      )
                    : const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleG())),
                const SizedBox(width: 12),
                Text(busy ? 'Signing in…' : 'Continue with Google',
                    style: AppText.strong.copyWith(color: AppColors.googleText, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Google "G" (Google's own 48 x 48 path data, four colours).
class _GoogleG extends CustomPainter {
  const _GoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    void fill(Color color, Path path) => canvas.drawPath(path, Paint()..color = color);

    fill(
      AppColors.googleRed,
      Path()
        ..moveTo(24, 9.5)
        ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
        ..lineTo(40.06, 6.25)
        ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
        ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
        ..lineTo(10.54, 19.41)
        ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
        ..close(),
    );
    fill(
      AppColors.googleBlue,
      Path()
        ..moveTo(46.98, 24.55)
        ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
        ..lineTo(24, 20)
        ..lineTo(24, 29.02)
        ..lineTo(36.94, 29.02)
        ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
        ..lineTo(39.89, 42.2)
        ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
        ..close(),
    );
    fill(
      AppColors.googleYellow,
      Path()
        ..moveTo(10.53, 28.59)
        ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
        ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
        ..lineTo(2.55, 13.22)
        ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
        ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
        ..lineTo(10.53, 28.59)
        ..close(),
    );
    fill(
      AppColors.googleGreen,
      Path()
        ..moveTo(24, 48)
        ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
        ..lineTo(32.16, 36.19)
        ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
        ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
        ..lineTo(2.55, 34.77)
        ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
        ..close(),
    );
  }

  @override
  bool shouldRepaint(_GoogleG old) => false;
}
