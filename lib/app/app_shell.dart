import 'package:flutter/material.dart';

import '../custom/custom_gestures_page.dart';
import '../home_page.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/capsule_nav.dart';
import 'app_services.dart';

/// The 5 tabs + floating capsule nav. Owns the shared [AppServices] (one glove connection).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final services = AppServices();
  var _tab = 0;

  static const _items = [
    NavItem('Home', Icons.home_rounded),
    NavItem('Conversation', Icons.chat_bubble_outline_rounded),
    NavItem('Hearing', Icons.volume_up_rounded, sun: true),
    NavItem('Gestures', Icons.back_hand_outlined),
    NavItem('Learn', Icons.school_outlined),
  ];

  @override
  void initState() {
    super.initState();
    services.start();
  }

  @override
  void dispose() {
    services.dispose();
    super.dispose();
  }

  void _go(int tab) => setState(() => _tab = tab);

  /// Old screens (until they are redesigned) get room for the floating nav.
  Widget _legacy(Widget child) =>
      Builder(builder: (context) => Padding(padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)), child: child));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                services: services,
                onOpenTab: _go,
                onOpenProfile: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ProfileScreen(name: services.userName)),
                ),
              ),
              _legacy(HomePage(services: services)), // Conversation: redesigned in step 2
              _legacy(HomePage(services: services)), // Hearing: redesigned in step 3
              _legacy(CustomGesturesPage(gestures: services.gestures, session: services.session)), // step 4
              const LearnScreen(),
            ],
          ),
          Positioned(
            left: AppSpace.navMargin,
            right: AppSpace.navMargin,
            bottom: AppSpace.navMargin + MediaQuery.paddingOf(context).bottom,
            child: CapsuleNav(items: _items, current: _tab, onTap: _go),
          ),
        ],
      ),
    );
  }
}
