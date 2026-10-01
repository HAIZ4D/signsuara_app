import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../listen/listen_session.dart';
import '../listen/note_summary.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/note_kind_icon.dart';
import '../ui/widgets/note_sheet.dart';
import '../ui/widgets/speech_rhythm.dart';
import 'note_summary_view.dart';

void openNote(BuildContext context, AppServices services, ListenNote note) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteScreen(services: services, noteId: note.id)),
    );

/// Copies [note] as plain text, and says so.
Future<void> copyNote(BuildContext context, ListenNote note) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: NoteScreen.asText(note)));
  messenger.showSnackBar(const SnackBar(content: Text('The note was copied.')));
}

/// Changes a note's kind and title, with the same sheet as after Stop.
Future<void> editNote(BuildContext context, AppServices services, ListenNote note) async {
  final decision = await showNoteSheet(context, note, editing: true);
  if (decision == null || decision.discard) return;
  final title = decision.title.trim();
  await services.notes.save(
      note.copyWith(kind: decision.kind, title: title.isEmpty ? ListenSession.defaultTitle(decision.kind, note.startedAt) : title));
}

/// Deletes a note after asking; true when it was deleted.
Future<bool> deleteNote(BuildContext context, AppServices services, ListenNote note) async {
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
  if (sure != true) return false;
  await services.notes.delete(note.id);
  return true;
}

enum _Side { notes, said }

/// One note read again (README "Listen and Notes"): a dark header with what it was, when, and when
/// things were said; then Gemini's notes or every sentence heard, picked with the switch at the
/// bottom ("Aa" makes the words bigger).
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
        for (final (title, items, ticked) in [
          ('Key points', summary.keyPoints, const <int>{}),
          ('Advice and to do', summary.actions, summary.done),
          ('Important details', summary.details, const <int>{}),
        ])
          if (items.isNotEmpty) ...[
            '',
            '$title:',
            for (final (i, item) in items.indexed) '- $item${ticked.contains(i) ? ' (done)' : ''}',
          ],
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
  var _side = _Side.notes;
  var _bigger = 0; // the "Aa" button: 0 normal, 1 bigger, 2 biggest
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  final _bar = ValueNotifier(0.0); // the slim top bar: 0 hidden … 1 shown, once the header has gone

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  // How far the page scrolls before the header is hidden under the slim bar.
  double get _headerEnd =>
      max(0, (_headerKey.currentContext?.size?.height ?? 0) - MediaQuery.paddingOf(context).top - _SlimBar.height);

  void _onScroll() => _bar.value = ((_scroll.offset - _headerEnd + 40) / 40).clamp(0.0, 1.0);

  void _show(_Side side) {
    if (side == _side) return;
    final deep = _scroll.hasClients && _scroll.offset > _headerEnd;
    setState(() => _side = side);
    // Start the other side at its top (just under the slim bar), not somewhere in the middle.
    if (deep) _scroll.jumpTo(_headerEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // A side too short to scroll that far is shown from the top of the page, header and all.
      if (deep && _scroll.position.maxScrollExtent < _headerEnd) _scroll.jumpTo(0);
      _onScroll(); // the page may have moved back without telling the listener
    });
  }

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

  // Summarise again replaces the notes (and costs a request), so it asks first.
  Future<void> _again(ListenNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make new notes?'),
        content: const Text('Gemini writes the notes again from what was said. The notes you see now are '
            'replaced, and your ticks are cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Make new notes')),
        ],
      ),
    );
    if (ok == true) await _summarize(note);
  }

  void _toggle(ListenNote note, int action) {
    final summary = note.summary;
    if (summary == null) return;
    final done = {...summary.done};
    if (!done.remove(action)) done.add(action);
    HapticFeedback.selectionClick();
    services.notes
        .save(note.copyWith(summary: summary.withDone(done)))
        .catchError((Object e) => debugPrint('Note not saved: $e'));
  }

  void _copyDetail(String detail) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: detail));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $detail')));
  }

  Future<void> _delete(ListenNote note) async {
    final navigator = Navigator.of(context);
    if (await deleteNote(context, services, note)) navigator.pop();
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
        final media = MediaQuery.of(context);
        // The phone's text size, then "Aa" on top of it (for the notes and sentences only).
        final reading = media.copyWith(
          textScaler: TextScaler.linear(media.textScaler.scale(16) / 16 * (1 + 0.2 * _bigger)),
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            extendBody: true, // the page scrolls on under the floating switch
            bottomNavigationBar: _SideSwitch(
              side: _side,
              bigger: _bigger,
              onSide: _show,
              onBigger: () => setState(() => _bigger = (_bigger + 1) % 3),
            ),
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        key: _headerKey,
                        note: note,
                        onCopy: () => copyNote(context, note),
                        onEdit: () => editNote(context, services, note),
                        onDelete: () => _delete(note),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.xl,
                        AppSpace.gutter,
                        _SideSwitch.height + AppSpace.navMargin + media.padding.bottom + AppSpace.xxl,
                      ),
                      sliver: MediaQuery(
                        data: reading,
                        child: _side == _Side.said
                            ? _Said(note: note)
                            : SliverToBoxAdapter(
                                child: NoteNotesView(
                                  note: note,
                                  busy: _busy,
                                  problem: _problem,
                                  onSummarize: () => _summarize(note),
                                  onAgain: () => _again(note),
                                  onToggle: (action) => _toggle(note, action),
                                  onCopy: _copyDetail,
                                  onSeeSaid: () => _show(_Side.said),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                _SlimBar(shown: _bar, title: note.title),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The dark header: back, copy, edit and delete; the kind of note and when; the title; how long and
/// in which language; and when things were said.
class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.note,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final ListenNote note;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      bottomPadding: AppSpace.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _GlassButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => Navigator.maybePop(context),
            ),
            const Spacer(),
            _GlassButton(icon: Icons.copy_rounded, tooltip: 'Copy the note', onTap: onCopy),
            const SizedBox(width: AppSpace.s),
            _GlassButton(icon: Icons.edit_outlined, tooltip: 'Edit note', onTap: onEdit),
            const SizedBox(width: AppSpace.s),
            _GlassButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete note', onTap: onDelete),
          ]),
          const SizedBox(height: AppSpace.l),
          Row(children: [
            NoteKindBadge(kind: note.kind, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.kind.label, style: AppText.label.copyWith(color: AppColors.yellow, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${longDate(note.startedAt)} · ${clockTime(note.startedAt)}',
                      style: AppText.small.copyWith(color: AppColors.onDarkSoft)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.l),
          Text(note.title, style: AppText.heroTitle.copyWith(fontSize: 24, height: 1.25)),
          const SizedBox(height: 14),
          Row(children: [
            Flexible(child: _GlassPill(icon: Icons.schedule_rounded, text: durationLabel(note.duration))),
            const SizedBox(width: AppSpace.s),
            Flexible(child: _GlassPill(icon: Icons.translate_rounded, text: note.language.displayName)),
          ]),
          const SizedBox(height: 18),
          _WhenSaid(note: note),
        ],
      ),
    );
  }
}

