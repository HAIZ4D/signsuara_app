import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/conversation_tile.dart';
import '../ui/widgets/glove_card.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/note_kind_icon.dart';
import '../ui/widgets/user_avatar.dart';
import 'history_screen.dart';
import 'note_screen.dart';

/// Home dashboard (design: home.jsx). Only real data: no battery, no invented stats.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services, required this.onOpenTab, required this.onOpenProfile});

  final AppServices services;
  final ValueChanged<int> onOpenTab; // tab index in the app shell
  final VoidCallback onOpenProfile;

  static const conversationTab = 1, hearingTab = 2, gesturesTab = 3, notesTab = 4;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: services.changes,
        builder: (context, _) => ListView(
          padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _StartCta.height - 40),
                  child: HeroPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeUp(
                          child: _Greeting(
                              name: services.userName,
                              photoUrl: services.account.user?.photoUrl,
                              onAvatar: onOpenProfile)),
                        const SizedBox(height: AppSpace.xl),
                        FadeUp(
                          delay: const Duration(milliseconds: 100),
                          child: GloveCard(session: services.session, ble: services.ble),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpace.gutter,
                  right: AppSpace.gutter,
                  bottom: 0,
                  child: _StartCta(onTap: () => onOpenTab(conversationTab)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FadeUp(
                      delay: const Duration(milliseconds: 50),
                      child: _Tile(
                        icon: Icons.volume_up_rounded,
                        title: 'Listen',
                        subtitle: 'See what they say',
                        gradient: AppGradients.sun,
                        shadow: AppShadows.sunGlow,
                        iconColor: AppColors.onYellow,
                        onTap: () => onOpenTab(hearingTab),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FadeUp(
                      delay: const Duration(milliseconds: 120),
                      child: _Tile(
                        icon: Icons.waving_hand_rounded,
                        title: 'My signs',
                        subtitle: '${services.gestures.all.length} custom',
                        gradient: AppGradients.turq,
                        shadow: AppShadows.turqTile,
                        onTap: () => onOpenTab(gesturesTab),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FadeUp(
                      delay: const Duration(milliseconds: 190),
                      child: _Tile(
                        icon: Icons.sticky_note_2_rounded,
                        title: 'Notes',
                        subtitle: switch (services.notes.all.length) {
                          0 => 'No notes yet',
                          1 => '1 note',
                          final n => '$n notes',
                        },
                        gradient: AppGradients.blueTile,
                        shadow: AppShadows.blueTile,
                        onTap: () => onOpenTab(notesTab),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 14, AppSpace.gutter, 0),
              child: _LatestNote(
                note: services.notes.all.firstOrNull,
                onOpen: (note) => openNote(context, services, note),
                onListen: () => onOpenTab(hearingTab),
              ),
            ),
            SectionHeader(
              title: 'Recent conversations',
              action: services.history.recent.isEmpty ? null : 'See all',
              onAction: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => HistoryScreen(services: services))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: _Recent(services: services),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.photoUrl, required this.onAvatar});

  final String name;
  final String? photoUrl;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = longDate(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: AppText.label.copyWith(color: AppColors.onDarkSoft)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${timeGreeting(now)},\n'),
                  TextSpan(text: name, style: const TextStyle(color: AppColors.yellow)),
                ]),
                style: AppText.heroTitle,
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Profile',
          excludeSemantics: true, // just "Profile", not the letter inside the avatar
          child: InkWell(
            onTap: onAvatar,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(name: name, photoUrl: photoUrl),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blue, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Big turquoise "Start a conversation" card overlapping the hero (design: .hx-cta).
class _StartCta extends StatelessWidget {
  const _StartCta({required this.onTap});

  static const height = 88.0;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 200),
      child: Semantics(
        button: true,
        label: 'Start a conversation',
        excludeSemantics: true,
        child: Container(
          height: height,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: AppShadows.turqGlow),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: const BoxDecoration(gradient: AppGradients.cta),
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -8,
                        width: 190,
                        child: Opacity(
                          opacity: 0.45,
                          child: Waveform(color: AppColors.onDark.withValues(alpha: 0.55), height: 64),
                        ),
                      ),
                      const Positioned.fill(child: ShineSweep()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.onDark.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.onDark.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.onDark, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start a conversation',
                                      style: AppText.label.copyWith(color: AppColors.onDark.withValues(alpha: 0.85))),
                                  const SizedBox(height: 2),
                                  Text('Sign it, and be heard', style: AppText.cardTitle),
                                ],
                              ),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded, color: AppColors.turqDeep, size: 20),
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
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.shadow,
    required this.onTap,
    this.iconColor = AppColors.onDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final List<BoxShadow> shadow;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.m, 14, AppSpace.m, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: shadow,
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(height: 10),
                  Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 14)),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The newest note (design: the .hx-daily card); it opens the note. Before the first one: where
