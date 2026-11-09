import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tickets.dart';
import 'ticket_repository.dart';
import '../../services/application_api.dart';

/// State shared by the separate Figma booking screens. Card credentials never enter it.
class TicketJourney extends ChangeNotifier {
  final TicketRepository repository;
  final PendingTicketCheckoutStore pendingStore;
  TicketJourney(this.repository, this.pendingStore);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<TicketPackage> packages = [];
  List<ParkTicket> tickets = [];
  List<TicketOrder> orders = [];
  List<TicketCartLine> cart = [];
  List<TicketGuest> guests = [];
  BookingProfile profile = const BookingProfile();
  Set<String> wallet = {};
  TicketCheckout? pending, completed;
  String? error;
  bool loading = true, busy = false;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  int pointsUsed = 0;
  String promoCode = '';
  int discountMinor = 0;
  bool promotionAllowsPoints = true;
  bool termsAccepted = false;
  int get quantity => cart.fold(0, (sum, line) => sum + line.quantity);
  int get subtotal => cart.fold(0, (sum, line) => sum + line.subtotal);
  int get total => subtotal - pointsUsed - discountMinor;
  int get maxPoints => promotionAllowsPoints
      ? min(profile.points, subtotal - discountMinor) ~/ 100 * 100
      : 0;
  bool get guestsComplete =>
      guests.length == quantity && guests.every((g) => g.complete);
  String get _key => 'ticket_cart_v2_${repository.userId}';
  static String newId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> start() async {
    void failed(Object e) {
      error = bookingError(e);
      loading = false;
      notifyListeners();
    }

    _subscriptions.add(
      repository.packages().listen((value) {
        packages = [...value]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        loading = false;
        notifyListeners();
      }, onError: failed),
    );
    _subscriptions.add(
      repository.tickets().listen((value) {
        tickets = value;
        notifyListeners();
      }, onError: failed),
    );
    _subscriptions.add(
      repository.orders().listen((value) {
        orders = value;
        notifyListeners();
      }, onError: failed),
    );
    _subscriptions.add(
      repository.profile().listen((value) {
        profile = value;
        if (pointsUsed > maxPoints && !busy) pointsUsed = maxPoints;
        notifyListeners();
      }, onError: failed),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      wallet = (prefs.getStringList('ticket_wallet_${repository.userId}') ?? [])
          .toSet();
      final saved = prefs.getString(_key);
      if (saved != null) {
        final data = jsonDecode(saved) as Map;
        cart = (data['cart'] as List)
            .map((e) => TicketCartLine.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        guests = (data['guests'] as List)
            .map((e) => TicketGuest.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      final uid = repository.userId;
      pending = uid == null ? null : await pendingStore.load(uid);
      if (pending?.isJourney == true) {
        cart = [...pending!.lines];
        guests = [...pending!.guests];
        pointsUsed = pending!.pointsUsed;
        promoCode = pending!.promoCode;
        discountMinor = pending!.discountMinor;
        termsAccepted = true;
      }
    } catch (_) {
      error =
          'Your saved cart could not be restored. Please choose your tickets again.';
    }
    notifyListeners();
  }

  void add(TicketCartLine line) {
    if (pending != null) {
      throw StateError(
        'Finish the pending checkout before changing your cart.',
      );
    }
    if (quantity + line.quantity > 10) {
      throw StateError('You can book up to 10 tickets in one order.');
    }
    if (cart.length >= 5) {
      throw StateError('You can add up to five passes in one order.');
    }
    cart = [...cart, line];
    _syncGuests();
    _changed();
  }

  void remove(String id) {
    if (pending != null) return;
    cart = cart.where((line) => line.id != id).toList();
    _syncGuests();
    _changed();
  }

  void changeCount(String id, int adults, int children) {
    if (pending != null) return;
    final old = cart.firstWhere((line) => line.id == id);
    if (adults < 0 ||
        children < 0 ||
        adults + children < 1 ||
        quantity - old.quantity + adults + children > 10) {
      return;
    }
    cart = cart
        .map((line) => line.id == id ? line.withCounts(adults, children) : line)
        .toList();
    _syncGuests();
    _changed();
  }

  void _syncGuests() {
    promoCode = '';
    discountMinor = 0;
    promotionAllowsPoints = true;
    final old = {for (final guest in guests) guest.id: guest};
    guests = [
      for (final line in cart)
        for (final type in ['adult', 'child'])
          for (
            var i = 0;
            i < (type == 'adult' ? line.adults : line.children);
            i++
          )
            old['${line.id}_${type}_$i'] ??
                TicketGuest(
                  id: '${line.id}_${type}_$i',
                  lineId: line.id,
                  type: type,
                ),
    ];
    pointsUsed = min(pointsUsed, maxPoints);
    termsAccepted = false;
  }

  void updateGuest(TicketGuest guest) {
    if (pending != null) return;
    guests = guests.map((g) => g.id == guest.id ? guest : g).toList();
    _changed();
  }

  void setPoints(int value) {
    pointsUsed = value.clamp(0, maxPoints) ~/ 100 * 100;
    notifyListeners();
  }

  Future<void> applyPromotion(String code) async {
    if (busy || pending != null) return;
    if (code.trim().isEmpty) {
      promoCode = '';
      discountMinor = 0;
      promotionAllowsPoints = true;
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final normalized = code.trim().toUpperCase(),
          quote = await repository.promotionQuote(
            TicketCheckout.journey(
              requestId: newId(),
              lines: cart,
              guests: guests,
              promoCode: normalized,
            ),
          );
      promoCode = normalized;
      discountMinor = (quote['discountMinor'] as num).toInt();
      promotionAllowsPoints = quote['allowPoints'] != false;
      pointsUsed = min(pointsUsed, maxPoints);
      termsAccepted = false;
    } catch (e) {
      error = bookingError(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void acceptTerms(bool value) {
    termsAccepted = value;
    notifyListeners();
  }

  void _changed() {
    error = null;
    unawaited(_saveCart());
    notifyListeners();
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'cart': cart.map((l) => l.toMap()).toList(),
        'guests': guests.map((g) => g.toMap()).toList(),
      }),
    );
  }

  Future<bool> pay(String method, {String cardLast4 = ''}) async {
    if (busy) return false;
    if (pending == null && (!guestsComplete || !termsAccepted)) {
      error = 'Complete the guest details and agree to the ticket terms first.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final request =
          pending ??
          TicketCheckout.journey(
            requestId: newId(),
            lines: cart,
            guests: guests,
            pointsUsed: pointsUsed,
            paymentMethod: method,
            cardLast4: cardLast4,
            promoCode: promoCode,
            discountMinor: discountMinor,
          );
      final uid = repository.userId;
      if (uid == null) throw StateError('Please sign in before checkout.');
      await pendingStore.save(uid, request);
      pending = request;
      await repository.checkout(request);
      completed = request;
      await pendingStore.clear(uid);
      pending = null;
      cart = [];
      guests = [];
      pointsUsed = 0;
      promoCode = '';
      discountMinor = 0;
      promotionAllowsPoints = true;
      termsAccepted = false;
      await _saveCart();
      return true;
    } catch (e) {
      error = bookingError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> addToWallet(ParkTicket ticket) async {
    wallet.add(ticket.id);
    await (await SharedPreferences.getInstance()).setStringList(
      'ticket_wallet_${repository.userId}',
      wallet.toList(),
    );
    notifyListeners();
  }

  /// Resolve the server state before allowing an uncertain request to be replaced.
  Future<bool> reviewPending() async {
    if (busy || pending == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (await repository.orderExists(pending!.requestId)) {
        error =
            'This booking is already confirmed. Retry checkout to open your tickets.';
        return false;
      }
      await pendingStore.clear(repository.userId!);
      pending = null;
      termsAccepted = false;
      return true;
    } catch (e) {
      error = bookingError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

String bookingError(Object error) {
  if (error is ApplicationApiException) return error.message;
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'This action could not be authorised. Check that your email is verified, then try again.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Unable to connect. Your checkout is saved; retry when you are online.';
  }
  if (error is StateError) return error.message;
  if (text.contains('failed-precondition')) {
    return text.replaceFirst(RegExp(r'^.*?\] '), '');
  }
  return 'We could not complete this action. Please try again.';
}
