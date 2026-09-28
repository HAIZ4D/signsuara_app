import 'package:flutter/foundation.dart';

import '../cloud/account.dart';
import 'custom_gestures.dart';
import 'gesture_store.dart';

enum BackupState { off, checking, done, failed }

/// Keeps a copy of the custom gestures in the signed-in Google account and brings them back after
/// a reinstall or on a new phone. The list on the phone stays the one the app uses.
/// - Signing in (or opening the app signed in): gestures only in the account are added to the
///   phone, gestures only on the phone are uploaded.
/// - While signed in: every new gesture is uploaded, every deleted one removed from the account.
/// - While signed out nothing is copied (a gesture deleted then comes back at the next sign-in).
class GestureBackup extends ChangeNotifier {
  GestureBackup({required this.gestures, required this.account});

  final CustomGestures gestures;
  final Account account;

  GestureStore? _store;
  var _inAccount = <String>{}; // gesture ids the account has
  var _synced = false; // the first comparison is done: now phone changes are copied
  var _state = BackupState.off;
  var _restored = 0;
  var _started = false;
  DateTime? _checkedAt;

  BackupState get state => _state;

  /// When the phone and the account were last compared successfully.
  DateTime? get checkedAt => _checkedAt;

  /// Gestures brought back from the account at the last sign-in.
  int get restored => _restored;

  /// The state in plain words, for the Gestures tab and Profile.
  String get summary => switch (_state) {
        BackupState.off => 'Not backed up: sign in to keep your gestures in your Google account.',
        BackupState.checking => 'Checking the backup in your account…',
        BackupState.done => _restored > 0
            ? 'Backed up to your Google account. $_restored brought back from it.'
            : 'Backed up to your Google account.',
        BackupState.failed => 'Backup did not work (internet?). Your gestures are still on this phone.',
      };

  /// Call once the phone's own gestures are loaded, so loading can't undo a restore.
  void start() {
    if (_started) return;
    _started = true;
    gestures.addListener(_mirror);
    account.addListener(_useAccount);
    _useAccount();
  }

  /// Compare the phone and the account again now (e.g. after a failed backup).
  Future<void> syncNow() async {
    final store = _store;
    if (store == null) return;
    _state = BackupState.checking;
    notifyListeners();
    await _sync(store);
  }

  void _useAccount() {
    final store = account.gestureBackup;
    if (identical(store, _store)) return;
    _store = store;
    _inAccount = {};
    _synced = false;
    _restored = 0;
    _checkedAt = null;
    _state = store == null ? BackupState.off : BackupState.checking;
    notifyListeners();
    if (store != null) _sync(store);
  }

  Future<void> _sync(GestureStore store) async {
    try {
      final saved = await store.loadAll();
      if (!identical(store, _store)) return; // signed out meanwhile
      _inAccount = {for (final g in saved) g.id};
      final onPhone = {for (final g in gestures.all) g.id};
      final missing = [for (final g in saved) if (!onPhone.contains(g.id)) g];
      _synced = true;
      for (final g in missing) {
        await gestures.add(g); // already in the account: not uploaded again
      }
      _restored = missing.length;
      _mirror(); // uploads what only the phone has
      if (_state == BackupState.checking) _state = BackupState.done;
      _checkedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      _fail(e);
    }
  }

  /// Copies each change on the phone: new gestures up, deleted ones out of the account.
  void _mirror() {
    final store = _store;
    if (store == null || !_synced) return;
    final onPhone = {for (final g in gestures.all) g.id: g};
    for (final g in onPhone.values) {
      if (_inAccount.add(g.id)) store.save(g).catchError(_fail);
    }
    for (final id in _inAccount.difference(onPhone.keys.toSet())) {
      _inAccount.remove(id);
      store.delete(id).catchError(_fail);
    }
  }

  void _fail(Object e) {
    debugPrint('Gesture backup: $e');
    _state = BackupState.failed;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) {
      gestures.removeListener(_mirror);
      account.removeListener(_useAccount);
    }
    super.dispose();
  }
}
