
import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/tickets_page.dart';
import 'pages/map_page.dart';
import 'pages/queue_page.dart';
import 'pages/profile_page.dart';
import 'widgets/visitor_bottom_nav.dart';

class VisitorMainPage extends StatefulWidget {
  static void goTo(BuildContext context, int index) => _VisitorMainPageState.goTo(context, index);
  const VisitorMainPage({super.key});

  @override
  State<VisitorMainPage> createState() => _VisitorMainPageState();
}

class _VisitorMainPageState extends State<VisitorMainPage> {
  static _VisitorMainPageState? _active;
  static void goTo(BuildContext context, int index) {
    final state = _active;
    if (state != null && state.mounted) state._onTabSelected(index);
  }
  @override void initState() { super.initState(); _active = this; }
  @override void dispose() { if (identical(_active, this)) _active = null; super.dispose(); }

  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    TicketsPage(),
    MapPage(),
    QueuePage(),
    ProfilePage(),
  ];

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EF),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: VisitorBottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