/// When things were said, from the start of the session to its end.
class _WhenSaid extends StatelessWidget {
  const _WhenSaid({required this.note});

  final ListenNote note;

  @override
  Widget build(BuildContext context) {
    final time = AppText.small.copyWith(color: AppColors.onDarkSoft);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHEN WORDS WERE SAID', style: AppText.eyebrow.copyWith(color: AppColors.onDarkSoft)),
          const SizedBox(height: 10),
          SpeechRhythm(note: note, color: AppColors.turqBright, bars: 40, height: 44),
          const SizedBox(height: 6),
          Row(children: [
            Text(clockTime(note.startedAt), style: time),
            const Spacer(),
            Text(clockTime(note.endedAt), style: time),
          ]),
        ],
      ),
    );
  }
}

/// A round glass button on the dark header.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 21, color: AppColors.onDark),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.glass,
          side: const BorderSide(color: AppColors.glassBorder),
          fixedSize: const Size.square(44),
        ),
      );
}

/// A small fact on the dark header ("12 min").
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 15, color: AppColors.turqBright)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label.copyWith(color: AppColors.onDark)),
          ),
        ]),
      );
}

/// A slim dark bar with the title, fading in once the header has scrolled away.
class _SlimBar extends StatelessWidget {
  const _SlimBar({required this.shown, required this.title});

  static const height = 56.0;

