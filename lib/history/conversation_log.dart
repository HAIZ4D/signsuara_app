import 'package:flutter/foundation.dart';

enum Side { me, them }

/// One line of the conversation: something I signed ([label] = model/custom label) or
/// something the hearing person said ([text]).
class ChatMessage {
  ChatMessage.signed(String this.label) : side = Side.me, text = '', at = DateTime.now();
  ChatMessage.heard(this.text) : side = Side.them, label = null, at = DateTime.now();

  final Side side;
  final String? label;
  String text; // heard text can still grow until the next listen starts
  final DateTime at;
}

/// The conversation shown as chat bubbles. UI-level only: fed from outside by the signed-label
/// callback and by the transcriber's state, so recognition and speech code stay unchanged.
class ConversationLog extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  ChatMessage? _openHeard; // Android can deliver the final words just AFTER listening stops
  String? _logged; // transcriber text already logged for the current listen
  var _wasListening = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addSigned(String label) {
    _messages.add(ChatMessage.signed(label));
    notifyListeners();
  }

  /// Something the hearing person said without the mic (e.g. a quick-reply button).
  void addHeard(String text) {
    _openHeard = null;
    _messages.add(ChatMessage.heard(text));
    notifyListeners();
  }

  /// Call whenever the transcriber changes. A new listen closes the previous heard message;
  /// when not listening, the heard text is added (or the open message updated).
  void transcript({required bool listening, required String text}) {
    if (listening && !_wasListening) {
      _openHeard = null;
      _logged = null;
    }
    _wasListening = listening;
    final words = text.trim();
    if (listening || words.isEmpty || words == _logged) return;
    final open = _openHeard;
    if (open != null) {
      open.text = words;
    } else if (_logged == null) {
      _messages.add(_openHeard = ChatMessage.heard(words));
    } else {
      return; // this listen's message was closed (quick reply / clear): never re-add old text
    }
    _logged = words;
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    _openHeard = null;
    notifyListeners();
  }
}
