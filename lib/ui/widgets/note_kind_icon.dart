import 'package:flutter/material.dart';

import '../../listen/listen_note.dart';
import '../../theme/app_theme.dart';

/// The icon for each kind of note (Listen's save sheet, Notes, Home).
IconData noteKindIcon(NoteKind kind) => switch (kind) {
      NoteKind.meeting => Icons.groups_rounded,
      NoteKind.lesson => Icons.school_rounded,
      NoteKind.consultation => Icons.medical_services_rounded,
      NoteKind.program => Icons.campaign_rounded,
      NoteKind.other => Icons.notes_rounded,
    };

/// Each kind's own Deaf Flag colours: its gradient, the glow under its badge, the icon colour on it.
(Gradient, List<BoxShadow>, Color) noteKindColours(NoteKind kind) => switch (kind) {
      NoteKind.meeting => (AppGradients.turq, AppShadows.turqTile, AppColors.onDark),
      NoteKind.lesson => (AppGradients.blueTile, AppShadows.blueTile, AppColors.onDark),
      NoteKind.consultation => (AppGradients.sun, AppShadows.sunGlow, AppColors.onYellow),
      NoteKind.program => (AppGradients.cta, AppShadows.turqTile, AppColors.onDark),
      NoteKind.other => (AppGradients.night, AppShadows.blueTile, AppColors.onDark),
    };

/// Each kind's quiet colours for the Notes list: a pale background and the icon colour on it.
(Color, Color) noteKindTint(NoteKind kind) => switch (kind) {
      NoteKind.meeting => (AppColors.turqWash, AppColors.turqInk),
      NoteKind.lesson => (AppColors.blueWash, AppColors.royal),
      NoteKind.consultation => (AppColors.yellowWash, AppColors.onYellowInk),
      NoteKind.program => (AppColors.turqWash, AppColors.turqDeep),
      NoteKind.other => (AppColors.surface2, AppColors.blue),
    };

/// The rounded square behind a note's icon.
class NoteKindBadge extends StatelessWidget {
  const NoteKindBadge({super.key, required this.kind, this.size = 46});

  final NoteKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (gradient, shadow, color) = noteKindColours(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(size * 0.33), boxShadow: shadow),
      child: Icon(noteKindIcon(kind), size: size * 0.5, color: color),
    );
  }
}
