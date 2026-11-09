import 'package:flutter/material.dart';
import '../models/tickets.dart';

class TicketDisplayCurrency extends ChangeNotifier {
  final Future<Map<String, dynamic>> Function() fetchRates;
  TicketDisplayCurrency({required this.fetchRates});
  String selected = 'MYR', asOf = '';
  bool busy = false, disposed = false;
  Map<String, double> rates = {'MYR': 1};
  Future<void> choose(String code) async {
    if (busy || !['MYR', 'USD', 'SGD', 'CNY', 'EUR'].contains(code)) return;
    busy = true;
    notifyListeners();
    try {
      if (code != 'MYR') {
        final response = await fetchRates();
        if (disposed) return;
        rates = Map<String, dynamic>.from(
          response['rates'],
        ).map((key, value) => MapEntry(key, (value as num).toDouble()));
        asOf = response['asOf'] as String;
      }
      if (!disposed) selected = code;
    } finally {
      busy = false;
      if (!disposed) notifyListeners();
    }
  }

  String format(int amount) => selected == 'MYR'
      ? priceLabel(amount)
      : '≈ $selected ${(amount / 100 * (rates[selected] ?? 1)).toStringAsFixed(2)}';
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class TicketCurrencyScope extends InheritedNotifier<TicketDisplayCurrency> {
  final bool enabled;
  const TicketCurrencyScope({
    super.key,
    required TicketDisplayCurrency currency,
    required this.enabled,
    required super.child,
  }) : super(notifier: currency);
  @override
  bool updateShouldNotify(TicketCurrencyScope oldWidget) =>
      enabled != oldWidget.enabled || super.updateShouldNotify(oldWidget);
}

String ticketDisplayPrice(BuildContext context, int amount) {
  final scope = context
      .dependOnInheritedWidgetOfExactType<TicketCurrencyScope>();
  return scope?.enabled == true
      ? scope!.notifier!.format(amount)
      : priceLabel(amount);
}
