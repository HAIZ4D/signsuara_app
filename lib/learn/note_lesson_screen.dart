import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../signer/sign_player.dart';
import 'note_picker.dart';
import 'note_signs.dart';
import 'sign_lesson_screen.dart';

/// The signs heard in [note] that the avatar can show (cheap: run on every build of a note).
List<HeardSign> heardSigns(AppServices services, ListenNote note) =>
    signsInNote(note, services.signer.translator, services.signer.library);

/// "Learn the signs you heard" (README "Learn"): a lesson of the signs heard in [note], each with
/// the sentence it was heard in. It turns what was said in a class into a BIM lesson. Says so when
/// the note has none.
void openNoteLesson(BuildContext context, AppServices services, ListenNote note, {ClipOpener openClip = openAssetClip}) {
  final signs = heardSigns(services, note);
  if (signs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No words in this note have a sign clip yet. Names and other words: try Eja Nama.')));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SignLessonScreen(
      services: services,
      title: 'Signs from your note',
      subtitle: note.title,
      ids: [for (final s in signs) s.id],
      heard: {for (final s in signs) s.id: s},
      openClip: openClip,
    ),
  ));
}

/// The hub's "Signs in your notes" card: pick a note (with how many signs each has), then the lesson.
Future<void> pickNoteForLesson(BuildContext context, AppServices services, {ClipOpener openClip = openAssetClip}) async {
  int count(ListenNote note) => heardSigns(services, note).length;
  final note = await pickNote(
    context,
    services,
    title: 'Signs in your notes',
    intro: 'Pick a note. The avatar shows the signs for the words that were said.',
    none: 'No notes yet. Use Listen in a class or a meeting, then come back to learn its signs.',
    info: (note) => switch (count(note)) { 0 => 'No signs', 1 => '1 sign', final n => '$n signs' },
    canPick: (note) => count(note) > 0,
  );
  if (note != null && context.mounted) openNoteLesson(context, services, note, openClip: openClip);
}
