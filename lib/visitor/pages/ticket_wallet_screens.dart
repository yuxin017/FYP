import 'package:flutter/material.dart';
import '../../device/nfc_pass.dart';
import '../../device/screen_brightness.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/tickets.dart';
import '../services/ticket_journey.dart';
import '../services/ticket_receipt.dart';
import '../widgets/ticket_widgets.dart';
import 'tickets_page.dart';

class MyTicketsScreen extends StatefulWidget {
  final TicketJourney journey;
  final VoidCallback onBuy, onScan, onHistory;
  final ValueChanged<List<ParkTicket>> onOpen;
  const MyTicketsScreen({
    super.key,
    required this.journey,
    required this.onBuy,
    required this.onScan,
    required this.onHistory,
    required this.onOpen,
  });
  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  String filter = 'Upcoming';
  @override
  Widget build(BuildContext context) {
    final tickets = widget.journey.tickets
        .where((t) => t.filter == filter)
        .toList();
    final groups = <String, List<ParkTicket>>{};
    for (final ticket in tickets) {
      groups
          .putIfAbsent('${ticket.orderId}:${ticket.visitDate}', () => [])
          .add(ticket);
    }
    return TicketPageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: TicketButton(
                'Buy Tickets',
                icon: Icons.confirmation_number_outlined,
                onPressed: widget.onBuy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TicketButton(
                'Scan & Add',
                icon: Icons.qr_code_scanner,
                outlined: true,
                onPressed: widget.onScan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TicketSurface(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              for (final value in ['Upcoming', 'Used', 'Expired'])
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => filter = value),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: filter == value
                            ? const Color(0xFFF5E7E3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          color: filter == value ? ticketMutedRose : ticketInk,
                          fontWeight: filter == value
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${tickets.length} ${filter.toLowerCase()} ${tickets.length == 1 ? 'ticket' : 'tickets'}',
          style: const TextStyle(color: ticketMuted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        if (tickets.isEmpty)
          TicketSurface(
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: ticketMutedRose,
                  size: 50,
                ),
                const SizedBox(height: 14),
                Text(
                  'No ${filter.toLowerCase()} tickets',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == 'Upcoming'
                      ? 'Your next park adventure will appear here.'
                      : 'Your ${filter.toLowerCase()} tickets will appear here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ticketMuted),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        for (final group in groups.values) ...[
          _TicketGroupCard(
            tickets: group,
            journey: widget.journey,
            onOpen: () => widget.onOpen(group),
          ),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.onHistory,
          child: const TicketSurface(
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: ticketMutedRose,
                  size: 35,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase History',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'View past orders and receipts',
                        style: TextStyle(color: ticketMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ticketMutedRose),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketGroupCard extends StatelessWidget {
  final List<ParkTicket> tickets;
  final TicketJourney journey;
  final VoidCallback onOpen;
  const _TicketGroupCard({
    required this.tickets,
    required this.journey,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    final adults = tickets.where((t) => t.ticketType == 'adult').length;
    final children = tickets.length - adults;
    return PerforatedTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.packageName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    TicketBadge(
                      ticket.filter == 'Upcoming' ? '●  Active' : ticket.filter,
                    ),
                    const SizedBox(height: 16),
                    TicketMeta(
                      Icons.calendar_today_outlined,
                      displayParkDate(ticket.visitDate),
                    ),
                    const SizedBox(height: 10),
                    TicketMeta(
                      Icons.person_outline,
                      [
                        if (adults > 0)
                          '$adults ${adults == 1 ? 'Adult' : 'Adults'}',
                        if (children > 0)
                          '$children ${children == 1 ? 'Child' : 'Children'}',
                      ].join(' · '),
                    ),
                    const SizedBox(height: 10),
                    TicketMeta(
                      Icons.sell_outlined,
                      'Ticket ID: ${ticket.reference}',
                    ),
                  ],
                ),
              ),
              if (tickets.length == 1)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 35),
                  child: _Qr(ticket, size: 92),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TicketButton(
                  tickets.length == 1 ? 'View Ticket' : 'View Details',
                  onPressed: onOpen,
                ),
              ),
              if (tickets.length == 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TicketButton(
                    journey.wallet.contains(ticket.id)
                        ? 'Saved to Wallet'
                        : 'Add to Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    outlined: true,
                    onPressed: () => _saveWallet(context, journey, ticket),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class DigitalTicketsScreen extends StatefulWidget {
  final TicketJourney journey;
  final List<ParkTicket> tickets;
  const DigitalTicketsScreen({
    super.key,
    required this.journey,
    required this.tickets,
  });
  @override
  State<DigitalTicketsScreen> createState() => _DigitalTicketsScreenState();
}

class _DigitalTicketsScreenState extends State<DigitalTicketsScreen> {
  bool bright = false;
  @override
  void dispose() {
    PassScreenBrightness.setBright(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = widget.tickets
        .map(
          (ticket) =>
              widget.journey.tickets
                  .where((t) => t.id == ticket.id)
                  .firstOrNull ??
              ticket,
        )
        .toList();
    if (tickets.isEmpty) {
      return const TicketPageBody(
        children: [
          TicketSurface(
            child: Text(
              'Your tickets are being prepared. Return to My Tickets to view them.',
            ),
          ),
        ],
      );
    }
    final first = tickets.first;
    return ColoredBox(
      color: bright ? Colors.white : ticketBackground,
      child: TicketPageBody(
        children: [
          TicketSurface(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: Image.asset(
                    ticketCastleAsset,
                    width: 130,
                    height: 115,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.packageName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TicketMeta(
                          Icons.calendar_today_outlined,
                          displayParkDate(first.visitDate),
                        ),
                        const SizedBox(height: 7),
                        TicketMeta(
                          Icons.confirmation_number_outlined,
                          '${tickets.length} ${tickets.length == 1 ? 'Ticket' : 'Tickets'}',
                        ),
                        const SizedBox(height: 8),
                        const TicketBadge('✓ Confirmed', green: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (tickets.length > 1) ...[
            const Text(
              'Your Tickets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 13),
          ],
          for (var i = 0; i < tickets.length; i++) ...[
            PerforatedTicket(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFF6E9E6),
                        child: Icon(
                          Icons.person_outline,
                          color: ticketRose,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tickets[i].ticketType == 'child' ? 'Child' : 'Adult'} ${tickets.length > 1 ? 'Ticket ${i + 1}' : 'Day Pass'}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (tickets[i].guestName.isNotEmpty)
                              Text(
                                tickets[i].guestName,
                                style: const TextStyle(
                                  color: ticketMuted,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TicketBadge(
                        tickets[i].filter == 'Upcoming'
                            ? 'Active'
                            : tickets[i].filter,
                        green: tickets[i].filter == 'Upcoming',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'Ticket ID: ${tickets[i].reference}',
                    style: const TextStyle(fontSize: 12, color: ticketMuted),
                  ),
                  const SizedBox(height: 25),
                  Center(
                    child: ColoredBox(
                      color: Colors.white,
                      child: _Qr(
                        tickets[i],
                        size: tickets.length == 1 ? 220 : 175,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Present this QR code at the entrance',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ticketMuted, fontSize: 13),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(color: ticketBorder),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.contactless_outlined, size: 30),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap with NFC',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Hold your phone\nnear the scanner',
                              style: TextStyle(
                                color: ticketMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 138,
                        child: TicketButton(
                          'Tap with NFC',
                          icon: Icons.phone_android,
                          onPressed: () => NfcPassService.present(
                            context,
                            tickets[i].qrData,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TicketButton(
                    widget.journey.wallet.contains(tickets[i].id)
                        ? 'Saved to Wallet'
                        : 'Add to Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    outlined: true,
                    onPressed: () =>
                        _saveWallet(context, widget.journey, tickets[i]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          TicketSurface(
            child: Row(
              children: [
                const Icon(Icons.brightness_high_outlined, color: ticketRose),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'Increase screen brightness',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Switch(
                  value: bright,
                  onChanged: (v) async {
                    setState(() => bright = v);
                    final applied = await PassScreenBrightness.setBright(v);
                    if (v && !applied && context.mounted) _brightness(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Show each QR code at the park entrance.',
              style: TextStyle(color: ticketMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _brightness(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Make your QR code easy to scan'),
      content: const Text(
        'Increase your device’s screen brightness using its display controls. Keep the full QR code visible when presenting your ticket.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _Qr extends StatelessWidget {
  final ParkTicket ticket;
  final double size;
  const _Qr(this.ticket, {required this.size});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'QR code for ticket ${ticket.reference}',
    child: QrImageView(
      data: ticket.qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(6),
      errorStateBuilder: (_, _) => const Icon(Icons.error_outline),
    ),
  );
}

Future<void> _saveWallet(
  BuildContext context,
  TicketJourney journey,
  ParkTicket ticket,
) async {
  await journey.addToWallet(ticket);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ticket saved to your in-app wallet. Find it in My Tickets.',
        ),
      ),
    );
  }
}

class TicketHistoryScreen extends StatefulWidget {
  final TicketJourney journey;
  final ValueChanged<List<ParkTicket>> onOpen;
  const TicketHistoryScreen({
    super.key,
    required this.journey,
    required this.onOpen,
  });
  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final orders = filter == 'All' || filter == 'Tickets'
        ? widget.journey.orders
        : <TicketOrder>[];
    return TicketPageBody(
      children: [
        Row(
          children: [
            for (final value in ['All', 'Tickets', 'Photos', 'Purchases'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(value, style: const TextStyle(fontSize: 12)),
                    selected: filter == value,
                    onSelected: (_) => setState(() => filter = value),
                    showCheckmark: false,
                    selectedColor: const Color(0xFFEED8D5),
                    side: const BorderSide(color: ticketBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent Purchases',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        if (orders.isEmpty)
          TicketSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 42,
                    color: ticketMutedRose,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filter == 'All'
                        ? 'No purchases yet'
                        : 'No ${filter.toLowerCase()} purchases yet',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your completed orders and receipts will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ticketMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        for (final order in orders) ...[
          TicketSurface(
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF5E7E4),
                      child: Icon(
                        Icons.confirmation_number_outlined,
                        color: ticketMutedRose,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.packageName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${displayParkDate(order.visitDate)} · ${order.quantity} ${order.quantity == 1 ? 'ticket' : 'tickets'}',
                            style: const TextStyle(
                              color: ticketMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      order.paymentLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.reference,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ticketMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => downloadTicketReceipt(context, order),
                      child: const Text(
                        'View Receipt',
                        style: TextStyle(color: ticketMutedRose, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                TicketButton(
                  'View Tickets',
                  outlined: true,
                  onPressed: () => widget.onOpen(
                    widget.journey.tickets
                        .where((t) => t.orderId == order.id)
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
