import 'package:flutter/material.dart';

import '../../listen/listen_note.dart';

/// The icon for each kind of note (Listen's save sheet, Notes).
IconData noteKindIcon(NoteKind kind) => switch (kind) {
      NoteKind.meeting => Icons.groups_rounded,
      NoteKind.lesson => Icons.school_rounded,
      NoteKind.consultation => Icons.medical_services_rounded,
      NoteKind.program => Icons.campaign_rounded,
      NoteKind.other => Icons.notes_rounded,
    };
