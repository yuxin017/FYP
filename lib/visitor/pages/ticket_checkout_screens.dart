import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tickets.dart';
import '../services/ticket_journey.dart';
import '../services/ticket_receipt.dart';
import '../widgets/ticket_widgets.dart';
import 'tickets_page.dart';

class TicketCartScreen extends StatefulWidget {
  final TicketJourney journey;
  final VoidCallback onShop, onCheckout;
  const TicketCartScreen({
    super.key,
    required this.journey,
    required this.onShop,
    required this.onCheckout,
  });
  @override
  State<TicketCartScreen> createState() => _TicketCartScreenState();
}

class _TicketCartScreenState extends State<TicketCartScreen> {
  bool editing = false;
  @override
  Widget build(BuildContext context) {
    final j = widget.journey;
    return TicketPageBody(
      footer: j.cart.isEmpty
          ? null
          : TicketSurface(
              padding: const EdgeInsets.all(14),
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
                          ticketDisplayPrice(context, j.subtotal),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TicketButton(
                      'Checkout',
                      onPressed: widget.onCheckout,
                    ),
                  ),
                ],
              ),
            ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${j.cart.length} ${j.cart.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: ticketMuted),
              ),
            ),
            TextButton(
              onPressed: j.pending != null
                  ? null
                  : () => setState(() => editing = !editing),
              child: Text(
                editing ? 'Done' : 'Edit',
                style: const TextStyle(color: ticketRose),
              ),
            ),
          ],
        ),
        if (j.cart.isEmpty) ...[
          const SizedBox(height: 60),
          const Icon(
            Icons.shopping_cart_outlined,
            size: 60,
            color: ticketMutedRose,
          ),
          const SizedBox(height: 20),
          const Text(
            'Your next adventure starts here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose a park pass to add it to your cart.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ticketMuted),
          ),
          const SizedBox(height: 25),
          TicketButton('Browse Passes', onPressed: widget.onShop),
        ],
        for (final line in j.cart) ...[
          TicketLineSummary(line, showTotal: true),
          if (editing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TicketSurface(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Adults')),
                        TicketCounter(
                          label: 'adults',
                          value: line.adults,
                          minus: line.adults > 0 && line.quantity > 1
                              ? () => j.changeCount(
                                  line.id,
                                  line.adults - 1,
                                  line.children,
                                )
                              : null,
                          plus: j.quantity < 10
                              ? () => j.changeCount(
                                  line.id,
                                  line.adults + 1,
                                  line.children,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: Text('Children')),
                        TicketCounter(
                          label: 'children',
                          value: line.children,
                          minus: line.children > 0 && line.quantity > 1
                              ? () => j.changeCount(
                                  line.id,
                                  line.adults,
                                  line.children - 1,
                                )
                              : null,
                          plus: j.quantity < 10
                              ? () => j.changeCount(
                                  line.id,
                                  line.adults,
                                  line.children + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => j.remove(line.id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove pass'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (j.cart.isNotEmpty) ...[
          const TicketSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 20),
                TicketMeta(
                  Icons.confirmation_number_outlined,
                  'Digital QR ticket issued after payment',
                ),
                Divider(height: 30, color: ticketBorder),
                TicketMeta(
                  Icons.calendar_today_outlined,
                  'Admission is valid for the selected dates',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onShop,
            child: const Text('Add another pass'),
          ),
        ],
      ],
    );
  }
}

class TicketGuestsScreen extends StatelessWidget {
  final TicketJourney journey;
  final VoidCallback onContinue;
  const TicketGuestsScreen({
    super.key,
    required this.journey,
    required this.onContinue,
  });
  @override
  Widget build(BuildContext context) {
    final j = journey;
    var adult = 0, child = 0;
    return TicketPageBody(
      footer: TicketButton(
        'Continue to Review',
        onPressed: j.guestsComplete ? onContinue : null,
      ),
      children: [
        const TicketStepper(1),
        const SizedBox(height: 18),
        TicketSurface(
          color: const Color(0xFFF8F1EE),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${j.quantity} guests  •  ${j.cart.isEmpty ? '' : displayParkDate(j.cart.first.visitDate)}',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < j.guests.length; i++) ...[
          _GuestForm(
            key: ValueKey(j.guests[i].id),
            guest: j.guests[i],
            label: j.guests[i].type == 'adult'
                ? 'Adult ${++adult}'
                : 'Child ${++child}',
            initiallyExpanded: i == 0,
            profile: j.profile,
            locked: j.pending != null,
            onChanged: j.updateGuest,
          ),
          const SizedBox(height: 14),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: TicketMeta(
            Icons.info_outline,
            'Names must match each guest’s identification.',
          ),
        ),
      ],
    );
  }
}

class _GuestForm extends StatefulWidget {
  final TicketGuest guest;
  final String label;
  final BookingProfile profile;
  final bool initiallyExpanded, locked;
  final ValueChanged<TicketGuest> onChanged;
  const _GuestForm({
    super.key,
    required this.guest,
    required this.label,
    required this.profile,
    required this.initiallyExpanded,
    required this.locked,
    required this.onChanged,
  });
  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  late bool expanded = widget.initiallyExpanded;
  late final name = TextEditingController(text: widget.guest.fullName),
      email = TextEditingController(text: widget.guest.email);
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  void _update() => widget.onChanged(
    widget.guest.copyWith(
      fullName: name.text,
      email: email.text,
      assignedToMe: false,
    ),
  );
  @override
  Widget build(BuildContext context) => TicketSurface(
    padding: const EdgeInsets.all(15),
    color: const Color(0xFFFFFDFC),
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => expanded = !expanded),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF6ECEA),
                child: Icon(Icons.person_outline, color: ticketRose, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!expanded)
                      Text(
                        widget.guest.complete
                            ? widget.guest.fullName
                            : 'Guest details required',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.guest.complete
                              ? ticketMuted
                              : ticketRose,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: ticketMuted,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 17),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Full Name', style: TextStyle(color: ticketMuted)),
          ),
          const SizedBox(height: 7),
          TextFormField(
            key: Key('name-${widget.guest.id}'),
            controller: name,
            enabled: !widget.locked,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Enter guest’s full name',
            ),
            validator: (v) => (v ?? '').trim().length < 2
                ? 'Enter the guest’s full name'
                : null,
            onChanged: (_) => _update(),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Email Address', style: TextStyle(color: ticketMuted)),
          ),
          const SizedBox(height: 7),
          TextFormField(
            key: Key('email-${widget.guest.id}'),
            controller: email,
            enabled: !widget.locked,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLength: 254,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Enter guest’s email',
            ),
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                ? null
                : 'Enter a valid email address',
            onChanged: (_) => _update(),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Checkbox(
                value: widget.guest.assignedToMe,
                onChanged: widget.locked || widget.profile.email.isEmpty
                    ? null
                    : (value) {
                        if (value == true) {
                          name.text = widget.profile.fullName;
                          email.text = widget.profile.email;
                          widget.onChanged(
                            widget.guest.copyWith(
                              fullName: name.text,
                              email: email.text,
                              assignedToMe: true,
                            ),
                          );
                        } else {
                          widget.onChanged(
                            widget.guest.copyWith(assignedToMe: false),
                          );
                        }
                      },
              ),
              const Expanded(
                child: Text(
                  'Assign this ticket to me',
                  style: TextStyle(color: ticketMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class TicketReviewScreen extends StatelessWidget {
  final TicketJourney journey;
  final VoidCallback onContinue;
  const TicketReviewScreen({
    super.key,
    required this.journey,
    required this.onContinue,
  });
  @override
  Widget build(BuildContext context) {
    final j = journey;
    return TicketPageBody(
      footer: TicketButton(
        'Proceed to Payment',
        onPressed: j.guestsComplete && j.termsAccepted ? onContinue : null,
      ),
      children: [
        const TicketStepper(2),
        const SizedBox(height: 14),
        for (final line in j.cart) ...[
          TicketLineSummary(line),
          const SizedBox(height: 14),
        ],
        const Text(
          'Order Details',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final line in j.cart)
          for (final type in ['adult', 'child'])
            if ((type == 'adult' ? line.adults : line.children) > 0) ...[
              TicketSurface(
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF8F1EF),
                      child: Icon(Icons.person_outline, color: ticketRose),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'adult'
                                ? 'Adult Day Pass'
                                : 'Child Day Pass',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            type == 'adult' ? 'Age 12+' : 'Age 3–11',
                            style: const TextStyle(
                              color: ticketMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${priceLabel(type == 'adult' ? line.adultPriceMinor : line.childPriceMinor)} × ${type == 'adult' ? line.adults : line.children}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      priceLabel(
                        (type == 'adult'
                            ? line.adults * line.adultPriceMinor
                            : line.children * line.childPriceMinor),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
        TicketSurface(
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: ticketRose,
                    child: Icon(Icons.star_outline, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Use Loyalty Points',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${j.profile.points} points available',
                          style: const TextStyle(
                            color: ticketMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: j.pointsUsed > 0,
                    onChanged: j.maxPoints < 100 || j.pending != null
                        ? null
                        : (value) => j.setPoints(value ? j.maxPoints : 0),
                  ),
                ],
              ),
              if (j.pointsUsed > 0) ...[
                const SizedBox(height: 12),
                TicketSurface(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(child: Text('${j.pointsUsed} points')),
                      TicketCounter(
                        label: 'loyalty points',
                        value: j.pointsUsed ~/ 100,
                        minus: () => j.setPoints(j.pointsUsed - 100),
                        plus: j.pointsUsed < j.maxPoints
                            ? () => j.setPoints(j.pointsUsed + 100)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'You save ${priceLabel(j.pointsUsed)}',
                    style: const TextStyle(
                      color: ticketRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        TicketPromotionField(journey: j),
        const SizedBox(height: 14),
        TicketSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _amount('Subtotal', j.subtotal),
              if (j.discountMinor > 0) ...[
                const SizedBox(height: 12),
                _amount('Promotion discount', -j.discountMinor),
              ],
              const SizedBox(height: 12),
              _amount('Points discount', -j.pointsUsed),
              const Divider(height: 24, color: ticketBorder),
              _amount('Total', j.total, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              key: const Key('ticket-terms'),
              value: j.termsAccepted,
              onChanged: j.pending != null
                  ? null
                  : (v) => j.acceptTerms(v ?? false),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('I agree to the ', style: TextStyle(fontSize: 13)),
                  InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Ticket Terms & Conditions'),
                        content: const Text(
                          'Tickets are non-refundable and valid for their selected admission dates. Adult tickets are for ages 12 and above; child tickets are for ages 3–11. Guest names must match identification. Each QR code admits one guest and can be used only once. Keep ticket codes private. Multi-day passes cover consecutive days from the selected start date.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text(
                      'Ticket Terms & Conditions.',
                      style: TextStyle(color: ticketRose, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _amount(String label, int amount, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: bold ? 17 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
      Text(
        '${amount < 0 ? '− ' : ''}${priceLabel(amount.abs())}',
        style: TextStyle(
          fontSize: bold ? 23 : 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: bold || amount < 0 ? ticketRose : ticketInk,
        ),
      ),
    ],
  );
}

class TicketPromotionField extends StatefulWidget {
  final TicketJourney journey;
  const TicketPromotionField({super.key, required this.journey});
  @override
  State<TicketPromotionField> createState() => _TicketPromotionFieldState();
}

class _TicketPromotionFieldState extends State<TicketPromotionField> {
  late final code = TextEditingController(text: widget.journey.promoCode);
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.journey;
    return TicketSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Promotion Code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ticket-promotion'),
                  controller: code,
                  enabled: !j.busy && j.pending == null,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    hintText: 'Enter code',
                    counterText: '',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: j.busy || j.pending != null
                    ? null
                    : () => j.applyPromotion(code.text),
                child: const Text('Apply'),
              ),
            ],
          ),
          if (j.promoCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Colors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${j.promoCode} • Save ${money(j.discountMinor)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove promotion',
                  onPressed: j.busy || j.pending != null
                      ? null
                      : () {
                          code.clear();
                          j.applyPromotion('');
                        },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TicketPaymentScreen extends StatefulWidget {
  final TicketJourney journey;
  final Future<void> Function(String method, {String cardLast4}) onPay;
  const TicketPaymentScreen({
    super.key,
    required this.journey,
    required this.onPay,
  });
  @override
  State<TicketPaymentScreen> createState() => _TicketPaymentScreenState();
}

class _TicketPaymentScreenState extends State<TicketPaymentScreen> {
  late String method = widget.journey.pending?.paymentMethod ?? 'card';
  final card = TextEditingController(),
      expiry = TextEditingController(),
      cvv = TextEditingController();
  @override
  void dispose() {
    card.clear();
    expiry.clear();
    cvv.clear();
    card.dispose();
    expiry.dispose();
    cvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.journey;
    final locked = j.busy || j.pending != null;
    return TicketPageBody(
      footer: TicketButton(
        j.busy
            ? 'Confirming…'
            : j.pending != null
            ? 'Retry checkout'
            : 'Pay ${j.paymentLabel}',
        onPressed: j.busy
            ? null
            : () async {
                final last = card.text.length >= 4
                    ? card.text.substring(card.text.length - 4)
                    : '';
                await widget.onPay(method, cardLast4: last);
                card.clear();
                expiry.clear();
                cvv.clear();
              },
      ),
      children: [
        const TicketStepper(3),
        const SizedBox(height: 18),
        const Text(
          'Order Summary',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TicketSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total to Pay', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                j.paymentLabel,
                style: const TextStyle(
                  fontSize: 27,
                  color: ticketRose,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((j.pending?.currencyQuote ?? j.currencyQuote)
                  case final quote?) ...[
                const SizedBox(height: 10),
                Text(
                  '1 MYR = ${quote.rate} ${quote.currency} • Rate date ${quote.asOf}',
                  style: const TextStyle(fontSize: 12, color: ticketMuted),
                ),
              ],
              if (j.pending == null && j.paymentCurrency != 'MYR')
                TextButton(
                  onPressed: j.busy
                      ? null
                      : () => j.prepareCurrency(j.paymentCurrency),
                  child: const Text('Refresh Currency Quote'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        const Text(
          'Payment Method',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final option in [
          ('card', 'Credit / Debit Card', 'cards.png'),
          ('fpx', 'FPX Online Banking', 'fpx.png'),
          ('touch-go', 'Touch ’n Go eWallet', 'touch-go.png'),
          ('apple-pay', 'Apple Pay', 'apple-pay.png'),
          ('nfc', 'NFC payment', ''),
        ]) ...[
          TicketSurface(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                InkWell(
                  onTap: locked
                      ? null
                      : () => setState(() => method = option.$1),
                  child: Row(
                    children: [
                      Icon(
                        method == option.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: method == option.$1 ? ticketRose : ticketMuted,
                        size: 23,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.$2,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (option.$3.isNotEmpty)
                        Image.asset(
                          'assets/images/ticketing/${option.$3}',
                          height: 22,
                          width: 65,
                          fit: BoxFit.contain,
                        )
                      else
                        const Icon(Icons.contactless_outlined, size: 25),
                    ],
                  ),
                ),
                if (option.$1 == 'card' && method == 'card') ...[
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('payment-card'),
                    controller: card,
                    enabled: !locked,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      hintText: '••••  ••••  ••••  ••••',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: expiry,
                          enabled: !locked,
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'MM / YY',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cvv,
                          enabled: !locked,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(hintText: 'CVV'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const TicketMeta(
                    Icons.lock_outline,
                    'Card details are not saved on this device.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 12),
        const TicketMeta(
          Icons.lock_outline,
          'Your booking is securely saved to your account.',
        ),
        if (j.pending != null)
          TextButton(
            onPressed: j.busy
                ? null
                : () async {
                    if (await j.reviewPending() && context.mounted) {
                      context
                          .findAncestorStateOfType<TicketsPageState>()
                          ?.showSection('cart');
                    }
                  },
            child: const Text('Review or change this checkout'),
          ),
      ],
    );
  }
}

class TicketSuccessScreen extends StatelessWidget {
  final TicketJourney journey;
  final VoidCallback onDigital, onBack;
  const TicketSuccessScreen({
    super.key,
    required this.journey,
    required this.onDigital,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    final request = journey.completed;
    final order = journey.orders
        .where((o) => o.id == request?.requestId)
        .firstOrNull;
    return TicketPageBody(
      children: [
        Image.asset(
          'assets/images/ticketing/success.png',
          height: 205,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 5),
        const Text(
          'Your adventure is confirmed!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'Payment of ${request?.paymentLabel ?? order?.paymentLabel ?? priceLabel(0)} was successful.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: ticketMuted),
        ),
        const SizedBox(height: 22),
        if (request != null)
          for (final line in request.lines) ...[
            TicketLineSummary(line),
            const SizedBox(height: 8),
          ],
        TicketSurface(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Booking ID: ${order?.reference ?? (request == null ? '' : bookingReference(request.requestId, request.visitDate))}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const TicketBadge('Confirmed', green: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TicketSurface(
          color: Color(0xFFFBF2EF),
          child: Row(
            children: [
              Icon(Icons.qr_code, size: 37, color: ticketRose),
              SizedBox(width: 14),
              Icon(Icons.contactless_outlined, size: 32, color: ticketRose),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Your digital ticket is ready. Use the QR code at the park entrance.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        TicketButton(
          'View Digital Tickets',
          icon: Icons.confirmation_number_outlined,
          onPressed: onDigital,
        ),
        const SizedBox(height: 12),
        TicketButton(
          'Download Receipt',
          icon: Icons.download_outlined,
          outlined: true,
          onPressed: order == null
              ? null
              : () => downloadTicketReceipt(context, order),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child: const Text(
            'Back to Tickets',
            style: TextStyle(color: ticketRose, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
