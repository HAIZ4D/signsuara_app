import 'package:flutter/material.dart';

import '../../speech/sign_words.dart';
import '../../theme/app_theme.dart';
import 'motion.dart';

/// One chat bubble (design: .bubble). Mine = signed and spoken aloud (turquoise, right), with the
/// other language small below. Theirs = heard (white, left). Tap = [onRepeat] (say it again).
class ChatBubble extends StatelessWidget {
  ChatBubble.signed({super.key, required SignWords words, required SpeechLanguage language, this.onRepeat})
      : me = true,
        text = words.shown(language),
        sub = _otherLanguage(words, language);

  const ChatBubble.heard({super.key, required this.text})
      : me = false,
        sub = null,
        onRepeat = null;

  final bool me;
  final String text;
  final String? sub;
  final VoidCallback? onRepeat;

  static String? _otherLanguage(SignWords words, SpeechLanguage language) {
    final other = words.shown(language == SpeechLanguage.malay ? SpeechLanguage.english : SpeechLanguage.malay);
    return other == words.shown(language) ? null : other;
  }

  @override
  Widget build(BuildContext context) {
    final ink = me ? AppColors.onDark : AppColors.ink;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        gradient: me ? AppGradients.bubbleMe : null,
        color: me ? null : AppColors.surface,
        boxShadow: me ? AppShadows.bubbleMe : AppShadows.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(me ? 22 : 8),
          bottomRight: Radius.circular(me ? 8 : 22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(me ? Icons.waving_hand_rounded : Icons.mic_rounded,
                size: 13, color: me ? AppColors.onDark : AppColors.onYellowInk),
            const SizedBox(width: 5),
            Text(me ? 'SIGNED · SPOKEN ALOUD' : 'HEARD',
                style: AppText.eyebrow.copyWith(
                    fontSize: 10.5, color: me ? AppColors.onDark.withValues(alpha: 0.85) : AppColors.onYellowInk)),
          ]),
          const SizedBox(height: 5),
          Text(text, style: AppText.strong.copyWith(color: ink, fontWeight: FontWeight.w600, height: 1.4)),
          if (sub case final sub?) ...[
            const SizedBox(height: 4),
            Text(sub,
                style: AppText.small.copyWith(
                    color: ink.withValues(alpha: 0.78), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );

    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: me ? Alignment.centerRight : Alignment.centerLeft,
          child: Semantics(
            button: onRepeat != null,
            label: me ? 'You signed: $text${sub == null ? '' : ', $sub'}' : 'They said: $text',
            hint: onRepeat == null ? null : 'Double tap to say it again',
            excludeSemantics: true,
            child: GestureDetector(onTap: onRepeat, child: bubble),
          ),
        ),
      ),
    );
  }
}

/// Small grey pill above the bubbles, e.g. "Today".
class DayChip extends StatelessWidget {
  const DayChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: AppText.eyebrow.copyWith(color: AppColors.inkFaint, letterSpacing: 0.3)),
      );
}
