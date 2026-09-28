import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cloud/account.dart';
import '../speech/sign_words.dart';
import 'conversation_log.dart';
import 'history_store.dart';
import 'saved_conversation.dart';

/// Saves what the chat shows (ConversationLog) as conversations, and keeps the newest ones for Home.
/// Signed in: the account's store (Firestore, kept). Guest: memory, kept until the app closes.
///
/// A new conversation starts with the first message after the app opens, after the chat is
/// cleared, or after [quietGap] without messages.
class ConversationHistory extends ChangeNotifier {
  ConversationHistory({required this.log, required this.account, required this.words}) {
    log.addListener(_onLog);
    account.addListener(_useStore);
    _useStore();
  }

  static const quietGap = Duration(minutes: 5);

  final ConversationLog log;
  final Account account;
  final SignWords Function(String label) words;

  final _guest = MemoryHistoryStore();
  HistoryStore? _store;
  StreamSubscription<List<SavedConversation>>? _watching;
  List<SavedConversation> _recent = const [];

  final _wordsAtSign = Expando<SignWords>(); // per message: its words when it was signed
  String? _id; // the conversation being written, null = the next message starts one
  var _from = 0; // its first message in the log
  var _seen = 0; // log messages already looked at

  /// Newest first (up to 50).
  List<SavedConversation> get recent => _recent;

  /// True when conversations are kept after the app closes (signed in).
  bool get kept => account.signedIn;

  void _useStore() {
    final store = account.history ?? _guest;
    if (identical(store, _store)) return;
    _store = store;
    _watching?.cancel();
    _recent = const [];
    _watching = store.watch().listen((list) {
      _recent = list;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Conversation history not loaded: $e'));
    _save(); // e.g. signed in during a conversation: it continues in the account
    notifyListeners();
  }

  void _onLog() {
    final all = log.messages;
    if (all.isEmpty) {
      _id = null; // cleared: the next message starts a new conversation
      _from = _seen = 0;
      return;
    }
    if (all.length > _seen) {
      final first = all[_seen];
      final quiet = _seen > 0 && first.at.difference(all[_seen - 1].at) >= quietGap;
      if (_id == null || quiet) {
        _id = '${first.at.microsecondsSinceEpoch}';
        _from = _seen;
      }
    }
    _seen = all.length;
    _save();
  }

  void _save() {
    final id = _id;
    if (id == null) return;
    final messages = [
      for (final m in log.messages.skip(_from))
        if (m.label case final label?)
          SavedMessage.signed(label, _wordsAtSign[m] ??= words(label), m.at)
        else
          SavedMessage.heard(m.text, m.at),
    ];
    _store?.save(SavedConversation(id, messages)).catchError((Object e) => debugPrint('Conversation not saved: $e'));
  }

  Future<void> delete(String id) async {
    // Deleting the conversation still being written: later messages start a new one,
    // so the deleted lines are never saved again.
    if (id == _id) _id = null;
    await _store?.delete(id);
  }

  /// Deletes every saved conversation (in the account when signed in).
  Future<void> deleteAll() async {
    _id = null;
    await _store?.deleteAll();
  }

  @override
  void dispose() {
    log.removeListener(_onLog);
    account.removeListener(_useStore);
    _watching?.cancel();
    super.dispose();
  }
}
