import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/tickets_page.dart';
import 'pages/map_page.dart';
import 'pages/queue_page.dart';
import 'pages/profile_page.dart';
import 'widgets/visitor_bottom_nav.dart';

class VisitorMainPage extends StatefulWidget {
  static void goTo(BuildContext context, int index) =>
      _VisitorMainPageState.goTo(context, index);
  static void openTickets(BuildContext context, String section) =>
      _VisitorMainPageState.openTickets(context, section);
  static void openTicketOrder(BuildContext context, String orderId) =>
      _VisitorMainPageState.openTicketOrder(orderId);
  const VisitorMainPage({super.key});

  @override
  State<VisitorMainPage> createState() => _VisitorMainPageState();
}

class _VisitorMainPageState extends State<VisitorMainPage> {
  static void openTicketOrder(String orderId) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._ticketsKey.currentState?.openOrder(orderId);
    state._onTabSelected(1, resetTickets: false);
  }

  final _ticketsKey = GlobalKey<TicketsPageState>();
  static void openTickets(BuildContext context, String section) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._ticketsKey.currentState?.showSection(section);
    state._onTabSelected(1, resetTickets: false);
  }

  static _VisitorMainPageState? _active;
  static void goTo(BuildContext context, int index) {
    final state = _active;
    if (state != null && state.mounted) state._onTabSelected(index);
  }

  @override
  void initState() {
    super.initState();
    _active = this;
  }

  @override
  void dispose() {
    if (identical(_active, this)) _active = null;
    _startPlace.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;
  final _startPlace = ValueNotifier<String?>(null);

  late final List<Widget> _pages = [
    HomePage(),
    TicketsPage(key: _ticketsKey),
    MapPage(startPlace: _startPlace),
    QueuePage(startPlace: _startPlace),
    ProfilePage(),
  ];

  void _onTabSelected(int index, {bool resetTickets = true}) {
    if (_ticketsKey.currentState?.journey.busy == true) return;
    if (index == 1 && resetTickets) {
      _ticketsKey.currentState?.showSection('hub');
    }
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFDF4EF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Scaffold(
            backgroundColor: const Color(0xFFFDF4EF),
            body: IndexedStack(index: _selectedIndex, children: _pages),
            bottomNavigationBar: VisitorBottomNav(
              selectedIndex: _selectedIndex,
              onTap: _onTabSelected,
            ),
          ),
        ),
      ),
    );
  }
}
