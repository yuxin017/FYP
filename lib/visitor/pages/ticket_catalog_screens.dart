import 'package:flutter/material.dart';
import '../models/tickets.dart';
import '../services/ticket_journey.dart';
import '../widgets/ticket_widgets.dart';
import 'tickets_page.dart';

class TicketHub extends StatelessWidget {
  final TicketJourney journey;
  final void Function([String category]) onBuy;
  final VoidCallback onTickets, onScan, onHistory;
  final ValueChanged<TicketPackage> onSelect;
  const TicketHub({
    super.key,
    required this.journey,
    required this.onBuy,
    required this.onTickets,
    required this.onScan,
    required this.onHistory,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final day = journey.packages.where((p) => p.category == 'day').firstOrNull;
    final annual = journey.packages
        .where((p) => p.category == 'annual')
        .firstOrNull;
    return TicketPageBody(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 16),
      children: [
        Semantics(
          key: const Key('buy-tickets-banner'),
          button: true,
          label: 'Buy Tickets. Make every moment magical.',
          child: InkWell(
            onTap: () => onBuy(),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/ticketing/hero.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shortcut(
              Icons.confirmation_number_outlined,
              'Day & Annual\nPasses',
              () => onBuy(),
            ),
            _shortcut(Icons.qr_code_scanner, 'Add Ticket\n(Scan)', onScan),
            _shortcut(
              Icons.account_balance_wallet_outlined,
              'My Tickets',
              onTickets,
            ),
            _shortcut(Icons.shopping_bag_outlined, 'My Orders', onHistory),
          ],
        ),
        const SizedBox(height: 20),
        _section('Day & Annual Passes', () => onBuy()),
        const SizedBox(height: 12),
        if (journey.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _passCard(
                  context,
                  'Theme Park Day Pass',
                  ticketCastleAsset,
                  day?.priceMinor,
                  () => day == null ? onBuy() : onSelect(day),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _passCard(
                  context,
                  'Annual Pass',
                  ticketAnnualAsset,
                  annual?.priceMinor,
                  () => annual == null ? onBuy('annual') : onSelect(annual),
                  annual: true,
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),
        _section('Shop Souvenirs', () => _souvenirInfo(context)),
        const SizedBox(height: 8),
        SizedBox(
          height: 115,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _souvenir(context, 'Mickey Ears Headband', 5900, 'headband.png'),
              _souvenir(context, 'Castle Snow Globe', 8900, 'snow-globe.png'),
              _souvenir(context, 'Duffy Plush Toy', 12900, 'plush.png'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTickets,
          child: TicketSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Digital Tickets',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${journey.tickets.where((t) => t.filter == 'Upcoming').length} active tickets',
                        style: const TextStyle(
                          color: ticketMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String text, VoidCallback tap) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      InkWell(
        onTap: tap,
        child: const Row(
          children: [
            Text(
              'See All',
              style: TextStyle(
                color: ticketRose,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.chevron_right, color: ticketRose, size: 20),
          ],
        ),
      ),
    ],
  );
  Widget _shortcut(IconData icon, String label, VoidCallback tap) => Expanded(
    child: InkWell(
      onTap: tap,
      child: Column(
        children: [
          TicketSurface(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            child: Icon(icon, color: ticketRose, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
  Widget _passCard(
    BuildContext context,
    String name,
    String image,
    int? price,
    VoidCallback tap, {
    bool annual = false,
  }) => TicketSurface(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          child: Image.asset(
            image,
            height: 126,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'From',
                style: TextStyle(fontSize: 11, color: ticketMuted),
              ),
              Text(
                price == null
                    ? 'View passes'
                    : '${ticketDisplayPrice(context, price)}${annual ? ' / year' : ''}',
                style: const TextStyle(
                  color: ticketRose,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 31,
                child: TicketButton('Buy Now', onPressed: tap),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _souvenir(
    BuildContext context,
    String name,
    int price,
    String image,
  ) => SizedBox(
    width: 119,
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () =>
            _souvenirInfo(context, name: name, price: price, image: image),
        child: TicketSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Image.asset(
                  'assets/images/ticketing/$image',
                  height: 76,
                  width: 110,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 3, 4, 0),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  ticketDisplayPrice(context, price),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  void _souvenirInfo(
    BuildContext context, {
    String? name,
    int? price,
    String? image,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null)
            Image.asset('assets/images/ticketing/$image', height: 150),
          Text(
            name ?? 'Shop Souvenirs',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          if (price != null)
            Text(
              ticketDisplayPrice(context, price),
              style: const TextStyle(color: ticketRose, fontSize: 21),
            ),
          const SizedBox(height: 12),
          const Text(
            'Discover these souvenirs at the park gift shop. Ask our shop team for availability during your visit.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TicketButton(
            'Continue exploring',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class PassCatalog extends StatelessWidget {
  final List<TicketPackage> packages;
  final String category;
  final bool loading;
  final ValueChanged<String> onCategory;
  final ValueChanged<TicketPackage> onSelect;
  const PassCatalog({
    super.key,
    required this.packages,
    required this.category,
    required this.onCategory,
    required this.onSelect,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    final filtered = packages.where((p) => p.category == category).toList();
    return TicketPageBody(
      children: [
        TicketSurface(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (final item in [
                ('day', 'Day Pass'),
                ('annual', 'Annual Pass'),
                ('addon', 'Add-ons'),
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => onCategory(item.$1),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: category == item.$1
                            ? ticketRose
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          color: category == item.$1 ? Colors.white : ticketInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          category == 'day'
              ? 'Choose Your Day Pass'
              : category == 'annual'
              ? 'Enjoy a Year of Magic'
              : 'Make Your Visit Extra Special',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
          TicketSurface(
            child: Text(
              category == 'addon'
                  ? 'There are no add-ons available for your visit right now.'
                  : 'Passes are currently unavailable. Please check again shortly.',
            ),
          ),
        for (final pack in filtered) ...[
          TicketSurface(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    pack.imageAsset,
                    width: 98,
                    height: 116,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.shortName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          pack.description,
                          style: const TextStyle(
                            color: ticketMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'From',
                                    style: TextStyle(
                                      color: ticketMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    ticketDisplayPrice(
                                      context,
                                      pack.priceMinor,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 21,
                                      color: ticketRose,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 74,
                              height: 36,
                              child: TicketButton(
                                'Select',
                                key: Key('select-${pack.id}'),
                                onPressed: () => onSelect(pack),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const TicketSurface(
          color: Color(0xFFF8EAEC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Important Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              TicketMeta(Icons.paid_outlined, 'Tickets are non-refundable.'),
              SizedBox(height: 8),
              TicketMeta(
                Icons.calendar_today_outlined,
                'Valid only on selected admission dates.',
              ),
              SizedBox(height: 8),
              TicketMeta(Icons.child_care, 'Child ticket for ages 3–11.'),
              SizedBox(height: 8),
              TicketMeta(Icons.qr_code, 'Scan QR code at park entrance.'),
            ],
          ),
        ),
      ],
    );
  }
}

class PassDetail extends StatefulWidget {
  final TicketPackage package;
  final int remaining;
  final ValueChanged<TicketCartLine> onAdd;
  const PassDetail({
    super.key,
    required this.package,
    required this.remaining,
    required this.onAdd,
  });
  @override
  State<PassDetail> createState() => _PassDetailState();
}

class _PassDetailState extends State<PassDetail> {
  int adults = 1, children = 0;
  DateTime date = parkToday();
  @override
  Widget build(BuildContext context) {
    final pack = widget.package;
    final total = adults * pack.priceMinor + children * pack.childPrice;
    return TicketPageBody(
      footer: TicketSurface(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: ticketMuted, fontSize: 12),
                  ),
                  Text(
                    ticketDisplayPrice(context, total),
                    key: const Key('pass-total'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TicketButton(
                'Add to Cart',
                onPressed:
                    adults + children < 1 ||
                        adults + children > widget.remaining
                    ? null
                    : () => widget.onAdd(
                        TicketCartLine(
                          id: TicketJourney.newId(),
                          packageId: pack.id,
                          packageName: pack.name,
                          visitDate: visitDateString(date),
                          adults: adults,
                          children: children,
                          adultPriceMinor: pack.priceMinor,
                          childPriceMinor: pack.childPrice,
                          durationDays: pack.durationDays,
                          imageAsset: pack.imageAsset,
                          category: pack.category,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            pack.imageAsset,
            height: 235,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          pack.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          pack.category == 'annual'
              ? 'A whole year of unforgettable rides, shows and attractions.'
              : 'Access to all rides, shows and attractions for ${pack.durationDays == 1 ? '1 day' : '${pack.durationDays} consecutive days'}.',
          style: const TextStyle(fontSize: 16, color: ticketMuted, height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          ticketDisplayPrice(context, pack.priceMinor),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: ticketRose,
          ),
        ),
        const Divider(height: 28, color: ticketBorder),
        const Text(
          'Select Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('select-visit-date'),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: parkToday(),
              lastDate: parkToday().add(const Duration(days: 365)),
            );
            if (value != null && mounted) setState(() => date = value);
          },
          child: TicketSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(displayParkDate(visitDateString(date)))),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Select Quantity',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _quantity(
          'Adult (12+)',
          'adults',
          adults,
          pack.priceMinor,
          () => setState(() => adults--),
          () => setState(() => adults++),
        ),
        const SizedBox(height: 5),
        _quantity(
          'Child (3–11)',
          'children',
          children,
          pack.childPrice,
          () => setState(() => children--),
          () => setState(() => children++),
        ),
        const SizedBox(height: 14),
        const Text(
          'You’ll Get',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final benefit in pack.benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                const Icon(Icons.check, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(fontSize: 13, color: ticketMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _quantity(
    String title,
    String label,
    int value,
    int price,
    VoidCallback minus,
    VoidCallback plus,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F0EE),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                ticketDisplayPrice(context, price),
                style: const TextStyle(color: ticketMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        TicketCounter(
          label: label,
          value: value,
          minus: value > 0 ? minus : null,
          plus: adults + children < widget.remaining ? plus : null,
        ),
      ],
    ),
  );
}
