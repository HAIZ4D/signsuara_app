import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/cloud/account.dart';

import 'fake_auth_backend.dart';

void main() {
  test('a guest is called Guest; a Google user by their name (or email without a name)', () async {
    expect(Account(FakeAuthBackend()).name, 'Guest');
    expect(Account(FakeAuthBackend(currentUser: testUser)).name, 'Test User');
    const noName = AppUser(uid: 'u2', name: ' ', email: 'aina.k@example.com');
    expect(Account(FakeAuthBackend(currentUser: noName)).name, 'aina.k');
  });

  test('sign in, then sign out', () async {
    final backend = FakeAuthBackend();
    final account = Account(backend);
    expect(await account.signIn(), isTrue);
    expect(account.user?.email, 'test.user@example.com');
    expect(account.busy, isFalse);

    await account.signOut();
    expect(account.signedIn, isFalse);
    expect(backend.signOuts, 1);
  });

  test('closing the account picker is not an error', () async {
    final account = Account(FakeAuthBackend(next: null));
    expect(await account.signIn(), isFalse);
    expect(account.error, isNull);
  });

  test('a sign-in problem is kept in plain words; the next try clears it', () async {
    final backend = FakeAuthBackend(failure: const SignInFailure('No internet connection.'));
    final account = Account(backend);
    expect(await account.signIn(), isFalse);
    expect(account.error, 'No internet connection.');
    expect(account.busy, isFalse);

    backend.failure = null;
    expect(await account.signIn(), isTrue);
    expect(account.error, isNull);
  });

  test('without Firebase the app is guest-only and says so', () async {
    final account = Account(null);
    expect(await account.signIn(), isFalse);
    expect(account.error, contains('continue as a guest'));
  });
}
