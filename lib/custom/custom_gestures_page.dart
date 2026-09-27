import 'package:flutter/material.dart';

import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../speech/sign_words.dart';
import 'custom_gesture.dart';
import 'custom_gestures.dart';
import 'record_gesture_page.dart';

/// "My gestures": the custom gestures, with delete and "New gesture".
class CustomGesturesPage extends StatelessWidget {
  const CustomGesturesPage({super.key, required this.gestures, required this.session});

  final CustomGestures gestures;
  final GloveSession session;

  @override
  Widget build(BuildContext context) {
    final builtIn = [
      for (final l in kLabels)
        if (l != GestureClassifier.restLabel) wordsFor(l).malay
    ].join(', ');
    return ListenableBuilder(
      listenable: gestures,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('My gestures')),
        body: gestures.all.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No custom gestures yet.\n\nTap "New gesture" to record one. '
                    'Make it clearly different from the built-in signs ($builtIn).',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final g in gestures.all)
                    ListTile(
                      leading: Icon(g.moving ? Icons.swipe : Icons.back_hand),
                      title: Text(g.malay),
                      subtitle: Text([if (g.english.isNotEmpty) g.english, g.moving ? 'Moving' : 'Still'].join(' · ')),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, g),
                      ),
                    ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => RecordGesturePage(gestures: gestures, session: session))),
          icon: const Icon(Icons.add),
          label: const Text('New gesture'),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CustomGesture g) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${g.malay}"?'),
        content: const Text('Its recordings are deleted too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (delete == true) await gestures.remove(g.id);
  }
}
