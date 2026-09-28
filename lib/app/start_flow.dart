import 'package:flutter/material.dart';

import '../cloud/account.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

/// What the app shows when it opens: splash → welcome pages (every time) → sign-in (only when
/// nobody is signed in) → the app.
class StartFlow extends StatefulWidget {
  const StartFlow({super.key, required this.account});

  final Account account;

  @override
  State<StartFlow> createState() => _StartFlowState();
}

enum _Stage { splash, onboarding, login, app }

class _StartFlowState extends State<StartFlow> {
  var _stage = _Stage.splash;

  void _go(_Stage stage) => setState(() => _stage = stage);

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return AnimatedSwitcher(
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
      child: KeyedSubtree(
        key: ValueKey(_stage),
        child: switch (_stage) {
          _Stage.splash => SplashScreen(onDone: () => _go(_Stage.onboarding)),
          _Stage.onboarding => OnboardingScreen(onDone: () => _go(account.signedIn ? _Stage.app : _Stage.login)),
          _Stage.login => LoginScreen(account: account, onDone: () => _go(_Stage.app)),
          _Stage.app => AppShell(account: account),
        },
      ),
    );
  }
}
