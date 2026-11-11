import 'package:flutter/material.dart';
import '../models/tickets.dart';
import '../services/ticket_repository.dart';
import '../services/ticket_journey.dart';
import '../widgets/ticket_widgets.dart';
import 'ticket_catalog_screens.dart';
import 'ticket_checkout_screens.dart';
import 'ticket_wallet_screens.dart';
import 'ticket_scan_page.dart';
import 'purchase_history_page.dart';
import '../../photos/photo_repository.dart';
import '../services/ticket_currency.dart';
import '../../services/application_api.dart';

class TicketsPage extends StatefulWidget {
  final TicketRepository? repository;
  final PendingTicketCheckoutStore? pendingStore;
  const TicketsPage({super.key, this.repository, this.pendingStore});
  @override
  State<TicketsPage> createState() => TicketsPageState();
}

class TicketsPageState extends State<TicketsPage> {
  late final currency = TicketDisplayCurrency(
    fetchRates: () => ApplicationApi().post('/v1/park/exchangeRates'),
  );
  late final TicketJourney journey;
  final List<String> _history = [];
  String _screen = 'hub', _category = 'day';
  TicketPackage? _package;
  List<ParkTicket> _selectedTickets = [];
  String? _awaitingOrder;
  late final PhotoRepository? photos =
      widget.repository == null || widget.repository is FirebaseTicketRepository
      ? FirebasePhotoRepository()
      : null;
  void openOrder(String id) {
    _digital(
      journey.tickets.where((t) => t.orderId == id).toList(),
      orderId: id,
    );
  }

  @override
  void initState() {
    super.initState();
    journey = TicketJourney(
      widget.repository ?? FirebaseTicketRepository(),
      widget.pendingStore ?? PendingTicketCheckoutStore(),
    );
    journey.start();
  }

  @override
  void dispose() {
    currency.dispose();
    journey.dispose();
    super.dispose();
  }

  void showSection(String screen) {
    if (!mounted) return;
    setState(() {
      _history.clear();
      _screen = screen;
    });
  }

  void _go(String screen) {
    setState(() {
      _history.add(_screen);
      _screen = screen;
    });
  }

  void _back() {
    if (journey.busy) return;
    setState(() {
      _screen = _history.isEmpty ? 'hub' : _history.removeLast();
    });
  }

  void _catalog([String category = 'day']) {
    _category = category;
    _go('catalog');
  }

  void _detail(TicketPackage package) {
    _package = package;
    _go('detail');
  }

