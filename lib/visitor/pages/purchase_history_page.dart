import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../photos/photo_repository.dart';
import '../../photos/photo_order_pages.dart';
import '../../photos/photo_widgets.dart';
import '../models/tickets.dart';
import '../services/ticket_repository.dart';
import '../services/ticket_receipt.dart';
import '../visitor_main_page.dart';

class CombinedPurchaseHistoryPage extends StatefulWidget {
  const CombinedPurchaseHistoryPage({super.key});
  @override
  State<CombinedPurchaseHistoryPage> createState() =>
      _CombinedPurchaseHistoryPageState();
}

class _CombinedPurchaseHistoryPageState
    extends State<CombinedPurchaseHistoryPage> {
  late final tickets = FirebaseTicketRepository().orders(),
      photos = FirebasePhotoRepository();
  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Purchase History',
    helpTitle: 'Your purchases',
    helpText:
        'Use the filters to find ticket and photo orders. Open a ticket purchase for its passes and receipt, or open a photo order for digital downloads and print collection. Orders remain linked to the account used for the purchase.',
    body: StreamBuilder<List<TicketOrder>>(
      stream: tickets,
      builder: (context, s) {
        if (s.hasError) {
          return const Center(
            child: Text('Unable to load your orders. Please try again.'),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return PurchaseHistoryBody(
          orders: s.data!,
          photos: photos,
          onTickets: (order) {
            Navigator.of(context).popUntil((r) => r.isFirst);
            VisitorMainPage.openTicketOrder(context, order.id);
          },
        );
      },
    ),
  );
}

class PurchaseHistoryBody extends StatefulWidget {
  final List<TicketOrder> orders;
  final PhotoRepository? photos;
  final ValueChanged<TicketOrder> onTickets;
  const PurchaseHistoryBody({
    super.key,
    required this.orders,
    required this.onTickets,
    this.photos,
  });
  @override
  State<PurchaseHistoryBody> createState() => _PurchaseHistoryBodyState();
}

class _PurchaseHistoryBodyState extends State<PurchaseHistoryBody> {
  late final photoOrders =
      widget.photos?.orders() ?? Stream<List<ParkPhoto>>.value([]);
  String filter = 'All', query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ParkPhoto>>(
    stream: photoOrders,
    builder: (context, s) {
      final rows =
          <({DateTime? time, TicketOrder? ticket, ParkPhoto? photo})>[
            if (filter != 'Photos')
              for (final t in widget.orders)
                (time: t.createdAt, ticket: t, photo: null),
            if (filter != 'Tickets')
              for (final p in s.data ?? [])
                (
                  time: (p.data['createdAt'] as Timestamp?)?.toDate(),
                  ticket: null,
                  photo: p,
                ),
          ]..sort(
            (a, b) =>
                (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)),
          );
      final matched = rows
          .where(
            (row) =>
                '${row.ticket?.packageName ?? (row.photo?.data['items'] as List? ?? []).map((p) => p['title']).join(' ')} ${row.ticket?.reference ?? photoOrderReference(row.photo!.id)}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              for (final v in ['All', 'Tickets', 'Photos', 'Purchases'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(v, style: const TextStyle(fontSize: 11)),
                      showCheckmark: false,
                      selected: filter == v,
                      onSelected: (_) => setState(() => filter = v),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Search purchase or order number',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 23),
          const Text(
            'Recent Purchases',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (s.hasError)
            const PhotoPanel(
              child: Text(
                'Photo orders could not be loaded. Please reopen Purchase History.',
              ),
            ),
          if (matched.isEmpty)
            const PhotoPanel(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 55,
                      color: photoRose,
                    ),
                    SizedBox(height: 17),
                    Text(
                      'No purchases found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Confirmed orders and receipts will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (final row in matched)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PhotoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFF3E3DE),
                          child: Icon(
                            row.ticket != null
                                ? Icons.confirmation_number_outlined
                                : Icons.photo_library_outlined,
                            color: photoRose,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.ticket?.packageName ??
                                    'Park Photo Purchase',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row.ticket?.reference ??
                                    photoOrderReference(row.photo!.id),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                row.time == null
                                    ? ''
                                    : '${row.time!.toLocal().day}/${row.time!.toLocal().month}/${row.time!.toLocal().year}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          photoMoney(
                            row.ticket?.totalMinor ??
                                row.photo!.data['totalMinor'] as num,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 29),
                    Text(
                      row.ticket != null
                          ? '${row.ticket!.quantity} tickets • ${displayParkDate(row.ticket!.visitDate)}'
                          : '${(row.photo!.data['items'] as List).length} photos • Confirmed',
                      style: const TextStyle(fontSize: 12, color: photoRose),
                    ),
                    const SizedBox(height: 14),
                    if (row.ticket != null) ...[
                      PhotoButton(
                        'View Tickets',
                        outlined: true,
                        onPressed: () => widget.onTickets(row.ticket!),
                      ),
                      TextButton(
                        onPressed: () =>
                            downloadTicketReceipt(context, row.ticket!),
                        child: const Text('View Receipt'),
                      ),
                    ] else
                      PhotoButton(
                        'View Photo Order',
                        outlined: true,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoOrderDetailPage(
                              repository: widget.photos!,
                              orderId: row.photo!.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
