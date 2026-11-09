import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/note_kind_icon.dart';

/// Learn's list of the user's Listen notes (Gemini Quiz, Signs in your notes), as a bottom sheet:
/// the picked note, or null. [info] = what a note offers ("Quiz saved", "4 signs"; null = nothing
/// to add); [canPick] = false greys a note out. [none] is shown when there are no notes at all.
Future<ListenNote?> pickNote(
  BuildContext context,
  AppServices services, {
  required String title,
  required String intro,
  required String none,
  String? Function(ListenNote note)? info,
  bool Function(ListenNote note)? canPick,
}) =>
    showModalBottomSheet<ListenNote>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        final notes = services.notes.all;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, MediaQuery.paddingOf(context).bottom + AppSpace.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.section),
                const SizedBox(height: AppSpace.xs),
                Text(notes.isEmpty ? none : intro, style: AppText.body.copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: AppSpace.m),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final note in notes)
                        Builder(builder: (context) {
                          final can = canPick?.call(note) ?? true;
                          final extra = info?.call(note);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: can,
                            leading: Opacity(opacity: can ? 1 : 0.45, child: NoteKindBadge(kind: note.kind, size: 40)),
                            title: Text(note.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.strong.copyWith(color: can ? AppColors.ink : AppColors.inkFaint)),
                            subtitle: Text('${dayAndTime(note.startedAt)} · ${durationLabel(note.duration)}',
                                style: AppText.small.copyWith(color: AppColors.inkSoft)),
                            trailing: extra == null
                                ? const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint)
                                : Text(extra, style: AppText.small.copyWith(color: can ? AppColors.turqInk : AppColors.inkSoft)),
                            onTap: () => Navigator.pop(context, note),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
