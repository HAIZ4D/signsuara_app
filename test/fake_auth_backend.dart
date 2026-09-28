import 'package:signsuara_app/cloud/account.dart';
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

  @override
  Future<void> signOut() async {
    currentUser = null;
    signOuts++;
  }
}
