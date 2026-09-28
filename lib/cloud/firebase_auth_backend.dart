import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../custom/gesture_store.dart';
import '../history/history_store.dart';
import 'account.dart';
import 'firestore_gesture_store.dart';
import 'firestore_history_store.dart';

/// Google sign-in through Firebase: the ONLY file using firebase_core, firebase_auth and
/// google_sign_in. Firestore is used here for the profile, and in firestore_history_store.dart and
/// firestore_gesture_store.dart.
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
      final user = _toAppUser((await _auth.signInWithCredential(credential)).user);
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
  HistoryStore historyFor(AppUser user) => FirestoreHistoryStore(user.uid);

  @override
  GestureStore gesturesFor(AppUser user) => FirestoreGestureStore(user.uid);

  /// Saves users/{uid}: name, email, photo, first and last sign-in. A failed write is only logged
  /// (e.g. Firestore rules not set yet): the app works the same without it.
  Future<void> _saveProfile(AppUser user) async {
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
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
      : AppUser(uid: user.uid, name: user.displayName ?? '', email: user.email ?? '', photoUrl: user.photoURL);
}
