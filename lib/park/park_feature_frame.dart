import 'package:flutter/material.dart';

import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/widgets/reservation_widgets.dart';
import '../visitor/widgets/visitor_bottom_nav.dart';

class ParkFeatureFrame extends StatelessWidget {
  const ParkFeatureFrame({
    super.key,
    required this.title,
    required this.onTab,
    required this.body,
    this.action,
    this.onBack,
  });

  final String title;
  final ValueChanged<int> onTab;
  final Widget body;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Theme(
    data: reservationTheme(context),
    child: ColoredBox(
      color: queueBackground,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Scaffold(
            backgroundColor: queueBackground,
            appBar: AppBar(
              centerTitle: true,
              toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 23
                  ? 72
                  : null,
              title: Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              leading: BackButton(color: queueRose, onPressed: onBack),
              actions: [?action],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: body,
              ),
            ),
            bottomNavigationBar: VisitorBottomNav(
              selectedIndex: 3,
              onTap: onTab,
            ),
          ),
        ),
      ),
    ),
  );
}
