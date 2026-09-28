import 'package:flutter/material.dart';

import '../../history/conversation_log.dart';
import '../../history/saved_conversation.dart';
import '../../speech/sign_words.dart';
import '../../theme/app_theme.dart';
import '../time_label.dart';

/// A saved conversation in a list (design: home.jsx .hx-ri): when it started, how many messages,
/// and the last line. Yellow = it ended with my sign, turquoise = with their words.
class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation, required this.language, required this.onTap});

  final SavedConversation conversation;
  final SpeechLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conversation.messages.last;
    final mine = last.side == Side.me;
    final count = conversation.messages.length;
    final when = dayAndTime(conversation.startedAt);
    final messages = '$count ${count == 1 ? 'message' : 'messages'}';
    final line = '${mine ? 'You' : 'They'}: ${last.shown(language)}';
    return Semantics(
      button: true,
      label: 'Conversation, $when, $messages. Last: $line',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: mine ? AppColors.yellow : AppColors.turq,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(mine ? Icons.waving_hand_rounded : Icons.mic_rounded,
                        size: 20, color: mine ? AppColors.onYellow : AppColors.onDark),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(when,
                                  style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 14.5),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: AppSpace.s),
                            Text(messages, style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(color: AppColors.inkSoft, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
