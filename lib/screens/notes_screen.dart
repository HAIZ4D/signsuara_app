import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/note_kind_icon.dart';
import 'note_screen.dart';

/// Notes tab (README "Listen and Notes"): every Listen session, newest first and grouped by day,
/// to read again.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.services, required this.onOpenListen});

  final AppServices services;
  final VoidCallback onOpenListen;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: services.notes,
        builder: (context, _) {
          final all = services.notes.all;
          final total = all.fold(Duration.zero, (sum, note) => sum + note.duration);
          String? day;
          return ListView(
            padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
            children: [
              HeroPanel(
                bottomPadding: 26,
                child: FadeUp(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const ExcludeSemantics(child: Icon(Icons.sticky_note_2_rounded, size: 14, color: AppColors.yellow)),
                        const SizedBox(width: 6),
                        Text('NOTES', style: AppText.eyebrow.copyWith(color: AppColors.yellow, fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Text('What you listened to', style: AppText.heroTitle.copyWith(fontSize: 24)),
                      const SizedBox(height: 6),
                      Text('Meetings, classes and consultations, kept to read again.',
                          style: AppText.body.copyWith(color: AppColors.onDarkSoft)),
                      const SizedBox(height: AppSpace.l),
                      Row(children: [
                        Expanded(child: _Stat('${all.length}', all.length == 1 ? 'Note' : 'Notes', AppColors.turqBright)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(total.inMinutes < 1 ? (all.isEmpty ? '0 min' : '< 1 min') : durationLabel(total),
                              'Listened', AppColors.yellow),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, 0),
                  child: _EmptyNotes(onOpenListen: onOpenListen),
                )
              else
                for (final (i, note) in all.indexed) ...[
                  if (dayName(note.startedAt) != day)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Text(day = dayName(note.startedAt), style: AppText.label.copyWith(color: AppColors.inkSoft)),
                    ),
                  FadeUp(
                    delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 10),
                      child: _NoteCard(note: note, onTap: () => openNote(context, services, note)),
                    ),
                  ),
                ],
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                child: Text(
                  services.notes.kept
                      ? 'Saved to your Google account (the newest 100 are shown).'
                      : 'As a guest, notes are kept only until the app closes. Sign in to save them.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A number on the hero, e.g. "3 Notes" (real data only).
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(color: color, fontSize: 20)),
              Text(label, style: AppText.small.copyWith(color: AppColors.onDarkSoft)),
            ],
          ),
        ),
      );
}

/// One note in the list: its kind, title, time, length and first words.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final ListenNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = note.lines.length;
    final meta = '${clockTime(note.startedAt)} · ${durationLabel(note.duration)} · '
        '$count ${count == 1 ? 'sentence' : 'sentences'}';
    return Semantics(
      button: true,
      label: '${note.title}. ${note.kind.label}, $meta${note.summary != null ? ', with Gemini notes' : ''}',
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
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NoteKindBadge(kind: note.kind),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.strong.copyWith(color: AppColors.ink)),
                        const SizedBox(height: 3),
                        Text(meta, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                        if (note.summary != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.onYellowInk),
                            const SizedBox(width: 4),
                            Text('Gemini notes', style: AppText.small.copyWith(color: AppColors.onYellowInk)),
                          ]),
                        ],
                        if (note.summary?.overview ?? note.lines.firstOrNull?.text case final preview?) ...[
                          const SizedBox(height: 4),
                          Text(preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Before the first note: where notes come from, and the way to Listen.
class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.onOpenListen});

  final VoidCallback onOpenListen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: NoteKindBadge(kind: NoteKind.meeting)),
            const SizedBox(height: AppSpace.m),
            Text('No notes yet', style: AppText.section),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Start listening in a meeting, a class or a consultation. Everything heard is kept here '
              'to read again.',
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpace.l),
            GradientButton(
              label: 'Go to Listen',
              icon: Icons.volume_up_rounded,
              gradient: AppGradients.sun,
              shadow: AppShadows.sunGlow,
              foreground: AppColors.onYellow,
              onTap: onOpenListen,
            ),
          ],
        ),
      );
}
