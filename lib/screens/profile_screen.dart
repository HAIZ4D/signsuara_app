import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Profile & settings. PLACEHOLDER until redesign step 9 (Google login + real settings).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppGradients.deep,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.card,
                ),
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: AppText.heroTitle.copyWith(fontSize: 34, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 14),
              Text(name, style: AppText.section.copyWith(fontSize: 23)),
              const SizedBox(height: AppSpace.s),
              Text('Google sign-in and settings are coming in a later step.',
                  textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
