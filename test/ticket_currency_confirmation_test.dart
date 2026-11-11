import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collaborative_asg/visitor/models/tickets.dart';
import 'package:collaborative_asg/visitor/services/ticket_repository.dart';
import 'widget_test.dart' show FakeTickets, ready, line, fillGuests;

class QuotedTickets extends FakeTickets {
  bool unavailable = false;
  @override
  Future<Map<String, dynamic>> promotionQuote(
    TicketCheckout request, {
    String paymentCurrency = 'MYR',
  }) async {
    if (unavailable) {
      throw StateError('Currency conversion is temporarily unavailable.');
    }
    return {
      'totalMinor': request.total,
      'discountMinor': 0,
      'allowPoints': true,
      'paymentCurrency': paymentCurrency,
      'paymentTotalMinor': (request.total * .25).round(),
      'exchangeRate': .25,
      'exchangeRateDate': '2026-11-10',
      'currencyQuoteId': 'isolated-quote',
      'quoteExpiresAt': DateTime.now()
          .add(const Duration(minutes: 15))
          .toUtc()
          .toIso8601String(),
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'a pending foreign-currency checkout preserves its quote and fingerprint through storage and a retry',
    () async {
      final repository = QuotedTickets()..failOnce = true,
          journey = await ready(repository);
      addTearDown(journey.dispose);
      journey.add(line());
      fillGuests(journey);
      expect(await journey.prepareCurrency('USD'), true);
      expect(journey.paymentLabel, 'USD 35.00');
      expect(await journey.pay('fpx'), false);
      final saved = await PendingTicketCheckoutStore().load('alice');
      expect(saved!.currencyQuote!.currency, 'USD');
      expect(saved.paymentLabel, 'USD 35.00');
      expect(saved.fingerprint, journey.pending!.fingerprint);
      expect(await journey.pay('fpx'), true);
      expect(
        repository.requests[0].requestId,
        repository.requests[1].requestId,
      );
      expect(journey.completed!.paymentLabel, 'USD 35.00');
    },
  );
  test(
    'unavailable or expired currency quotes prevent a new confirmation until refreshed',
    () async {
      final repository = QuotedTickets(), journey = await ready(repository);
      addTearDown(journey.dispose);
      journey.add(line());
      fillGuests(journey);
      repository.unavailable = true;
      expect(await journey.prepareCurrency('USD'), false);
      expect(await journey.pay('fpx'), false);
      expect(repository.requests, isEmpty);
      repository.unavailable = false;
      expect(await journey.prepareCurrency('USD'), true);
      final original = journey.currencyQuote!;
      journey.currencyQuote = TicketCurrencyQuote(
        id: original.id,
        currency: original.currency,
        amountMinor: original.amountMinor,
        baseMinor: original.baseMinor,
        rate: original.rate,
        asOf: original.asOf,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(await journey.pay('fpx'), false);
      expect(repository.requests, isEmpty);
      expect(await journey.prepareCurrency('USD'), true);
      expect(await journey.pay('fpx'), true);
    },
  );
}
