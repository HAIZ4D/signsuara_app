import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../custom/gesture_store.dart';
import '../history/history_store.dart';
import '../listen/note_store.dart';
import 'account.dart';
import 'firestore_gesture_store.dart';
import 'firestore_history_store.dart';
import 'firestore_note_store.dart';

/// Google sign-in through Firebase: the ONLY file using firebase_core, firebase_auth,
/// google_sign_in and firebase_storage (profile photos). Firestore is used here for the profile,
/// and in firestore_history_store.dart and firestore_gesture_store.dart.
/// Settings come from android/app/google-services.json (see README "Firebase setup").
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend._();

  /// Starts Firebase. Null when it can't start (the app then runs as guest only).
  static Future<FirebaseAuthBackend?> start() async {
    try {
      await Firebase.initializeApp();
      return FirebaseAuthBackend._();
    } catch (e) {
      debugPrint('Firebase not available: $e');
      return null;
    }
  }

  static const _noInternet = 'No internet connection. Connect and try again, or continue as a guest.';

  final _auth = FirebaseAuth.instance;
  Future<void>? _googleReady;

  // The Google client ID is read from google-services.json, so nothing is written in the code.
  Future<void> _google() => _googleReady ??= GoogleSignIn.instance.initialize();

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      await _google();
      final account = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
      final signedIn = (await _auth.signInWithCredential(credential)).user;
      if (signedIn != null) await _restoreChosenProfile(signedIn);
      final user = _toAppUser(_auth.currentUser);
      if (user != null) unawaited(_saveProfile(user)); // never makes sign-in wait
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null; // closed the picker: no error
      debugPrint('Google sign-in: ${e.code} ${e.description}');
      throw SignInFailure(switch (e.code) {
        GoogleSignInExceptionCode.interrupted => 'Sign-in was interrupted. Please try again.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not set up for this app build yet (Firebase: SHA-1 and google-services.json).',
        _ => 'Google sign-in failed. Check the internet and that the phone has a Google account.',
      });
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase sign-in: ${e.code} ${e.message}');
      throw SignInFailure(e.code == 'network-request-failed' ? _noInternet : 'Sign-in failed (${e.code}).');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _google();
    await GoogleSignIn.instance.signOut(); // next sign-in shows the account picker again
  }

  @override
  Future<AppUser> rename(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw const SignInFailure('Sign in first.');
    try {
      await user.updateDisplayName(name);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      debugPrint('Rename: ${e.code} ${e.message}');
      throw SignInFailure(e.code == 'network-request-failed'
          ? 'No internet connection. The name was not changed.'
          : 'The name could not be changed (${e.code}).');
    }
    _saveChoice(user.uid, {'name': name, 'username': name});
    return _toAppUser(_auth.currentUser)!;
  }

  @override
  Future<AppUser> setPhoto(Uint8List image) async {
    final user = _auth.currentUser;
    if (user == null) throw const SignInFailure('Sign in first.');
    final old = user.photoURL;
    try {
      // A new file each time, so no phone shows an old cached photo. The gallery can give PNG too.
      final png = image.length > 4 && image[0] == 0x89 && image[1] == 0x50 && image[2] == 0x4E && image[3] == 0x47;
      final file = FirebaseStorage.instance
          .ref('users/${user.uid}/photos/${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}');
      await file.putData(image, SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'));
      final url = await file.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      _saveChoice(user.uid, {'photoUrl': url, 'customPhotoUrl': url});
    } on FirebaseException catch (e) {
      debugPrint('Photo: ${e.plugin} ${e.code} ${e.message}');
      throw SignInFailure(_photoProblem(e.code));
    }
    if (old != null) unawaited(_deleteUploaded(old));
    return _toAppUser(_auth.currentUser)!;
  }

  @override
  Future<AppUser> useGooglePhoto() async {
    final user = _auth.currentUser;
    if (user == null) throw const SignInFailure('Sign in first.');
    final old = user.photoURL;
    final google = _googlePhoto(user);
    try {
      await user.updatePhotoURL(google);
      await user.reload();
    } on FirebaseException catch (e) {
      debugPrint('Photo: ${e.plugin} ${e.code} ${e.message}');
      throw SignInFailure(_photoProblem(e.code));
    }
    _saveChoice(user.uid, {'photoUrl': google, 'customPhotoUrl': FieldValue.delete()});
    if (old != null) unawaited(_deleteUploaded(old));
    return _toAppUser(_auth.currentUser)!;
  }

  static String _photoProblem(String code) => switch (code) {
        'network-request-failed' || 'retry-limit-exceeded' => 'No internet connection. The photo was not changed.',
        'unauthorized' => 'Not allowed to save the photo: check the Firebase Storage rules (README "Firebase setup").',
        'bucket-not-found' || 'project-not-found' || 'object-not-found' =>
          'Firebase Storage is not set up yet (README "Firebase setup").',
        _ => 'The photo could not be changed ($code).',
      };

  /// Removes a photo this app uploaded before (never the Google photo). Failure is only logged.
  Future<void> _deleteUploaded(String url) async {
    if (!url.contains('firebasestorage')) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Old photo not deleted: $e');
    }
  }

  /// The Google account's own photo (Firebase keeps it per sign-in provider).
  static String? _googlePhoto(User user) =>
      [for (final p in user.providerData) if (p.providerId == 'google.com') p.photoURL].firstOrNull;

  /// Keeps the user's choice in Firestore too, so it can be put back after a later sign-in.
  void _saveChoice(String uid, Map<String, Object?> fields) => unawaited(_profile(uid)
      .set(fields, SetOptions(merge: true))
      .catchError((Object e) => debugPrint('Profile choice not saved to Firestore: $e')));

  /// A Google sign-in may set the Firebase name and photo back to the Google ones: put back what
  /// the user chose in Profile (users/{uid}.username / customPhotoUrl). Any problem: keep Google's.
  Future<void> _restoreChosenProfile(User user) async {
    try {
      final saved = (await _profile(user.uid).get().timeout(const Duration(seconds: 3))).data();
      final name = saved?['username'];
      final photo = saved?['customPhotoUrl'];
      var changed = false;
      if (name is String && name.isNotEmpty && name != user.displayName) {
        await user.updateDisplayName(name);
        changed = true;
      }
      if (photo is String && photo.isNotEmpty && photo != user.photoURL) {
        await user.updatePhotoURL(photo);
        changed = true;
      }
      if (changed) await user.reload();
    } catch (e) {
      debugPrint('Chosen name or photo not restored: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  @override
  HistoryStore historyFor(AppUser user) => FirestoreHistoryStore(user.uid);

  @override
  GestureStore gesturesFor(AppUser user) => FirestoreGestureStore(user.uid);

  @override
  NoteStore notesFor(AppUser user) => FirestoreNoteStore(user.uid);

  /// Saves users/{uid}: name, email, photo, first and last sign-in. A failed write is only logged
  /// (e.g. Firestore rules not set yet): the app works the same without it.
  Future<void> _saveProfile(AppUser user) async {
    try {
      final doc = _profile(user.uid);
      final isNew = !(await doc.get()).exists;
      await doc.set({
        'name': user.name,
        'email': user.email,
        'photoUrl': user.photoUrl,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Profile not saved to Firestore: $e');
    }
  }

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          customPhoto: user.photoURL != null && user.photoURL != _googlePhoto(user),
        );
}
