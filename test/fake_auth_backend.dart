import 'package:flutter/foundation.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/gesture_store.dart';
import 'package:signsuara_app/history/history_store.dart';

const testUser = AppUser(uid: 'u1', name: 'Test User', email: 'test.user@example.com');

/// Stands in for Firebase + Google in tests: [next] is what the account picker "returns"
/// (null = the user closed it), [failure] makes sign-in fail.
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({this.currentUser, this.next = testUser, this.failure});

  @override
  AppUser? currentUser;
  AppUser? next;
  SignInFailure? failure;
  var signOuts = 0;

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (failure case final failure?) throw failure;
    return currentUser = next;
  }

  /// One in-memory "cloud" store per account.
  final stores = <String, MemoryHistoryStore>{};

  @override
  HistoryStore historyFor(AppUser user) => stores.putIfAbsent(user.uid, MemoryHistoryStore.new);

  /// One in-memory gesture backup per account.
  final gestureStores = <String, FakeGestureStore>{};

  @override
  GestureStore gesturesFor(AppUser user) => gestureStores.putIfAbsent(user.uid, FakeGestureStore.new);

  /// Makes the next rename fail.
  SignInFailure? renameFailure;

  /// Makes the next photo change fail.
  SignInFailure? photoFailure;
  var photosUploaded = 0;

  @override
  Future<AppUser> setPhoto(Uint8List image) async {
    if (photoFailure case final failure?) throw failure;
    final user = currentUser!;
    photosUploaded++;
    return currentUser = AppUser(
        uid: user.uid,
        name: user.name,
        email: user.email,
        photoUrl: 'https://example.com/photo-$photosUploaded.jpg',
        customPhoto: true);
  }

  @override
  Future<AppUser> useGooglePhoto() async {
    if (photoFailure case final failure?) throw failure;
    final user = currentUser!;
    return currentUser = AppUser(uid: user.uid, name: user.name, email: user.email);
  }

  @override
  Future<AppUser> rename(String name) async {
    if (renameFailure case final failure?) throw failure;
    final user = currentUser!;
    return currentUser = AppUser(uid: user.uid, name: name, email: user.email, photoUrl: user.photoUrl);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    signOuts++;
  }
}

/// A gesture backup in memory. It keeps the database maps, so the conversion is tested too.
/// [failing] makes every call fail (e.g. no permission).
class FakeGestureStore implements GestureStore {
  final saved = <String, Map<String, Object?>>{};
  var failing = false;

  void _check() {
    if (failing) throw StateError('backup unavailable');
  }

  @override
  Future<List<CustomGesture>> loadAll() async {
    _check();
    return [for (final e in saved.entries) gestureFromBackup(e.key, e.value)!];
  }

  @override
  Future<void> save(CustomGesture gesture) async {
    _check();
    saved[gesture.id] = gestureToBackup(gesture);
  }

  @override
  Future<void> delete(String id) async {
    _check();
    saved.remove(id);
  }
}
