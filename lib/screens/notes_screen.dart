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
/// to search, filter by kind and read again.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.services, required this.onOpenListen});

  final AppServices services;
  final VoidCallback onOpenListen;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  NoteKind? _kind; // the kind filter; null = every kind

  AppServices get services => widget.services;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showAll() {
    _search.clear();
    setState(() => _kind = null);
  }

  // ⋮ on a card: the note's actions, without opening it.
  Future<void> _more(ListenNote note) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, AppSpace.s),
              child: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.section),
            ),
            for (final (action, icon, label) in const [
              ('open', Icons.open_in_new_rounded, 'Open'),
              ('copy', Icons.copy_rounded, 'Copy as text'),
              ('edit', Icons.edit_outlined, 'Change kind or title'),
              ('delete', Icons.delete_outline_rounded, 'Delete'),
            ])
              ListTile(
                leading: Icon(icon, color: action == 'delete' ? AppColors.danger : AppColors.turqDeep),
                title: Text(label, style: AppText.strong.copyWith(color: AppColors.ink)),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'open':
        openNote(context, services, note);
      case 'copy':
        await copyNote(context, note);
      case 'edit':
        await editNote(context, services, note);
      case 'delete':
        await deleteNote(context, services, note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: Listenable.merge([services.notes, _search]),
        builder: (context, _) {
          final all = services.notes.all;
          final query = _search.text.trim().toLowerCase();
          final kinds = {for (final note in all) note.kind};
          final kind = kinds.contains(_kind) ? _kind : null; // the filter's last note may be gone
          final shown = [
            for (final note in all)
              if ((kind == null || note.kind == kind) && (query.isEmpty || _found(note, query) != null)) note,
          ];
          String? day;
          return ListView(
            padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
            children: [
              _Hero(notes: all, search: all.isEmpty ? null : _search),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, 0),
                  child: _EmptyNotes(onOpenListen: widget.onOpenListen),
                )
              else ...[
                if (kinds.length > 1)
                  _KindFilter(notes: all, selected: kind, onSelect: (kind) => setState(() => _kind = kind)),
                if (shown.isEmpty)
                  _NoMatch(query: _search.text.trim(), onShowAll: _showAll)
                else
                  for (final (i, note) in shown.indexed) ...[
                    if (dayName(note.startedAt) != day) _DayHeader(day = dayName(note.startedAt)),
                    FadeUp(
                      key: ValueKey(note.id),
                      delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.m),
                        child: _NoteCard(
                          note: note,
                          query: query,
                          onOpen: () => openNote(context, services, note),
                          onMore: () => _more(note),
                        ),
                      ),
                    ),
                  ],
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

/// Where [query] (lower case) is in a note: the summary part or sentence it is in (shown on the
/// card), the title, or null when the note doesn't have it.
String? _found(ListenNote note, String query) {
  final summary = note.summary;
  final texts = [
    if (summary != null) ...[
      summary.overview,
      ...summary.keyPoints,
      ...summary.actions,
      ...summary.details,
      for (final t in summary.terms) '${t.term}: ${t.meaning}',
    ],
    for (final line in note.lines) line.text,
    note.title,
  ];
  for (final text in texts) {
    if (text.toLowerCase().contains(query)) return text;
  }
  return null;
}

/// [text] with every [query] (lower case) marked, for search results.
TextSpan _marked(String text, String query, TextStyle style) {
  final lower = text.toLowerCase();
  if (query.isEmpty || lower.length != text.length) return TextSpan(text: text, style: style);
  final mark = style.copyWith(backgroundColor: AppColors.yellowWash, color: AppColors.ink, fontWeight: FontWeight.w800);
  final parts = <TextSpan>[];
  var from = 0;
  for (var at = lower.indexOf(query); at >= 0; at = lower.indexOf(query, from)) {
    parts
      ..add(TextSpan(text: text.substring(from, at)))
      ..add(TextSpan(text: text.substring(at, at + query.length), style: mark));
    from = at + query.length;
  }
  parts.add(TextSpan(text: text.substring(from)));
  return TextSpan(style: style, children: parts);
}

/// The dark header: what this tab is, real numbers, and the search field over its bottom edge.
class _Hero extends StatelessWidget {
  const _Hero({required this.notes, required this.search});

  final List<ListenNote> notes;
  final TextEditingController? search; // none before the first note

  @override
  Widget build(BuildContext context) {
    final total = notes.fold(Duration.zero, (sum, note) => sum + note.duration);
    final listened = total.inMinutes < 1 ? (notes.isEmpty ? '0 min' : '< 1 min') : durationLabel(total);
    final summarised = notes.where((note) => note.summary != null).length;
    final panel = HeroPanel(
      bottomPadding: search == null ? 26 : 50,
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
              Expanded(child: _Stat('${notes.length}', notes.length == 1 ? 'Note' : 'Notes', AppColors.turqBright)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(listened, 'Listened', AppColors.yellow)),
              const SizedBox(width: 10),
              Expanded(child: _Stat('$summarised', 'With Gemini', AppColors.onDark)),
            ]),
          ],
        ),
      ),
    );
    final field = search;
    if (field == null) return panel;
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 26), child: panel),
        Positioned(left: AppSpace.gutter, right: AppSpace.gutter, bottom: 0, child: _SearchField(controller: field)),
      ],
    );
  }
}

