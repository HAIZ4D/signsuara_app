import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Rounded avatar: the Google photo when there is one and it loads, otherwise the first letter.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoUrl, this.size = 48});

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.avatar,
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: AppText.cardTitle.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w800)),
          ),
          // No internet or a broken link: the letter underneath stays visible.
          if (photo != null) Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
        ],
      ),
    );
  }
}
