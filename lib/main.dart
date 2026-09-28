import 'package:flutter/material.dart';

import 'app/start_flow.dart';
import 'cloud/account.dart';
import 'cloud/firebase_auth_backend.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SignSuaraApp(account: Account(await FirebaseAuthBackend.start())));
}

class SignSuaraApp extends StatelessWidget {
  const SignSuaraApp({super.key, required this.account});

  /// Google account or guest. Tests pass one with a fake backend (Firebase never starts in tests).
  final Account account;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SignSuara',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: StartFlow(account: account),
      );
}
