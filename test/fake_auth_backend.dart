import 'package:signsuara_app/cloud/account.dart';

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

  @override
  Future<void> signOut() async {
    currentUser = null;
    signOuts++;
  }
}
