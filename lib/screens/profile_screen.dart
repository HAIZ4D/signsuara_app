import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../custom/custom_gestures_page.dart';
import '../custom/gesture_backup.dart';
import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/brand.dart';
import '../ui/widgets/glove_card.dart';
import '../ui/widgets/google_button.dart';
import '../ui/widgets/logo_mark.dart';
import '../ui/widgets/notice.dart';
import '../ui/widgets/user_avatar.dart';
import 'history_screen.dart';

/// Profile & settings (design: screens3.jsx ProfileScreen). Only real settings and numbers:
/// glove, speech language and voice, conversation history, gesture backup, account, about.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: AppColors.bg),
      body: ListenableBuilder(
        listenable: services.changes,
        builder: (context, _) {
          final account = services.account;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.xxl),
            children: [
              _Header(services: services),
              _Stats(services: services),
              _Group(rows: [
                _gloveRow(),
                _languageRow(),
                _voiceRow(),
              ]),
              _Group(rows: [
                _historyRow(context),
                _backupRow(),
              ]),
              _Group(rows: [_accountRow()]),
              if (account.error case final error?) Notice(message: error),
              if (!account.signedIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GoogleButtonCard(onTap: account.signIn, busy: account.busy),
                ),
              _Group(rows: [
                _Row(
                  icon: Icons.info_outline_rounded,
                  title: 'About SignSuara',
                  subtitle: 'Final Year Project · FCSIT, Universiti Putra Malaysia',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                  onTap: () => _about(context),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  _Row _gloveRow() {
    final session = services.session;
    final connected = session.link == GloveLink.connected;
    return _Row(
      icon: Icons.bluetooth_rounded,
      title: 'SignSuara Glove',
      subtitle: connected
          ? (session.motionSensorOk ? 'Connected' : 'Connected · motion sensor disconnected')
          : session.status,
      warning: connected && !session.motionSensorOk,
      trailing: GloveActionButton(link: session.link, ble: services.ble, onLight: true),
    );
  }

  _Row _languageRow() {
    final language = services.speaker.language;
    return _Row(
      icon: Icons.translate_rounded,
      title: 'Speech language',
      subtitle: 'Spoken in ${language.displayName}. The screen shows both.',
      trailing: _LanguageToggle(value: language, onChanged: services.setLanguage),
    );
  }

  _Row _voiceRow() {
    final problem = services.speaker.problem;
    return _Row(
      icon: Icons.record_voice_over_rounded,
      title: 'Speech voice',
      subtitle: problem ?? 'Ready. Tap play to hear it.',
      warning: problem != null,
      trailing: IconButton(
        tooltip: 'Test the voice',
        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.turq, size: 30),
        onPressed: () => services.speaker.say('TerimaKasih'),
      ),
    );
  }

  _Row _historyRow(BuildContext context) {
    final history = services.history;
    final n = history.recent.length;
    final count = n >= 50 ? '50+' : '$n';
    return _Row(
      icon: Icons.history_rounded,
      title: 'Conversation history',
      subtitle: history.kept ? '$count saved to your Google account' : '$count kept until the app closes (guest)',
      trailing: n == 0
          ? null
          : TextButton(onPressed: () => _clearHistory(context), child: const Text('Clear all')),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistoryScreen(services: services))),
    );
  }

  _Row _backupRow() {
    final backup = services.backup;
    final (icon, _) = backupLook(backup.state);
    final checked = backup.checkedAt;
    return _Row(
      icon: icon,
      title: 'Gesture backup',
      subtitle: checked == null ? backup.summary : '${backup.summary} Checked ${clockTime(checked)}.',
      warning: backup.state == BackupState.failed,
      trailing: backup.state == BackupState.off
          ? null
          : IconButton(
              tooltip: 'Check the backup now',
              icon: const Icon(Icons.sync_rounded, color: AppColors.turq),
              onPressed: backup.state == BackupState.checking ? null : backup.syncNow,
            ),
    );
  }

  _Row _accountRow() {
    final account = services.account;
    final user = account.user;
    return user == null
        ? const _Row(
            icon: Icons.account_circle_outlined,
            title: 'Not signed in',
            subtitle: 'Sign in to keep your conversations and back up your custom signs.',
          )
        : _Row(
            icon: Icons.account_circle_rounded,
            title: 'Google account',
            subtitle: user.email,
            trailing: TextButton(onPressed: account.signOut, child: const Text('Sign out')),
          );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete all conversations?'),
        content: Text(services.history.kept
            ? 'They are removed from your Google account. This cannot be undone.'
            : 'They are removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (sure == true) await services.history.deleteAll();
  }

  void _about(BuildContext context) => showAboutDialog(
        context: context,
        applicationName: 'SignSuara',
        applicationIcon: const LogoMark(size: 48),
        applicationLegalese: 'A smart glove that turns Bahasa Isyarat Malaysia (BIM) signs into speech, '
            'and speech into text.\n\nFinal Year Project, Faculty of Computer Science and Information '
            'Technology, Universiti Putra Malaysia.',
      );
}

/// Photo or initial, name, email (design: .prof-hero).
class _Header extends StatelessWidget {
  const _Header({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final account = services.account;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpace.s, 0, AppSpace.l),
      child: Column(
        children: [
          UserAvatar(name: account.name, photoUrl: account.user?.photoUrl, size: 84),
          const SizedBox(height: 14),
          Text(account.name, textAlign: TextAlign.center, style: AppText.section.copyWith(fontSize: 23)),
          const SizedBox(height: AppSpace.xxs),
          Text(account.user?.email ?? 'Guest · not signed in',
              textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 13)),
          const SizedBox(height: 14),
          const FlagStrip(width: 26),
        ],
      ),
    );
  }
}