/// A number on the header, e.g. "3 Notes" (real data only).
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
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: AppText.cardTitle.copyWith(color: color, fontSize: 20)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.onDarkSoft)),
            ],
          ),
        ),
      );
}

/// Search titles, sentences and Gemini's notes, as you type.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.pop,
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppText.strong.copyWith(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Search your notes',
            hintStyle: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 15),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.turqDeep),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear the search',
                    icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
                    onPressed: controller.clear,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}

/// Show one kind of note (only the kinds there are, with how many).
class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.notes, required this.selected, required this.onSelect});

  final List<ListenNote> notes;
  final NoteKind? selected;
  final ValueChanged<NoteKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <NoteKind, int>{};
    for (final note in notes) {
      counts[note.kind] = (counts[note.kind] ?? 0) + 1;
    }
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 14, AppSpace.gutter, 0),
        children: [
          _Chip(label: 'All', count: notes.length, selected: selected == null, onTap: () => onSelect(null)),
          for (final kind in NoteKind.values)
            if (counts[kind] case final count?)
              _Chip(
                icon: noteKindIcon(kind),
                label: kind.label,
                count: count,
                selected: selected == kind,
                onTap: () => onSelect(kind),
              ),
        ],
      ),
    );
  }
}

/// One filter: dark blue when chosen.
class _Chip extends StatelessWidget {
  const _Chip({this.icon, required this.label, required this.count, required this.selected, required this.onTap});

  final IconData? icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.s),
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label, $count',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
            curve: AppMotion.outCurve,
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: selected ? AppColors.blue : AppColors.line),
              boxShadow: selected ? AppShadows.blueTile : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon case final icon?) ...[
                      Icon(icon, size: 16, color: selected ? AppColors.yellow : AppColors.turqDeep),
                      const SizedBox(width: 6),
                    ],
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: label),
                        TextSpan(text: '  $count', style: TextStyle(color: selected ? AppColors.onDarkSoft : AppColors.inkSoft)),
                      ]),
                      style: AppText.label.copyWith(color: selected ? AppColors.onDark : AppColors.ink, fontSize: 13.5),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// "Today ———" above the notes of a day.
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day);

  final String day;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Row(children: [
          Semantics(header: true, child: Text(day, style: AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 13))),
          const SizedBox(width: AppSpace.m),
          const Expanded(child: Divider(height: 1, color: AppColors.line)),
        ]),
      );
}

/// One note, quietly: its kind's icon, the title, the first words or Gemini's summary, and one line
/// with how long it was and whether Gemini made notes. Tap opens it; ⋮ has its actions.
class _NoteCard extends StatefulWidget {
  const _NoteCard({required this.note, required this.query, required this.onOpen, required this.onMore});

