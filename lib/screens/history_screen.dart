import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../history/saved_conversation.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/chat_bubble.dart';
import '../ui/widgets/conversation_tile.dart';

/// All saved conversations, newest first. Tap one to read it back.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Conversations')),
      body: ListenableBuilder(
        listenable: services.changes,
        builder: (context, _) {
          final all = services.history.recent;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
            children: [
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('No conversations yet.',
                      textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkFaint)),
                ),
              for (final c in all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ConversationTile(
                    conversation: c,
                    language: services.speaker.language,
                    onTap: () => openConversation(context, services, c),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s),
                child: Text(keptNote(services),
                    textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.inkFaint)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Where the conversations are kept, in one honest sentence.
String keptNote(AppServices services) => services.history.kept
    ? 'Saved to your Google account (the newest 50 are shown).'
    : 'As a guest, conversations are kept only until the app closes. Sign in to save them.';

void openConversation(BuildContext context, AppServices services, SavedConversation conversation) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PastConversationScreen(services: services, conversation: conversation),
    ));

/// One saved conversation read back as bubbles (read-only), with Delete.
class PastConversationScreen extends StatelessWidget {
  const PastConversationScreen({super.key, required this.services, required this.conversation});

  final AppServices services;
  final SavedConversation conversation;

  Future<void> _delete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text(services.history.kept
            ? 'It is removed from your Google account. This cannot be undone.'
            : 'It is removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    await services.history.delete(conversation.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final language = services.speaker.language;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(dayName(conversation.startedAt)),
        actions: [
          IconButton(
            tooltip: 'Delete conversation',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, AppSpace.xxl),
        children: [
          Center(child: DayChip(dayAndTime(conversation.startedAt))),
          for (final m in conversation.messages)
            if (m.words case final words?)
              ChatBubble.signed(words: words, language: language)
            else
              ChatBubble.heard(text: m.text),
        ],
      ),
    );
  }
}