  void _digital(List<ParkTicket> tickets, {String? orderId}) {
    _selectedTickets = tickets;
    _awaitingOrder = tickets.isEmpty ? orderId : null;
    _go('digital');
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your park tickets'),
      content: const Text(
        'Choose a pass and visit date, add each guest’s name and email, then confirm your booking. Your tickets and QR codes are saved in My Tickets.\n\nEach guest presents their own QR code at the park entrance. Tickets are valid for their selected admission dates.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  Future<void> _pay(String method, {String cardLast4 = ''}) async {
    final success = await journey.pay(method, cardLast4: cardLast4);
    if (mounted && success) {
      setState(() {
        _history.clear();
        _screen = 'success';
      });
    }
  }

  Future<void> _payment() async {
    if (await journey.prepareCurrency(currency.selected) && mounted) {
      _go('payment');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([journey, currency]),
    builder: (context, _) {
      Widget page;
      switch (_screen) {
        case 'catalog':
          page = PassCatalog(
            packages: journey.packages,
            category: _category,
            onCategory: (v) => setState(() => _category = v),
            onSelect: _detail,
            loading: journey.loading,
          );
          break;
        case 'detail':
          page = PassDetail(
            key: ValueKey(_package!.id),
            package: _package!,
            remaining: 10 - journey.quantity,
            onAdd: (line) {
              try {
                journey.add(line);
                _go('cart');
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(bookingError(e))));
              }
            },
          );
          break;
        case 'cart':
          page = TicketCartScreen(
            journey: journey,
            onShop: () => _catalog(),
            onCheckout: () => _go('guests'),
          );
          break;
        case 'guests':
          page = TicketGuestsScreen(
            journey: journey,
            onContinue: () => _go('review'),
          );
          break;
        case 'review':
          page = TicketReviewScreen(journey: journey, onContinue: _payment);
          break;
        case 'payment':
          page = TicketPaymentScreen(journey: journey, onPay: _pay);
          break;
        case 'success':
          page = TicketSuccessScreen(
            journey: journey,
            onDigital: () {
              final id = journey.completed?.requestId;
              _digital(
                journey.tickets.where((t) => t.orderId == id).toList(),
                orderId: id,
              );
            },
            onBack: () => showSection('hub'),
          );
          break;
        case 'tickets':
          page = MyTicketsScreen(
            journey: journey,
            onBuy: () => _catalog(),
            onScan: () => _go('scan'),
            onOpen: _digital,
            onHistory: () => _go('history'),
          );
          break;
        case 'digital':
          page = DigitalTicketsScreen(
            journey: journey,
            tickets: _awaitingOrder == null
                ? _selectedTickets
                : journey.tickets
                      .where((t) => t.orderId == _awaitingOrder)
                      .toList(),
          );
          break;
        case 'history':
          page = PurchaseHistoryBody(
            orders: journey.orders,
            photos: photos,
            onTickets: (order) => _digital(
              journey.tickets.where((t) => t.orderId == order.id).toList(),
              orderId: order.id,
            ),
          );
          break;
        case 'scan':
          page = TicketScanPage(
            repository: journey.repository,
            onFound: (ticket) {
              journey.addToWallet(ticket);
              _digital([ticket]);
            },
          );
          break;
        default:
          page = TicketHub(
            journey: journey,
            onBuy: _catalog,
            onTickets: () => _go('tickets'),
            onScan: () => _go('scan'),
            onHistory: () => _go('history'),
            onSelect: _detail,
          );
      }
      const titles = {
        'hub': 'Tickets',
        'catalog': 'Day & Annual Passes',
        'cart': 'Your Cart',
        'guests': 'Guest Details',
        'review': 'Review Order',
        'payment': 'Payment',
        'success': 'Payment Successful',
        'tickets': 'My Tickets',
        'digital': 'My Digital Tickets',
        'history': 'Purchase History',
        'scan': 'Scan & Add Ticket',
      };
      final title = _screen == 'detail'
          ? _package!.shortName
          : titles[_screen] ?? 'Tickets';
      final currencyVisible = [
        'hub',
        'catalog',
        'detail',
        'cart',
      ].contains(_screen);
      return TicketCurrencyScope(
        currency: currency,
        enabled: currencyVisible,
        child: PopScope(
          canPop: _history.isEmpty,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _back();
          },
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: ticketBackground,
              colorScheme: ColorScheme.fromSeed(
                seedColor: ticketRose,
                primary: ticketRose,
                surface: Colors.white,
              ),
              textTheme: Theme.of(
                context,
              ).textTheme.apply(bodyColor: ticketInk, displayColor: ticketInk),
              inputDecorationTheme: InputDecorationTheme(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: ticketBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: ticketBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: ticketRose),
                ),
              ),
            ),
            child: ColoredBox(
              color: ticketBackground,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          if (_screen != 'hub' &&
                              _screen != 'tickets' &&
                              _screen != 'success')
                            IconButton(
                              tooltip: 'Back',
                              onPressed: journey.busy ? null : _back,
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 22,
                                color: ticketRose,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              textAlign:
                                  _screen == 'hub' || _screen == 'tickets'
                                  ? TextAlign.start
                                  : TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    _screen == 'hub' || _screen == 'tickets'
                                    ? 32
                                    : 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_screen == 'hub') ...[
                            PopupMenuButton<String>(
                              tooltip: 'Display currency',
                              enabled: !currency.busy && !journey.busy,
                              itemBuilder: (_) => [
                                for (final c in [
                                  'MYR',
                                  'USD',
                                  'SGD',
                                  'CNY',
                                  'EUR',
                                ])
                                  PopupMenuItem(value: c, child: Text(c)),
                              ],
                              onSelected: (value) async {
                                try {
                                  await currency.choose(value);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e is ApplicationApiException
                                              ? e.message
                                              : 'Unable to load exchange rates.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  currency.busy ? '…' : currency.selected,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ticket notifications',
                              onPressed: () => _go('tickets'),
                              icon: const Icon(
                                Icons.notifications_none,
                                size: 29,
                              ),
                            ),
                          ] else if (_screen == 'tickets' ||
                              _screen == 'scan' ||
                              _screen == 'history' ||
                              _screen == 'digital')
                            IconButton(
                              tooltip: 'Ticket help',
                              onPressed: _help,
                              icon: const Icon(
                                Icons.help_outline,
                                color: ticketMutedRose,
                                size: 27,
                              ),
                            )
                          else if (_screen == 'success')
                            IconButton(
                              tooltip: 'Back to Tickets',
                              onPressed: () => showSection('hub'),
                              icon: const Icon(Icons.close, color: ticketRose),
                            )
                          else if (_screen != 'cart')
                            IconButton(
                              tooltip: 'Shopping cart',
                              onPressed: journey.busy
                                  ? null
                                  : () => _go('cart'),
                              icon: Badge(
                                isLabelVisible: journey.quantity > 0,
                                label: Text('${journey.quantity}'),
                                backgroundColor: ticketRose,
                                child: const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 27,
                                  color: Color(0xFF64252A),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    if (journey.error != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDEB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: ticketRose,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                journey.error!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (journey.pending != null && _screen != 'payment')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: TicketButton(
                          'Resume pending checkout',
                          onPressed: () => _go('payment'),
                          outlined: true,
                        ),
                      ),
                    Expanded(child: page),
                    if (currency.selected != 'MYR' && currencyVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                        child: Text(
                          'Reference conversion as of ${currency.asOf}. A fixed currency quote is shown before confirmation.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ticketMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class TicketPageBody extends StatelessWidget {
  final List<Widget> children;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  const TicketPageBody({
    super.key,
    required this.children,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(padding: padding, children: children),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: footer!,
        ),
    ],
  );
}
