import 'package:flutter/material.dart';
import '../models/tickets.dart';
import '../services/ticket_currency.dart';
export '../services/ticket_currency.dart' show ticketDisplayPrice;

const ticketRose = Color(0xFFA54348);
const ticketMutedRose = Color(0xFFAD7472);
const ticketInk = Color(0xFF10222E);
const ticketBackground = Color(0xFFFCF7F5);
const ticketBorder = Color(0xFFEBDDD9);
const ticketMuted = Color(0xFF5C6268);

class TicketSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const TicketSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ticketBorder),
    ),
    child: child,
  );
}

class TicketButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  const TicketButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.outlined = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: ticketRose,
                side: const BorderSide(color: ticketRose),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: content,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: ticketRose,
                disabledBackgroundColor: const Color(0xFFDEC3C3),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: content,
            ),
    );
  }
}

class TicketStepper extends StatelessWidget {
  final int step;
  const TicketStepper(this.step, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: i <= step ? ticketRose : Colors.grey.shade400,
              ),
            ),
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? ticketRose : Colors.transparent,
              border: Border.all(color: i <= step ? ticketRose : Colors.grey),
            ),
            child: i < step
                ? const Icon(Icons.check, size: 17, color: ticketRose)
                : Text(
                    '$i',
                    style: TextStyle(
                      color: i == step ? Colors.white : ticketRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            ['Guests', 'Review', 'Payment'][i - 1],
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class TicketCounter extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? minus, plus;
  const TicketCounter({
    super.key,
    required this.label,
    required this.value,
    this.minus,
    this.plus,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(Icons.remove, minus, 'Fewer $label'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '$value',
          key: Key('count-$label'),
          style: const TextStyle(fontSize: 17),
        ),
      ),
      _button(Icons.add, plus, 'More $label'),
    ],
  );
  Widget _button(IconData icon, VoidCallback? onTap, String tooltip) =>
      SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ticketBorder),
            ),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 19),
        ),
      );
}

class TicketLineSummary extends StatelessWidget {
  final TicketCartLine line;
  final bool showTotal;
  const TicketLineSummary(this.line, {super.key, this.showTotal = false});
  @override
  Widget build(BuildContext context) => TicketSurface(
    padding: EdgeInsets.zero,
    child: Row(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          child: Image.asset(
            line.imageAsset,
            width: 125,
            height: 125,
            fit: BoxFit.cover,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.packageName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TicketMeta(
                  Icons.calendar_today_outlined,
                  displayParkDate(line.visitDate),
                ),
                const SizedBox(height: 6),
                TicketMeta(Icons.people_outline, line.guestSummary),
                if (showTotal) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      ticketDisplayPrice(context, line.subtotal),
                      style: const TextStyle(
                        color: ticketRose,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class TicketMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const TicketMeta(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: ticketMutedRose),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: ticketMuted, fontSize: 13),
        ),
      ),
    ],
  );
}

class TicketBadge extends StatelessWidget {
  final String text;
  final bool green;
  const TicketBadge(this.text, {super.key, this.green = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: green ? const Color(0xFFEAF3E7) : const Color(0xFFF6EAE7),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: green ? const Color(0xFF24652A) : ticketMutedRose,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class PerforatedTicket extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PerforatedTicket({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => PhysicalShape(
    clipper: _TicketClipper(),
    color: Colors.white,
    elevation: 2,
    shadowColor: const Color(0x33664444),
    child: Padding(padding: padding, child: child),
  );
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (double y = 32; y < size.height - 16; y += 28) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addOval(Rect.fromCircle(center: Offset(0, y), radius: 5)),
      );
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()
          ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: 5)),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => false;
}
