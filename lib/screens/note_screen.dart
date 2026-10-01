import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../listen/listen_session.dart';
import '../listen/note_summary.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/note_kind_icon.dart';
import '../ui/widgets/note_sheet.dart';
import '../ui/widgets/notice.dart';

void openNote(BuildContext context, AppServices services, ListenNote note) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteScreen(services: services, noteId: note.id)),
    );

/// One note read again: what it was, when, Gemini's notes (when asked for), and every sentence heard
/// with its time. Copy, edit (kind and title) and delete.
class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key, required this.services, required this.noteId});

  final AppServices services;
  final String noteId;

  /// The note as plain text (Copy): title, Gemini's notes if there are any, then what was said.
  static String asText(ListenNote note) {
    final summary = note.summary;
    return [
      note.title,
      '${dayAndTime(note.startedAt)} · ${durationLabel(note.duration)}',
      if (summary != null) ...[
        '',
        summary.overview,
        for (final (title, items) in [
          ('Key points', summary.keyPoints),
          ('Advice and to do', summary.actions),
          ('Important details', summary.details),
        ])
          if (items.isNotEmpty) ...['', '$title:', for (final item in items) '- $item'],
        if (summary.terms.isNotEmpty) ...['', 'Words explained:', for (final t in summary.terms) '- ${t.term}: ${t.meaning}'],
        '',
        'Notes made by Gemini: check important details.',
      ],
      '',
      'What was said:',
      for (final line in note.lines) '${clockTime(line.at)}  ${line.text}',
    ].join('\n');
  }

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  var _busy = false; // Gemini is writing
  String? _problem;

  AppServices get services => widget.services;

  Future<void> _summarize(ListenNote note) async {
    if (!services.summaryNoticeSeen) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Make notes with Gemini?'),
          content: const Text(
            "To make the notes, the words heard in this note are sent to Google's Gemini. SignSuara uses "
            "Gemini's paid service, so Google does not use them to train its models.\n\n"
            'Gemini can make mistakes: check important details, like doses and dates, against what was '
            'said. The notes are not medical advice.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Make notes')),
          ],
        ),
      );
      if (ok != true) return;
      await services.markSummaryNoticeSeen();
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await services.notes.summarize(note);
    } on SummaryFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(ListenNote note) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: NoteScreen.asText(note)));
    messenger.showSnackBar(const SnackBar(content: Text('The note was copied.')));
  }

  Future<void> _edit(ListenNote note) async {
    final decision = await showNoteSheet(context, note, editing: true);
    if (decision == null || decision.discard) return;
    final title = decision.title.trim();
    await services.notes.save(
        note.copyWith(kind: decision.kind, title: title.isEmpty ? ListenSession.defaultTitle(decision.kind, note.startedAt) : title));
  }

  Future<void> _delete(ListenNote note) async {
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
        final note = services.notes.byId(widget.noteId);
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
              IconButton(tooltip: 'Copy the note', icon: const Icon(Icons.copy_rounded), onPressed: () => _copy(note)),
              IconButton(tooltip: 'Edit note', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(note)),
              IconButton(tooltip: 'Delete note', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(note)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
            children: [
              _Header(note: note),
              const SizedBox(height: 14),
              if (_problem case final problem?) Notice(message: problem),
              if (_busy)
                const _Writing()
              else if (note.summary case final summary?)
                _SummaryCards(summary: summary, onAgain: () => _summarize(note))
              else
                _AskGemini(onTap: () => _summarize(note)),
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
    return _Card(
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

/// No summary yet: what Gemini would make, and the button.
class _AskGemini extends StatelessWidget {
  const _AskGemini({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(gradient: AppGradients.sun, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.onYellow, size: 21),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(child: Text('Clear notes by Gemini', style: AppText.section)),
            ]),
            const SizedBox(height: AppSpace.s),
            Text('The main points, what to do, important details and hard words explained, in simple words.',
                style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: AppSpace.l),
            GradientButton(label: 'Summarise with Gemini', icon: Icons.auto_awesome_rounded, onTap: onTap),
          ],
        ),
      );
}

class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) => _Card(
        child: Semantics(
          liveRegion: true,
          label: 'Gemini is writing your notes',
          excludeSemantics: true,
          child: Row(children: [
            const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.turq),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gemini is writing your notes…', style: AppText.strong.copyWith(color: AppColors.ink)),
                  Text('This takes a few seconds.', style: AppText.small.copyWith(color: AppColors.inkSoft)),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// Gemini's notes, one card per part (parts with nothing in them are left out).
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary, required this.onAgain});

  final NoteSummary summary;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final text = AppText.body.copyWith(color: AppColors.ink, fontSize: 15.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          icon: Icons.auto_awesome_rounded,
          title: 'SUMMARY',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.overview, style: text),
              const SizedBox(height: AppSpace.s),
              Row(children: [
                Expanded(
                  child: Text('Made by Gemini: check important details.',
                      style: AppText.small.copyWith(color: AppColors.inkSoft)),
                ),
                TextButton(onPressed: onAgain, child: const Text('Summarise again')),
              ]),
            ],
          ),
        ),
        if (summary.keyPoints.isNotEmpty)
          _Section(
            icon: Icons.format_list_bulleted_rounded,
            title: 'KEY POINTS',
            child: Column(children: [
              for (final point in summary.keyPoints)
                _Item(
                  lead: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(color: AppColors.turq, shape: BoxShape.circle),
                  ),
                  child: Text(point, style: text),
                ),
            ]),
          ),
        if (summary.actions.isNotEmpty)
          _Section(
            icon: Icons.task_alt_rounded,
            title: 'ADVICE & TO DO',
            child: Column(children: [
              for (final action in summary.actions)
                _Item(
                  lead: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.onYellowInk),
                  child: Text(action, style: text),
                ),
            ]),
          ),
        if (summary.details.isNotEmpty)
          _Section(
            icon: Icons.push_pin_outlined,
            title: 'IMPORTANT DETAILS',
            child: Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final detail in summary.details)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.yellowWash, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text(detail, style: AppText.label.copyWith(color: AppColors.onYellow, fontSize: 14)),
                  ),
              ],
            ),
          ),
        if (summary.terms.isNotEmpty)
          _Section(
            icon: Icons.menu_book_rounded,
            title: 'WORDS EXPLAINED',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in summary.terms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: t.term, style: AppText.strong.copyWith(color: AppColors.ink)),
                        TextSpan(text: '  ${t.meaning}'),
                      ]),
                      style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 15),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                ExcludeSemantics(child: Icon(icon, size: 15, color: AppColors.turq)),
                const SizedBox(width: 6),
                Text(title, style: AppText.eyebrow.copyWith(color: AppColors.inkSoft)),
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

/// A line with a mark in front of it (a dot, a tick).
class _Item extends StatelessWidget {
  const _Item({required this.lead, required this.child});

  final Widget lead;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 22, child: Align(alignment: Alignment.topLeft, child: lead)),
            const SizedBox(width: 6),
            Expanded(child: child),
          ],
        ),
      );
}

/// Every sentence heard, with the time it was said.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.note});

  final ListenNote note;

  @override
  Widget build(BuildContext context) => _Card(
        padding: const EdgeInsets.fromLTRB(AppSpace.l, 14, AppSpace.l, 6),
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

/// A white card (the page's building block).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(AppSpace.l)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
        child: child,
      );
}