  final ValueListenable<double> shown;
  final String title;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: shown,
        builder: (context, t, _) {
          if (t == 0) return const SizedBox.shrink();
          final top = MediaQuery.paddingOf(context).top;
          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: t,
              child: Container(
                height: top + height,
                padding: EdgeInsets.only(top: top, right: AppSpace.l),
                decoration: const BoxDecoration(gradient: AppGradients.night, boxShadow: AppShadows.dock),
                child: Row(children: [
                  const BackButton(color: AppColors.onDark),
                  Expanded(
                    child: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle.copyWith(fontSize: 16.5)),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// The floating switch at the bottom (like the app's capsule nav): Gemini's notes or what was
/// said, and "Aa" for bigger words.
class _SideSwitch extends StatelessWidget {
  const _SideSwitch({required this.side, required this.bigger, required this.onSide, required this.onBigger});

  static const height = 58.0;

  final _Side side;
  final int bigger;
  final ValueChanged<_Side> onSide;
  final VoidCallback onBigger;

  @override
  Widget build(BuildContext context) {
    final glide = AppMotion.reduced(context) ? Duration.zero : AppMotion.medium;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpace.gutter, 0, AppSpace.gutter, AppSpace.navMargin + MediaQuery.paddingOf(context).bottom),
      child: Row(children: [
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: AppGradients.navCapsule,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: AppShadows.nav,
            ),
            child: Stack(
              children: [
                // The turquoise blob glides under the chosen side.
                AnimatedAlign(
                  alignment: side == _Side.notes ? Alignment.centerLeft : Alignment.centerRight,
                  duration: glide,
                  curve: AppMotion.outCurve,
                  child: const FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.navBlobTurq,
                        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                        boxShadow: AppShadows.turqTile,
                      ),
                    ),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: _Segment(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Gemini notes',
                      selected: side == _Side.notes,
                      onTap: () => onSide(_Side.notes),
                    ),
                  ),
                  Expanded(
                    child: _Segment(
                      icon: Icons.notes_rounded,
                      label: 'What was said',
                      selected: side == _Side.said,
                      onTap: () => onSide(_Side.said),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TextSize(bigger: bigger, onTap: onBigger),
      ]),
    );
  }
}

/// One side of the switch.
class _Segment extends StatelessWidget {
  const _Segment({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onDark : AppColors.onDarkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 6),
                  Text(label, maxLines: 1, style: AppText.label.copyWith(fontSize: 13.5, color: color)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Aa": normal, bigger, biggest words (three dots show which).
class _TextSize extends StatelessWidget {
  const _TextSize({required this.bigger, required this.onTap});

  static const _sizes = ['normal', 'bigger', 'biggest'];

  final int bigger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Text size',
        value: _sizes[bigger],
        excludeSemantics: true,
        child: Tooltip(
          message: 'Text size',
          child: Container(
            width: _SideSwitch.height,
            height: _SideSwitch.height,
            decoration: BoxDecoration(
              gradient: AppGradients.navCapsule,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: AppShadows.nav,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Aa', style: AppText.cardTitle.copyWith(fontSize: 16 + 2.0 * bigger, height: 1.1)),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: i <= bigger ? AppColors.turqBright : AppColors.glassBorder,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Every sentence heard, on a timeline with the time it was heard.
class _Said extends StatelessWidget {
  const _Said({required this.note});

  final ListenNote note;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpace.xs, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('WHAT WAS SAID', style: AppText.eyebrow.copyWith(color: AppColors.inkSoft, fontSize: 11.5)),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text('Every sentence, with the time it was heard.',
                      style: AppText.small.copyWith(color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: note.lines.length,
            itemBuilder: (context, i) =>
                _Line(line: note.lines[i], first: i == 0, last: i == note.lines.length - 1),
          ),
        ],
      );
}

/// One sentence: its time, a dot on the rail, and the words in a card.
class _Line extends StatelessWidget {
  const _Line({required this.line, required this.first, required this.last});

  final NoteLine line;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // The time column grows with the text size, so "10:32 AM" stays on one line.
    final time = 66 * MediaQuery.textScalerOf(context).scale(12) / 12;
    return Stack(
        children: [
          // The rail joining the dots: from the first dot down, to the last dot.
          if (!(first && last))
            Positioned(
              left: time + 6,
              top: first ? 22 : 0,
              bottom: last ? null : 0,
              height: last ? 22 : null,
              width: 2,
              child: const ColoredBox(color: AppColors.line),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: time,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: Text(clockTime(line.at),
                        maxLines: 1,
                        softWrap: false,
                        style: AppText.small.copyWith(color: AppColors.turqInk, fontWeight: FontWeight.w800)),
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 15),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.turq, width: 3),
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.card,
                    ),
                    child: Text(line.text, style: AppText.reading),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }
}
