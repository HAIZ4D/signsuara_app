import 'package:flutter/foundation.dart';

import '../custom/gesture_store.dart';
import '../history/history_store.dart';
import '../listen/note_store.dart';

/// A signed-in Google user: only what the app shows and saves (no tokens).
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.customPhoto = false,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

  /// True when the photo was chosen in Profile (not the Google account's own).
  final bool customPhoto;
}

/// Why sign-in (or changing the name or photo) didn't work, already in plain words for the screen.
class SignInFailure implements Exception {
  const SignInFailure(this.message);

  final String message;
}

/// Where sign-in really happens: Firebase on the phone (firebase_auth_backend.dart), a fake in tests.
abstract class AuthBackend {
  AppUser? get currentUser;

  /// Opens Google's account picker. Null = the user closed it. Throws [SignInFailure].
  Future<AppUser?> signInWithGoogle();

  Future<void> signOut();

  /// Changes the name the app shows for the signed-in user. Throws [SignInFailure].
  Future<AppUser> rename(String name);

  /// Saves [image] (JPEG or PNG) as the signed-in user's photo. Throws [SignInFailure].
  Future<AppUser> setPhoto(Uint8List image);

  /// Goes back to the Google account's own photo. Throws [SignInFailure].
  Future<AppUser> useGooglePhoto();

  /// Where this user's conversations are kept.
  HistoryStore historyFor(AppUser user);

  /// Where this user's custom gestures are backed up.
  GestureStore gesturesFor(AppUser user);

  /// Where this user's Listen notes are kept.
  NoteStore notesFor(AppUser user);
}

/// Who is using the app: a Google account, or a guest (no account, no cloud features).
/// Signing in stays remembered by Firebase until [signOut].
class Account extends ChangeNotifier {
  /// [backend] null = Firebase could not start: guest only.
  Account(this._backend) : _user = _backend?.currentUser;

  final AuthBackend? _backend;
  AppUser? _user;
  _Stores? _cloud; // the signed-in user's stores
  var _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get signedIn => _user != null;
  bool get busy => _busy;

  /// The signed-in user's saved conversations; null for a guest.
  HistoryStore? get history => _stores()?.history;

  /// Where the signed-in user's custom gestures are backed up; null for a guest.
  GestureStore? get gestureBackup => _stores()?.gestures;

  /// The signed-in user's Listen notes; null for a guest.
  NoteStore? get notes => _stores()?.notes;

  _Stores? _stores() {
    final user = _user;
    if (user == null) return null;
    if (_cloud?.uid != user.uid) {
      _cloud = (
        uid: user.uid,
        history: _backend!.historyFor(user),
        gestures: _backend.gesturesFor(user),
        notes: _backend.notesFor(user),
      );
    }
    return _cloud;
  }

  /// The last sign-in problem, or null.
  String? get error => _error;

  /// The name used across the app: the Google account's name, or "Guest".
  String get name {
    final user = _user;
    if (user == null) return 'Guest';
    return user.name.trim().isNotEmpty ? user.name.trim() : user.email.split('@').first;
  }

  /// True when signed in afterwards.
  Future<bool> signIn() async {
    final backend = _backend;
    if (backend == null) {
      _error = 'Sign-in is not available right now. You can continue as a guest.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await backend.signInWithGoogle() ?? _user;
    } on SignInFailure catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      debugPrint('Sign-in failed: $e');
    }
    _busy = false;
    notifyListeners();
    return signedIn;
  }

  /// The longest name accepted (it has to fit the Home greeting).
  static const maxNameLength = 30;

  /// Signed in only: changes the name shown on Home and in Profile. True when it was saved.
  Future<bool> rename(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > maxNameLength) return Future.value(false);
    return _update((b) => b.rename(clean), 'The name could not be changed. Check the internet and try again.');
  }

  /// Signed in only: a new profile photo (JPEG or PNG). True when it was saved.
  Future<bool> setPhoto(Uint8List image) =>
      _update((b) => b.setPhoto(image), 'The photo could not be changed. Check the internet and try again.');

  /// Signed in only: back to the Google account's own photo.
  Future<bool> useGooglePhoto() =>
      _update((b) => b.useGooglePhoto(), 'The photo could not be changed. Check the internet and try again.');

  Future<bool> _update(Future<AppUser> Function(AuthBackend backend) change, String failed) async {
    final backend = _backend;
    if (backend == null || _user == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await change(backend);
    } on SignInFailure catch (e) {
      _error = e.message;
    } catch (e) {
      _error = failed;
      debugPrint('Account change failed: $e');
    }
    _busy = false;
    notifyListeners();
    return _error == null;
  }

  Future<void> signOut() async {
    try {
      await _backend?.signOut();
    } catch (e) {
      debugPrint('Sign-out problem: $e');
    }
    _user = null;
    _error = null;
    notifyListeners();
  }
}

typedef _Stores = ({String uid, HistoryStore history, GestureStore gestures, NoteStore notes});
