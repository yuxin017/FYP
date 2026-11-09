import 'dart:convert';
import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/models/park_time.dart';
import '../../attractions/widgets/attraction_cover.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../models/reservation.dart';
import '../../visitor/widgets/visitor_bottom_nav.dart';
import '../../visitor/visitor_main_page.dart';

ThemeData reservationTheme(BuildContext context) => Theme.of(context).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: queueRose,
    primary: queueRose,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: queueBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: queueBackground,
    foregroundColor: queueInk,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
);
String reservationDayLabel(DateTime value) {
  final now = ParkTime.date(DateTime.now());
  return ParkTime.date(value) == now ? 'Today' : ParkTime.date(value);
}

String returnWindow(DateTime start, DateTime end) =>
    '${ParkTime.time(start)}–${ParkTime.time(end)}';
void reservationHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Ride reservations'),
    content: const Text(
      'Choose an available return time and your own admission ticket. Your ticket must cover this visit date and your profile must meet the minimum height. You can reserve different attractions, once each, without overlapping return windows. Arrive during the displayed window.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);

class ReservationPanel extends StatelessWidget {
  const ReservationPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFF1E6E3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class ReservationFrame extends StatelessWidget {
  const ReservationFrame({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onHelp,
    this.helpLabel = 'Reservation help',
    this.navigationIndex = 3,
  });
  final String title;
  final Widget body;
  final Widget? action;
  final VoidCallback? onHelp;
  final String helpLabel;
  final int navigationIndex;
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
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              leading: BackButton(color: queueRose),
              actions: [
                IconButton(
                  tooltip: helpLabel,
                  onPressed: onHelp ?? () => reservationHelp(context),
                  icon: const Icon(Icons.help_outline, color: queueRose),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: body,
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                      child: Align(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 404),
                          child: action,
                        ),
                      ),
                    ),
                  ),
                VisitorBottomNav(
                  selectedIndex: navigationIndex,
                  onTap: (index) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    VisitorMainPage.goTo(context, index);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ReservationButton extends StatelessWidget {
  const ReservationButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: queueRose,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    ),
  );
}

class ReservationSteps extends StatelessWidget {
  const ReservationSteps({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: i == 1
                            ? Colors.transparent
                            : i <= step
                            ? queueRose
                            : Colors.grey.shade300,
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == step ? queueRose : Colors.transparent,
                        border: Border.all(
                          color: i <= step ? queueRose : Colors.grey.shade300,
                        ),
                      ),
                      child: i < step
                          ? const Icon(Icons.check, color: queueRose, size: 19)
                          : Text(
                              '$i',
                              style: TextStyle(
                                color: i == step
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Divider(
                        color: i == 3
                            ? Colors.transparent
                            : i < step
                            ? queueRose
                            : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ['Time', 'Visitor', 'Confirm'][i - 1],
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= step ? queueRose : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class ReservationSummary extends StatelessWidget {
  const ReservationSummary({
    super.key,
    required this.attraction,
    required this.slot,
    this.review = false,
  });
  final Attraction attraction;
  final AttractionSlot slot;
  final bool review;
  @override
  Widget build(BuildContext context) => ReservationPanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AttractionCover(
          encoded: attraction.coverImageBase64,
          width: review ? 100 : 82,
          height: review ? 145 : 100,
          radius: 10,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attraction.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: queueInk,
                ),
              ),
              const SizedBox(height: 13),
              _line(
                Icons.calendar_today_outlined,
                reservationDayLabel(slot.startsAt),
              ),
              const SizedBox(height: 10),
              _line(
                Icons.schedule,
                'Return  ${returnWindow(slot.startsAt, slot.endsAt)}',
                rose: true,
              ),
              if (review) ...[
                const SizedBox(height: 10),
                _line(Icons.person_outline, '1 visitor'),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  Widget _line(IconData icon, String text, {bool rose = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: const Color(0xFF7A838A)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: rose ? queueRose : const Color(0xFF59656D),
          ),
        ),
      ),
    ],
  );
}

class VisitorAvatar extends StatelessWidget {
  const VisitorAvatar({super.key, required this.visitor});
  final ReservationVisitor visitor;
  @override
  Widget build(BuildContext context) {
    ImageProvider? photo;
    try {
      if (visitor.photo?.isNotEmpty == true) {
        photo = MemoryImage(base64Decode(visitor.photo!.split(',').last));
      }
    } catch (_) {
      photo = null;
    }
    return CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFFF1E5E1),
      backgroundImage: photo,
      child: photo == null
          ? Text(
              visitor.name.trim().isEmpty ? 'Y' : visitor.name.trim()[0],
              style: const TextStyle(color: queueRose),
            )
          : null,
    );
  }
}
