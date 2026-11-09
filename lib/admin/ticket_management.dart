import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../visitor/models/tickets.dart';
import '../visitor/services/ticket_receipt.dart';
import 'admin_models.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';

class TicketManagement extends StatefulWidget {
  final AdminStore store;
  final ValueChanged<ParkTicket> onValidate;
  const TicketManagement({
    super.key,
    required this.store,
    required this.onValidate,
  });
  @override
  State<TicketManagement> createState() => _TicketManagementState();
}

class _TicketManagementState extends State<TicketManagement> {
  String query = '', tab = 'Bookings', status = 'all';
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final text = query.trim().toLowerCase();
    final orders = s.orders
        .where(
          (o) => '${o.reference} ${o.packageName} ${o.id}'
              .toLowerCase()
              .contains(text),
        )
        .toList();
    final tickets = s.tickets
        .where(
          (t) =>
              (status == 'all' ||
                  (status == 'valid'
                      ? t.filter == 'Upcoming'
                      : t.filter.toLowerCase() == status)) &&
              '${t.reference} ${t.guestName} ${t.guestEmail} ${t.id} ${t.packageName}'
                  .toLowerCase()
                  .contains(text),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminHeading(
          'Tickets & Orders',
          'Manage booking records and digital park tickets',
        ),
        const SizedBox(height: 26),
        AdminStats(
          children: [
            AdminStat(
              'Total Bookings',
              '${s.orders.length}',
              'Confirmed park bookings',
              Icons.receipt_long_outlined,
            ),
            AdminStat(
              'Tickets Issued',
              '${s.tickets.length}',
              'All issued park tickets',
              Icons.confirmation_number_outlined,
            ),
            AdminStat(
              'Valid Tickets',
              '${s.tickets.where((t) => t.filter == 'Upcoming').length}',
              'Available park admissions',
              Icons.verified_outlined,
              color: const Color(0xFF278D52),
            ),
            AdminStat(
              'Booking Amount',
              money(s.orders.fold(0, (amount, o) => amount + o.totalMinor)),
              'Total confirmed booking value',
              Icons.payments_outlined,
              color: const Color(0xFF3978D8),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final value in ['Bookings', 'Digital Tickets'])
                ChoiceChip(
                  label: Text(value),
                  selected: tab == value,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => tab = value),
                ),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search booking, ticket or guest',
                  ),
                ),
              ),
              if (tab == 'Digital Tickets')
                AdminSelect(
                  value: status,
                  options: const {
                    'all': 'All Status',
                    'valid': 'Valid',
                    'used': 'Used',
                    'expired': 'Expired',
                  },
                  onChanged: (v) => setState(() => status = v),
                ),
              AdminButton(
                'Export CSV',
                icon: Icons.download_outlined,
                onPressed: () => exportAdminCsv(
                  context,
                  tab == 'Bookings' ? 'park-bookings.csv' : 'park-tickets.csv',
                  tab == 'Bookings'
                      ? [
                          'Booking ID',
                          'Pass',
                          'Visit Date',
                          'Guests',
                          'Subtotal',
                          'Points',
                          'Total',
                        ]
                      : [
                          'Ticket ID',
                          'Pass',
                          'Guest',
                          'Email',
                          'Visit Date',
                          'Status',
                        ],
                  tab == 'Bookings'
                      ? orders
                            .map(
                              (o) => [
                                o.reference,
                                o.packageName,
                                o.visitDate,
                                o.quantity,
                                money(o.subtotal),
                                o.pointsUsed,
                                money(o.totalMinor),
                              ],
                            )
                            .toList()
                      : tickets
                            .map(
                              (t) => [
                                t.reference,
                                t.packageName,
                                t.guestName,
                                t.guestEmail,
                                t.visitDate,
                                t.filter,
                              ],
                            )
                            .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          padding: EdgeInsets.zero,
          child: tab == 'Bookings'
              ? (orders.isEmpty
                    ? const AdminEmpty(
                        'No matching bookings',
                        'Confirmed visitor bookings will appear here.',
                      )
                    : AdminTable(
                        columns: const [
                          DataColumn(label: Text('Booking ID')),
                          DataColumn(label: Text('Pass')),
                          DataColumn(label: Text('Visit Date')),
                          DataColumn(label: Text('Guests')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final o in orders)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    o.reference,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 190,
                                    child: Text(o.packageName),
                                  ),
                                ),
                                DataCell(Text(displayParkDate(o.visitDate))),
                                DataCell(Text('${o.quantity}')),
                                DataCell(
                                  Text(
                                    money(o.totalMinor),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const DataCell(AdminBadge('Confirmed')),
                                DataCell(
                                  AdminButton(
                                    'View Receipt',
                                    outlined: true,
                                    onPressed: () =>
                                        downloadTicketReceipt(context, o),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ))
              : tickets.isEmpty
              ? const AdminEmpty(
                  'No matching tickets',
                  'Try another status or search for a ticket ID.',
                )
              : AdminTable(
                  columns: const [
                    DataColumn(label: Text('Ticket ID')),
                    DataColumn(label: Text('Pass / Guest')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Visit Date')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final t in tickets)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              t.reference,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 190,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.packageName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    t.guestName.isEmpty
                                        ? titleCase(t.ticketType)
                                        : t.guestName,
                                    style: const TextStyle(
                                      color: adminMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              t.guestEmail,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(Text(displayParkDate(t.visitDate))),
                          DataCell(
                            AdminBadge(
                              t.filter == 'Upcoming' ? 'Valid' : t.filter,
                            ),
                          ),
                          DataCell(
                            AdminButton(
                              'View Ticket',
                              outlined: true,
                              onPressed: () => showAdminTicket(
                                context,
                                t,
                                widget.onValidate,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

Future<void> showAdminTicket(
  BuildContext context,
  ParkTicket ticket,
  ValueChanged<ParkTicket> onValidate,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Ticket Details'),
    content: SizedBox(
      width: 390,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.packageName,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Guest: ${ticket.guestName.isEmpty ? 'Not assigned' : ticket.guestName}',
            ),
            const SizedBox(height: 7),
            Text(
              'Visit: ${displayParkDate(ticket.visitDate)}${ticket.endDate != ticket.visitDate ? ' – ${displayParkDate(ticket.endDate)}' : ''}',
            ),
            const SizedBox(height: 8),
            SelectableText(
              ticket.reference,
              style: const TextStyle(color: adminMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: ticket.qrData,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: AdminBadge(
                ticket.filter == 'Upcoming' ? 'Valid' : ticket.filter,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      AdminButton(
        'Validate Ticket',
        onPressed: () {
          Navigator.pop(context);
          onValidate(ticket);
        },
      ),
    ],
  ),
);
