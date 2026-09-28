import 'package:flutter/material.dart';

import '../cloud/account.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/google_button.dart';
import '../ui/widgets/notice.dart';
import '../ui/widgets/user_avatar.dart';

/// Profile: who is signed in, sign in / sign out. The settings come in redesign step 9.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: account,
        builder: (context, _) {
          final user = account.user;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xxl),
              child: Column(
                children: [
                  UserAvatar(name: account.name, photoUrl: user?.photoUrl, size: 84),
                  const SizedBox(height: 14),
                  Text(account.name, textAlign: TextAlign.center, style: AppText.section.copyWith(fontSize: 23)),
                  const SizedBox(height: AppSpace.xs),
                  Text(user?.email ?? 'Not signed in: your data stays on this phone.',
                      textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkFaint)),
                  const SizedBox(height: AppSpace.xl),
                  if (account.error case final error?) Notice(message: error),
                  if (user == null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: GoogleButton(onTap: account.signIn, busy: account.busy),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: account.signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  const SizedBox(height: AppSpace.xl),
                  Text('Settings are coming in a later step.',
                      textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.inkFaint)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