/// notes come from, and the way to Listen.
class _LatestNote extends StatelessWidget {
  const _LatestNote({required this.note, required this.onOpen, required this.onListen});

  final ListenNote? note;
  final ValueChanged<ListenNote> onOpen;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final (eyebrow, title, detail) = note == null
        ? ('NOTES', 'Your notes will appear here', 'Listen to a meeting, a class or a consultation')
        : ('LATEST NOTE', note.title, _detail(note));
    return Semantics(
      button: true,
      label: note == null ? 'Notes: $title. Open Listen.' : 'Latest note: $title, $detail',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: AppShadows.card),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: const BoxDecoration(gradient: AppGradients.night),
              child: InkWell(
                onTap: note == null ? onListen : () => onOpen(note),
                child: CustomPaint(
                  painter: _DotGrid(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                    child: Row(
                      children: [
                        if (note != null) ...[
                          NoteKindBadge(kind: note.kind, size: 44),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.sticky_note_2_rounded, size: 13, color: AppColors.yellow),
                                const SizedBox(width: 5),
                                Text(eyebrow, style: AppText.eyebrow.copyWith(color: AppColors.yellow)),
                              ]),
                              const SizedBox(height: 4),
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.cardTitle.copyWith(fontSize: 17)),
                              const SizedBox(height: 2),
                              Text(detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 12.5)),
                              if (note?.summary?.overview ?? note?.lines.firstOrNull?.text case final preview?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.small.copyWith(color: AppColors.onDark, fontSize: 12.5)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.m),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: AppGradients.sun,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.15), spreadRadius: 6)],
                          ),
                          child: Icon(note == null ? Icons.volume_up_rounded : Icons.arrow_forward_rounded,
                              color: AppColors.onYellow, size: 20),
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

/// When and how long; when is left out if the title already says it (the default title has the time).
String _detail(ListenNote note) {
  final length = durationLabel(note.duration);
  return note.title.contains(clockTime(note.startedAt)) ? length : '${dayAndTime(note.startedAt)} · $length';
}

/// Faint dot pattern (design: radial-gradient dots on .hx-daily).
class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.onDark.withValues(alpha: 0.1);
    for (var x = 1.0; x < size.width; x += 14) {
      for (var y = 1.0; y < size.height; y += 14) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid old) => false;
}

/// Shown until conversation history exists (redesign step 7).
/// The newest 3 saved conversations, or a card saying there are none yet.
class _Recent extends StatelessWidget {
  const _Recent({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final recent = services.history.recent.take(3).toList();
    if (recent.isEmpty) return _EmptyRecent(kept: services.history.kept);
    return Column(
      children: [
        for (final c in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ConversationTile(
              conversation: c,
              language: services.speaker.language,
              onTap: () => openConversation(context, services, c),
            ),
          ),
        if (!services.history.kept)
          Text(keptNote(services), textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.inkFaint)),
      ],
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.kept});

  final bool kept;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.forum_outlined, color: AppColors.turq),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No conversations yet', style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                      kept
                          ? 'Connect your glove and start signing. Your conversations are saved to your account.'
                          : 'Connect your glove and start signing. Sign in to keep your conversations.',
                      style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