  final ListenNote note;
  final String query; // the search, lower case ('' = none)
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final query = widget.query;
    final summary = note.summary;
    final found = query.isEmpty ? null : _found(note, query);
    final preview = found != null && found != note.title ? _near(found, query) : summary?.overview ?? note.lines.firstOrNull?.text;
    final time = clockTime(note.startedAt);
    final kindAndTime = note.title.contains(time) ? null : '${note.kind.label} · $time'; // a default title says both
    final length = durationLabel(note.duration);
    final soft = AppText.small.copyWith(color: AppColors.inkSoft);
    final previewStyle = AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5);
    final (wash, ink) = noteKindTint(note.kind);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.quick,
      curve: AppMotion.outCurve,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Semantics(
                button: true,
                label: '${note.title}. ${note.kind.label}, $time, $length${summary != null ? ', with Gemini notes' : ''}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: widget.onOpen,
                  onHighlightChanged: (on) => setState(() => _pressed = on),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(AppRadius.sm)),
                              child: Icon(noteKindIcon(note.kind), size: 21, color: ink),
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 32), // room for ⋮
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      _marked(note.title, query, AppText.section.copyWith(fontSize: 16.5, height: 1.3)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (kindAndTime != null) ...[
                                      const SizedBox(height: 2),
                                      Text(kindAndTime, style: soft),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (preview != null) ...[
                          const SizedBox(height: AppSpace.m),
                          query.isEmpty
                              ? Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: previewStyle)
                              : Text.rich(_marked(preview, query, previewStyle), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, size: 15, color: AppColors.inkSoft),
                          const SizedBox(width: 6),
                          Expanded(child: Text(length, maxLines: 1, overflow: TextOverflow.ellipsis, style: soft)),
                          if (summary != null) const _GeminiTag(),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 2,
                child: IconButton(
                  tooltip: 'More for ${note.title}',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
                  onPressed: widget.onMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A long sentence starts near the found words, so the mark shows on the card.
  static String _near(String text, String query) {
    final at = text.toLowerCase().indexOf(query);
    return at > 50 ? '…${text.substring(at - 30)}' : text;
  }
}

/// "Gemini notes": this note has a summary.
class _GeminiTag extends StatelessWidget {
  const _GeminiTag();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(color: AppColors.yellowWash, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.onYellow),
          const SizedBox(width: 5),
          Text('Gemini notes', style: AppText.small.copyWith(color: AppColors.onYellow, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Nothing found: say so, and the way back to every note.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query, required this.onShowAll});

  final String query;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 28, color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpace.m),
            Text(query.isEmpty ? 'No notes of this kind' : 'No notes with "$query"',
                textAlign: TextAlign.center, style: AppText.section),
            const SizedBox(height: AppSpace.xs),
            Text('Try another word, or show all your notes.',
                textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: AppSpace.s),
            TextButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Show all notes'),
              style: TextButton.styleFrom(foregroundColor: AppColors.turqInk),
            ),
          ]),
        ),
      );
}

/// Before the first note: a picture, where notes come from in three steps, and the way to Listen.
class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.onOpenListen});

  final VoidCallback onOpenListen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _NotesArt()),
            const SizedBox(height: AppSpace.l),
            Text('No notes yet', textAlign: TextAlign.center, style: AppText.section.copyWith(fontSize: 19)),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Listen in a meeting, a class or a consultation. Everything heard is kept here to read again.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpace.l),
            const _Step(1, 'Open Listen and tap Start.'),
            const _Step(2, 'Tap Stop when it ends, and save it.'),
            const _Step(3, 'Open it here: Gemini can make clear notes.'),
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

/// One numbered step.
class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.turqWash, shape: BoxShape.circle),
            child: Text('$number', style: AppText.label.copyWith(color: AppColors.turqInk)),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: AppColors.ink))),
        ]),
      );
}

/// Three pages of notes and Gemini's sparkle, drawn with plain shapes.
class _NotesArt extends StatelessWidget {
  const _NotesArt();

  static Widget _page(Color color, double turn, {List<BoxShadow>? shadow, Widget? child}) => Transform.rotate(
        angle: turn,
        child: Container(
          width: 112,
          height: 84,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: shadow),
          child: child,
        ),
      );

  static Widget _line(double width, Color color) => Container(
        width: width,
        height: 7,
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
      );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: 172,
          height: 124,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 10, top: 24, child: _page(AppColors.turqWash, -0.16)),
              Positioned(left: 46, top: 12, child: _page(AppColors.yellowWash, 0.1)),
              Positioned(
                left: 28,
                top: 30,
                child: _page(
                  AppColors.surface,
                  -0.03,
                  shadow: AppShadows.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(54, AppColors.turq),
                      _line(78, AppColors.skeleton),
                      _line(64, AppColors.skeleton),
                      _line(40, AppColors.skeleton),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 0,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(gradient: AppGradients.sun, shape: BoxShape.circle, boxShadow: AppShadows.sunGlow),
                  child: const Icon(Icons.auto_awesome_rounded, size: 21, color: AppColors.onYellow),
                ),
              ),
            ],
          ),
        ),
      );
}
