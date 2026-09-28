import '../speech/sign_words.dart';
import 'conversation_log.dart';

/// One saved line. Signed: the label and its words at that moment (so it still reads right if a
/// custom sign is deleted later). Heard: the words as heard.
class SavedMessage {
  const SavedMessage.signed(String this.label, SignWords this.words, this.at) : side = Side.me, text = '';
  const SavedMessage.heard(this.text, this.at) : side = Side.them, label = null, words = null;

  final Side side;
  final String? label;
  final SignWords? words;
  final String text;
  final DateTime at;

  /// What the bubble shows in [language].
  String shown(SpeechLanguage language) => words?.shown(language) ?? text;
}

/// One conversation: from its first message until the chat is cleared, the app closes, or it was
/// quiet for a while (see ConversationHistory).
class SavedConversation {
  SavedConversation(this.id, this.messages) : assert(messages.isNotEmpty);

  final String id;
  final List<SavedMessage> messages;

  DateTime get startedAt => messages.first.at;
  DateTime get updatedAt => messages.last.at;

  /// For the database (README "Firebase setup"). Times stay DateTime: Firestore stores them as
  /// timestamps.
  Map<String, Object?> toMap() => {
        'startedAt': startedAt,
        'updatedAt': updatedAt,
        'messages': [
          for (final m in messages)
            if (m.words case final words?)
              {'who': 'me', 'label': m.label, 'malay': words.malay, 'english': words.english, 'at': m.at}
            else
              {'who': 'them', 'text': m.text, 'at': m.at},
        ],
      };

  /// The opposite of [toMap]. [time] turns a stored time back into a DateTime (Firestore gives
  /// timestamps). Damaged data gives null: skipped, never a crash.
  static SavedConversation? fromMap(String id, Map<String, Object?> map,
      {DateTime Function(Object? stored) time = _asDateTime}) {
    try {
      final messages = [
        for (final m in (map['messages'] as List).cast<Map<Object?, Object?>>())
          m['who'] == 'me'
              ? SavedMessage.signed(
                  m['label'] as String, SignWords(m['malay'] as String, m['english'] as String), time(m['at']))
              : SavedMessage.heard(m['text'] as String, time(m['at'])),
      ];
      return messages.isEmpty ? null : SavedConversation(id, messages);
    } catch (_) {
      return null;
    }
  }

  static DateTime _asDateTime(Object? stored) => stored as DateTime;
}
