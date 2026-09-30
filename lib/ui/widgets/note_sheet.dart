import 'package:flutter/material.dart';

import '../../listen/listen_note.dart';
import '../../listen/listen_session.dart';
import '../../theme/app_theme.dart';
import '../time_label.dart';
import 'gradient_button.dart';
import 'note_kind_icon.dart';

/// What the note sheet decided: keep the note as [kind] with [title], or throw it away.
class NoteDecision {
  const NoteDecision.keep(this.kind, this.title) : discard = false;
  const NoteDecision.discard()
      : kind = NoteKind.other,
        title = '',
        discard = true;

  final NoteKind kind;
  final String title;
  final bool discard;
}

/// The sheet to name a note: after Stop in Listen ([editing] false: can also throw it away), or to
/// change a saved note's kind and title ([editing] true). Null when it was closed without choosing.
Future<NoteDecision?> showNoteSheet(BuildContext context, ListenNote note, {bool editing = false}) =>
    showModalBottomSheet<NoteDecision>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteSheet(note: note, editing: editing),
    );

class NoteSheet extends StatefulWidget {
  const NoteSheet({super.key, required this.note, this.editing = false});

  final ListenNote note;
  final bool editing;

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late var _kind = widget.editing ? widget.note.kind : NoteKind.meeting;
  late final _title = TextEditingController(
      text: widget.editing ? widget.note.title : ListenSession.defaultTitle(_kind, widget.note.startedAt));
  late var _edited = widget.editing; // a typed title is not replaced when the kind changes

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _pick(NoteKind kind) => setState(() {
        _kind = kind;
        if (!_edited) _title.text = ListenSession.defaultTitle(kind, widget.note.startedAt);
      });

  Future<void> _discard() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Throw this recording away?'),
        content: const Text('Everything heard in this session will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Throw away')),
        ],
      ),
    );
    if (sure == true && mounted) Navigator.pop(context, const NoteDecision.discard());
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final eyebrow = AppText.eyebrow.copyWith(color: AppColors.inkSoft);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
                const SizedBox(height: AppSpace.l),
                Text(widget.editing ? 'Edit note' : 'Save this listening', style: AppText.section.copyWith(fontSize: 20)),
                const SizedBox(height: AppSpace.xs),
                Text(
                    '${note.lines.length} ${note.lines.length == 1 ? 'sentence' : 'sentences'} · '
                    '${durationLabel(note.duration)}',
                    style: AppText.body.copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: AppSpace.xl),
                Text('WHAT WAS IT?', style: eyebrow),
                const SizedBox(height: AppSpace.s),
                Wrap(
                  spacing: AppSpace.s,
                  runSpacing: AppSpace.s,
                  children: [
                    for (final kind in NoteKind.values)
                      _KindChip(kind: kind, selected: kind == _kind, onTap: () => _pick(kind)),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Text('TITLE', style: eyebrow),
                const SizedBox(height: AppSpace.s),
                TextField(
                  controller: _title,
                  onChanged: (_) => _edited = true,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.strong.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                GradientButton(
                  label: widget.editing ? 'Save changes' : 'Save note',
                  icon: Icons.bookmark_added_rounded,
                  onTap: () => Navigator.pop(context, NoteDecision.keep(_kind, _title.text)),
                ),
                if (!widget.editing) ...[
                  const SizedBox(height: AppSpace.s),
                  TextButton(
                    onPressed: _discard,
                    child: Text('Throw it away', style: AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One kind to choose in the sheet.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  final NoteKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: kind.label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.turq : null,
                color: selected ? null : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: selected ? AppShadows.turqTile : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(noteKindIcon(kind), size: 17, color: selected ? AppColors.onDark : AppColors.turqDeep),
                const SizedBox(width: 7),
                Text(kind.label,
                    style: AppText.label.copyWith(color: selected ? AppColors.onDark : AppColors.ink, fontSize: 13.5)),
              ]),
            ),
          ),
        ),
      );
}
