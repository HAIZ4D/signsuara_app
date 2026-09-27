import 'package:flutter/material.dart';

import 'home_page.dart';

void main() => runApp(const SignSuaraApp());

class SignSuaraApp extends StatelessWidget {
  const SignSuaraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SignSuara',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomePage(),
      );
}
