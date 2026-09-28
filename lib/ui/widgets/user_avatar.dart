import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Round avatar: the photo fills the whole circle (cropped to fit, never stretched); the first
/// letter shows while it loads, without internet, or when there is no photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
    this.ring = AppColors.glassBorder,
    this.ringWidth = 1.5,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final Color ring; // thin circle around the photo
  final double ringWidth;

  /// Google profile photos come small (…=s96-c): ask for one big enough for this screen.
  static String sharper(String url, int pixels) =>
      url.contains('googleusercontent.com') ? url.replaceFirst(RegExp(r'=s\d+-c$'), '=s$pixels-c') : url;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.avatar),
      foregroundDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: ringWidth)),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: AppText.cardTitle.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w800)),
            ),
            if (photo != null)
              Image.network(
                sharper(photo, pixels),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
          ],
        ),
      ),
    );
  }
}
