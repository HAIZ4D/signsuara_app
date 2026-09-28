import 'package:flutter/material.dart';

import '../app_storage.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

/// What the app shows when it opens: splash → welcome pages (first time only) → the app.
class StartFlow extends StatefulWidget {
  const StartFlow({super.key});

  @override
  State<StartFlow> createState() => _StartFlowState();
}

enum _Stage { splash, onboarding, app }

class _StartFlowState extends State<StartFlow> {
  AppStorage? _storage;
  bool? _seen; // null until storage is read
  var _splashDone = false;

  @override
  void initState() {
    super.initState();
    AppStorage.open().then((storage) {
      if (!mounted) return;
      setState(() {
        _storage = storage;
        _seen = storage.loadOnboardingSeen();
      });
    }).catchError((_) {
      if (mounted) setState(() => _seen = true); // no storage: skip the welcome pages
    });
  }

  _Stage get _stage {
    if (!_splashDone || _seen == null) return _Stage.splash;
    return _seen! ? _Stage.app : _Stage.onboarding;
  }

  void _finishOnboarding() {
    _storage?.saveOnboardingSeen();
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    return AnimatedSwitcher(
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
      child: KeyedSubtree(
        key: ValueKey(stage),
        child: switch (stage) {
          _Stage.splash => SplashScreen(onDone: () => setState(() => _splashDone = true)),
          _Stage.onboarding => OnboardingScreen(onDone: _finishOnboarding),
          _Stage.app => const AppShell(),
        },
      ),
    );
  }
}