/// Three real numbers (design: .prof-stats).
class _Stats extends StatelessWidget {
  const _Stats({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final n = services.history.recent.length;
    final builtIn = kLabels.where((l) => l != GestureClassifier.restLabel).length;
    final stats = [
      (n >= 50 ? '50+' : '$n', 'Conversations'),
      ('${services.gestures.all.length}', 'Custom signs'),
      ('$builtIn', 'Built-in signs'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, (value, label)) in stats.indexed) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
              Expanded(
                child: Semantics(
                  container: true, // read as three separate numbers
                  label: '$value $label',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                    child: Column(
                      children: [
                        Text(value, style: AppText.section.copyWith(fontSize: 22)),
                        Text(label, style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A white card of rows with lines between them (design: .settings-group).
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.line),
                row,
              ],
            ],
          ),
        ),
      );
}

/// Icon tile, title, one line of real state, and an action on the right (design: .set-row).
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, size: 20, color: warning ? AppColors.warning : AppColors.turq),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 14.5)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: AppText.small.copyWith(
                            color: warning ? AppColors.warning : AppColors.inkFaint,
                            fontSize: 12.5,
                            fontWeight: warning ? FontWeight.w700 : null)),
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[const SizedBox(width: AppSpace.s), trailing],
            ],
          ),
        ),
      );
}

/// BM | EN switch for the speech language.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.value, required this.onChanged});

  final SpeechLanguage value;
  final ValueChanged<SpeechLanguage> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in SpeechLanguage.values)
              Semantics(
                button: true,
                selected: language == value,
                label: language.displayName,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(language),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: language == value ? AppGradients.turq : null,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(language.short,
                        style: AppText.label.copyWith(
                            color: language == value ? AppColors.onDark : AppColors.inkSoft,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// The Google button on the light Profile page (a thin border so the white button shows).
class GoogleButtonCard extends StatelessWidget {
  const GoogleButtonCard({super.key, required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.card,
        ),
        child: GoogleButton(onTap: onTap, busy: busy),
      );
}
