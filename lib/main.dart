import 'package:flutter/material.dart';

import 'app/start_flow.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SignSuaraApp());

class SignSuaraApp extends StatelessWidget {
  const SignSuaraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SignSuara',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const StartFlow(),
      );
}
