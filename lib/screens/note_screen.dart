import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../listen/listen_session.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/note_kind_icon.dart';
import '../ui/widgets/note_sheet.dart';

void openNote(BuildContext context, AppServices services, ListenNote note) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteScreen(services: services, noteId: note.id)),
    );

/// One note read again: what it was, when, and every sentence heard with its time. Copy, edit
/// (kind and title) and delete.
class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.services, required this.noteId});

  final AppServices services;
  final String noteId;

  static String asText(ListenNote note) => [
        note.title,
        '${dayAndTime(note.startedAt)} · ${durationLabel(note.duration)}',
        '',
        for (final line in note.lines) '${clockTime(line.at)}  ${line.text}',
      ].join('\n');

  Future<void> _copy(BuildContext context, ListenNote note) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: asText(note)));
    messenger.showSnackBar(const SnackBar(content: Text('The note was copied.')));
  }

  Future<void> _edit(BuildContext context, ListenNote note) async {
    final decision = await showNoteSheet(context, note, editing: true);
    if (decision == null || decision.discard) return;
    final title = decision.title.trim();
    await services.notes.save(
        note.copyWith(kind: decision.kind, title: title.isEmpty ? ListenSession.defaultTitle(decision.kind, note.startedAt) : title));
  }

  Future<void> _delete(BuildContext context, ListenNote note) async {
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(services.notes.kept
            ? 'It is removed from your Google account. This cannot be undone.'
            : 'It is removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    await services.notes.delete(note.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.notes,
      builder: (context, _) {
        final note = services.notes.byId(noteId);
        if (note == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(),
            body: Center(child: Text('This note was deleted.', style: AppText.body.copyWith(color: AppColors.inkSoft))),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Text(note.kind.label),
            actions: [
              IconButton(tooltip: 'Copy the note', icon: const Icon(Icons.copy_rounded), onPressed: () => _copy(context, note)),
              IconButton(tooltip: 'Edit note', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, note)),
              IconButton(
                  tooltip: 'Delete note',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context, note)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
            children: [
              _Header(note: note),
              const SizedBox(height: 14),
              _Transcript(note: note),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.note});

  final ListenNote note;

  @override
  Widget build(BuildContext context) {
    final count = note.lines.length;
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteKindBadge(kind: note.kind, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: AppText.section.copyWith(fontSize: 19)),
                const SizedBox(height: AppSpace.xs),
                if (!note.title.contains(dayAndTime(note.startedAt))) // the default title already says when
                  Text(dayAndTime(note.startedAt), style: AppText.body.copyWith(color: AppColors.inkSoft)),
                Text(
                    '${durationLabel(note.duration)} · $count ${count == 1 ? 'sentence' : 'sentences'} · '
                    '${note.language.displayName}',
                    style: AppText.small.copyWith(color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every sentence heard, with the time it was said.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.note});

  final ListenNote note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.l, 14, AppSpace.l, 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const ExcludeSemantics(child: Icon(Icons.subject_rounded, size: 15, color: AppColors.turq)),
              const SizedBox(width: 6),
              Text('WHAT WAS SAID', style: AppText.eyebrow.copyWith(color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 10),
            for (final line in note.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(clockTime(line.at), style: AppText.small.copyWith(color: AppColors.inkSoft, height: 1.9)),
                    ),
                    Expanded(child: Text(line.text, style: AppText.body.copyWith(color: AppColors.ink, fontSize: 15.5))),
                  ],
                ),
              ),
          ],
        ),
      );
}
