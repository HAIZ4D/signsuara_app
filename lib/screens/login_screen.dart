import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cloud/account.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/google_button.dart';
import '../ui/widgets/logo_mark.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/notice.dart';

/// After the welcome pages: sign in with Google (optional) or continue as a guest.
/// Shown only while nobody is signed in. Calls [onDone] when the app should open.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.account, required this.onDone});

  final Account account;
  final VoidCallback onDone;

  Future<void> _google() async {
    if (await account.signIn()) onDone();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.deep),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: account,
              builder: (context, _) => LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 40, 26, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 72),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FadeUp(
                          child: Column(
                            children: [
                              const LogoMark(size: 76),
                              const SizedBox(height: 26),
                              Text('Make SignSuara yours',
                                  textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(fontSize: 28)),
                              const SizedBox(height: 12),
                              Text(
                                'Sign in with Google so the app greets you by name, keeps your conversations '
                                'and backs up your custom signs. '
                                'Or continue as a guest: signing, speech and your custom signs work the same.',
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(color: AppColors.onDarkSoft, fontSize: 16, height: 1.55),
                              ),
                              const SizedBox(height: 28),
                              const _Perk(icon: Icons.waving_hand_rounded, text: 'Your Google name and photo in the app'),
                              const _Perk(icon: Icons.cloud_upload_outlined, text: 'Backup of your custom signs'),
                              const _Perk(icon: Icons.history_rounded, text: 'Your conversation history, kept'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeUp(
                          delay: const Duration(milliseconds: 100),
                          child: Column(
                            children: [
                              if (account.error case final error?) Notice(message: error),
                              GoogleButton(onTap: _google, busy: account.busy),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: account.busy ? null : onDone,
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.glass,
                                    foregroundColor: AppColors.onDark,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      side: const BorderSide(color: AppColors.glassBorder),
                                    ),
                                  ),
                                  child: Text('Continue as guest',
                                      style: AppText.strong.copyWith(color: AppColors.onDark, fontSize: 16)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Saved to your account: your name, email, photo, conversations and custom signs.',
                                textAlign: TextAlign.center,
                                style: AppText.small.copyWith(color: AppColors.onDarkFaint),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing an account gives you.
class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, size: 19, color: AppColors.turqBright),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.label.copyWith(color: AppColors.onDark, fontSize: 14))),
        ],
      ),
    );
  }
}
