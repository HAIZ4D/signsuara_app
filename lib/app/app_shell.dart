import 'package:flutter/material.dart';

import '../cloud/account.dart';
import '../custom/custom_gestures_page.dart';
import '../screens/conversation_screen.dart';
import '../screens/hearing_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/capsule_nav.dart';
import 'app_services.dart';

/// The 5 tabs + floating capsule nav. Owns the shared [AppServices] (one glove connection).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.account});

  final Account account;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final services = AppServices(account: widget.account);
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
                  MaterialPageRoute<void>(builder: (_) => ProfileScreen(account: services.account)),
                ),
              ),
              ConversationScreen(services: services),
              HearingScreen(services: services),
              CustomGesturesPage(gestures: services.gestures, session: services.session, ble: services.ble),
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
