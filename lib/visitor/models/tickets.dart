import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

const ticketCastleAsset = 'assets/images/ticketing/castle.png';
const ticketAnnualAsset = 'assets/images/ticketing/annual-pass.png';
String money(int minor) => 'RM ${(minor / 100).toStringAsFixed(2)}';
String priceLabel(int minor) =>
    minor % 100 == 0 ? 'RM ${minor ~/ 100}' : money(minor);
DateTime parkToday([DateTime? now]) {
  final value = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime(value.year, value.month, value.day);
}

String visitDateString(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String displayParkDate(String date) {
  final value = DateTime.tryParse(date);
  if (value == null) return date;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String bookingReference(String id, String date) {
  final tail = id.length > 8 ? id.substring(0, 8) : id;
  return 'TP-${date.replaceAll('-', '').substring(2)}-${tail.toUpperCase()}';
}

class BookingProfile {
  final String uid, fullName, email;
  final int points;
  const BookingProfile({
    this.uid = '',
    this.fullName = '',
    this.email = '',
    this.points = 0,
  });
}

class TicketPackage {
  final String id, name, description, currency, category, imageAsset;
  final int priceMinor, durationDays, sortOrder;
  final int? childPriceMinor;
  final List<String> benefits;
  const TicketPackage({
    required this.id,
    required this.name,
    this.description = '',
    required this.priceMinor,
    this.currency = 'MYR',
    this.category = 'day',
    this.imageAsset = ticketCastleAsset,
    this.childPriceMinor,
    this.durationDays = 1,
    this.sortOrder = 0,
    this.benefits = const [
      'Access to all rides and attractions',
      'Live shows and parades',
      'Use of park facilities',
      'Scan QR code for park entry',
    ],
  });
  int get childPrice => childPriceMinor ?? priceMinor;
  String get shortName =>
      category == 'annual' ? 'Annual Pass' : '$durationDays-Day Pass';
  factory TicketPackage.fromMap(String id, Map<String, dynamic> data) =>
      TicketPackage(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String? ?? '',
        priceMinor: (data['priceMinor'] as num).toInt(),
        currency: data['currency'] as String? ?? 'MYR',
        childPriceMinor: (data['childPriceMinor'] as num?)?.toInt(),
        category: data['category'] as String? ?? 'day',
        imageAsset: data['imageAsset'] as String? ?? ticketCastleAsset,
        durationDays: (data['durationDays'] as num?)?.toInt() ?? 1,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
        benefits:
            (data['benefits'] as List?)?.whereType<String>().toList() ??
            const [
              'Access to all rides and attractions',
              'Live shows and parades',
              'Use of park facilities',
              'Scan QR code for park entry',
            ],
      );
}

class TicketCartLine {
  final String id, packageId, packageName, visitDate, imageAsset, category;
  final int adults, children, adultPriceMinor, childPriceMinor, durationDays;
  const TicketCartLine({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.visitDate,
    required this.adults,
    required this.children,
    required this.adultPriceMinor,
    required this.childPriceMinor,
    this.durationDays = 1,
    this.imageAsset = ticketCastleAsset,
    this.category = 'day',
  });
  int get quantity => adults + children;
  int get subtotal => adults * adultPriceMinor + children * childPriceMinor;
  String get guestSummary => [
    if (adults > 0) '$adults ${adults == 1 ? 'Adult' : 'Adults'}',
    if (children > 0) '$children ${children == 1 ? 'Child' : 'Children'}',
  ].join(' · ');
  TicketCartLine withCounts(int a, int c) => TicketCartLine(
    id: id,
    packageId: packageId,
    packageName: packageName,
    visitDate: visitDate,
    adults: a,
    children: c,
    adultPriceMinor: adultPriceMinor,
    childPriceMinor: childPriceMinor,
    durationDays: durationDays,
    imageAsset: imageAsset,
    category: category,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'packageId': packageId,
    'packageName': packageName,
    'visitDate': visitDate,
    'adults': adults,
    'children': children,
    'adultPriceMinor': adultPriceMinor,
    'childPriceMinor': childPriceMinor,
    'durationDays': durationDays,
    'imageAsset': imageAsset,
    'category': category,
  };
  factory TicketCartLine.fromMap(Map<String, dynamic> data) => TicketCartLine(
    id: data['id'] as String,
    packageId: data['packageId'] as String,
    packageName: data['packageName'] as String,
    visitDate: data['visitDate'] as String,
    adults: (data['adults'] as num).toInt(),
    children: (data['children'] as num).toInt(),
    adultPriceMinor: (data['adultPriceMinor'] as num).toInt(),
    childPriceMinor: (data['childPriceMinor'] as num).toInt(),
    durationDays: (data['durationDays'] as num?)?.toInt() ?? 1,
    imageAsset: data['imageAsset'] as String? ?? ticketCastleAsset,
    category: data['category'] as String? ?? 'day',
  );
}

class TicketGuest {
  final String id, lineId, type, fullName, email;
  final bool assignedToMe;
  const TicketGuest({
    required this.id,
    required this.lineId,
    required this.type,
    this.fullName = '',
    this.email = '',
    this.assignedToMe = false,
  });
  TicketGuest copyWith({String? fullName, String? email, bool? assignedToMe}) =>
      TicketGuest(
        id: id,
        lineId: lineId,
        type: type,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        assignedToMe: assignedToMe ?? this.assignedToMe,
      );
  bool get complete =>
      fullName.trim().length >= 2 &&
      fullName.trim().length <= 100 &&
      email.trim().length <= 254 &&
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  Map<String, dynamic> toMap() => {
    'id': id,
    'lineId': lineId,
    'type': type,
    'fullName': fullName.trim(),
    'email': email.trim().toLowerCase(),
    'assignedToMe': assignedToMe,
  };
  factory TicketGuest.fromMap(Map<String, dynamic> data) => TicketGuest(
    id: data['id'] as String,
    lineId: data['lineId'] as String,
    type: data['type'] as String,
    fullName: data['fullName'] as String? ?? '',
    email: data['email'] as String? ?? '',
    assignedToMe: data['assignedToMe'] as bool? ?? false,
  );
}

class ParkTicket {
  final String id,
      orderId,
      packageName,
      visitDate,
      status,
      purchaserUid,
      ownerUid;
  final String guestName, guestEmail, ticketType, displayCode, validUntil;
  final DateTime? createdAt;
  final List<DateTime> admissionDays;
  const ParkTicket({
    required this.id,
    required this.orderId,
    required this.packageName,
    required this.visitDate,
    required this.status,
    this.createdAt,
    this.purchaserUid = '',
    this.ownerUid = '',
    this.guestName = '',
    this.guestEmail = '',
    this.ticketType = 'adult',
    this.displayCode = '',
    this.validUntil = '',
    this.admissionDays = const [],
  });
  String get reference =>
      displayCode.isEmpty ? bookingReference(id, visitDate) : displayCode;
  String get qrData => 'TP1:$id';
  String get endDate => validUntil.isEmpty ? visitDate : validUntil;
  bool get admittedToday => admissionDays.any(
    (day) => visitDateString(day.toUtc()) == visitDateString(parkToday()),
  );
  String get filter {
    if (status == 'used' || admittedToday) return 'Used';
    if (status == 'valid' &&
        endDate.compareTo(visitDateString(parkToday())) >= 0) {
      return 'Upcoming';
    }
    return 'Expired';
  }

  factory ParkTicket.fromMap(String id, Map<String, dynamic> data) =>
      ParkTicket(
        id: id,
        orderId: data['orderId'] as String,
        packageName: data['packageName'] as String,
        visitDate: data['visitDate'] as String,
        status: data['status'] as String,
        ownerUid: data['ownerUid'] as String? ?? '',
        purchaserUid:
            data['purchaserUid'] as String? ??
            data['ownerUid'] as String? ??
            '',
        guestName: data['guestName'] as String? ?? '',
        guestEmail: data['guestEmail'] as String? ?? '',
        ticketType: data['ticketType'] as String? ?? 'adult',
        displayCode: data['displayCode'] as String? ?? '',
        validUntil: data['validUntil'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        admissionDays:
            (data['admissionDays'] as List?)
                ?.whereType<Timestamp>()
                .map((day) => day.toDate())
                .toList() ??
            [],
      );
}

class TicketCurrencyQuote {
  final String id, currency, asOf;
  final int amountMinor, baseMinor;
  final double rate;
  final DateTime? expiresAt;
  const TicketCurrencyQuote({
    required this.id,
    required this.currency,
    required this.amountMinor,
    required this.baseMinor,
    required this.rate,
    required this.asOf,
    this.expiresAt,
  });
  String get label => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
  Map<String, dynamic> toMap() => {
    'currencyQuoteId': id,
    'paymentCurrency': currency,
    'paymentTotalMinor': amountMinor,
    'exchangeRate': rate,
    'exchangeRateDate': asOf,
    if (expiresAt != null)
      'quoteExpiresAt': expiresAt!.toUtc().toIso8601String(),
  };
  factory TicketCurrencyQuote.fromMap(
    Map<String, dynamic> data,
    int baseMinor,
  ) => TicketCurrencyQuote(
    id: data['currencyQuoteId'] as String? ?? '',
    currency: data['paymentCurrency'] as String,
    amountMinor: (data['paymentTotalMinor'] as num).toInt(),
    baseMinor: baseMinor,
    rate: (data['exchangeRate'] as num).toDouble(),
    asOf: data['exchangeRateDate'] as String? ?? '',
    expiresAt: DateTime.tryParse(data['quoteExpiresAt'] as String? ?? ''),
  );
}

class TicketOrder {
  final String id,
      packageName,
      visitDate,
      requestId,
      paymentMethod,
      displayCode;
  final int quantity,
      totalMinor,
      subtotalMinor,
      pointsUsed,
      loyaltyEarnRate,
      discountMinor;
  final String promoCode;
  final DateTime? createdAt;
  final List<String> ticketIds;
  final List<TicketCartLine> lines;
  final TicketCurrencyQuote? currencyQuote;
  const TicketOrder({
    required this.id,
    required this.packageName,
    required this.visitDate,
    required this.requestId,
    required this.quantity,
    required this.totalMinor,
    this.createdAt,
    this.subtotalMinor = 0,
    this.pointsUsed = 0,
    this.loyaltyEarnRate = 1,
    this.discountMinor = 0,
    this.promoCode = '',
    this.paymentMethod = 'card',
    this.displayCode = '',
    this.ticketIds = const [],
    this.lines = const [],
    this.currencyQuote,
  });
  String get paymentLabel => currencyQuote?.label ?? priceLabel(totalMinor);
  String get reference =>
      displayCode.isEmpty ? bookingReference(id, visitDate) : displayCode;
  int get subtotal =>
      subtotalMinor == 0 ? totalMinor + pointsUsed : subtotalMinor;
  factory TicketOrder.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => TicketOrder(
    id: id,
    packageName: data['packageName'] as String,
    visitDate: data['visitDate'] as String,
    requestId: data['requestId'] as String,
    quantity: (data['quantity'] as num).toInt(),
    totalMinor: (data['totalMinor'] as num).toInt(),
    subtotalMinor: (data['subtotalMinor'] as num?)?.toInt() ?? 0,
    pointsUsed: (data['pointsUsed'] as num?)?.toInt() ?? 0,
    loyaltyEarnRate: (data['loyaltyEarnRate'] as num?)?.toInt() ?? 1,
    discountMinor: (data['discountMinor'] as num?)?.toInt() ?? 0,
    promoCode: data['promoCode'] as String? ?? '',
    paymentMethod: data['paymentMethod'] as String? ?? 'card',
    displayCode: data['displayCode'] as String? ?? '',
    ticketIds: (data['ticketIds'] as List?)?.whereType<String>().toList() ?? [],
    lines:
        (data['lineItems'] as List?)
            ?.map(
              (line) => TicketCartLine.fromMap(
                Map<String, dynamic>.from(line as Map),
              ),
            )
            .toList() ??
        [],
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    currencyQuote:
        data['paymentCurrency'] != null && data['paymentCurrency'] != 'MYR'
        ? TicketCurrencyQuote.fromMap(data, (data['totalMinor'] as num).toInt())
        : null,
  );
}

class TicketCheckout {
  final String packageId,
      visitDate,
      requestId,
      paymentMethod,
      cardLast4,
      promoCode;
  final int quantity, pointsUsed, discountMinor;
  final int? expectedUnitPriceMinor;
  final List<TicketCartLine> lines;
  final List<TicketGuest> guests;
  final TicketCurrencyQuote? currencyQuote;
  const TicketCheckout({
    required this.packageId,
    required this.visitDate,
    required this.requestId,
    required this.quantity,
    this.expectedUnitPriceMinor,
    this.lines = const [],
    this.guests = const [],
    this.pointsUsed = 0,
    this.paymentMethod = 'card',
    this.cardLast4 = '',
    this.promoCode = '',
    this.discountMinor = 0,
    this.currencyQuote,
  });
  factory TicketCheckout.journey({
    required String requestId,
    required List<TicketCartLine> lines,
    required List<TicketGuest> guests,
    int pointsUsed = 0,
    String paymentMethod = 'card',
    String cardLast4 = '',
    String promoCode = '',
    int discountMinor = 0,
    TicketCurrencyQuote? currencyQuote,
  }) {
    if (lines.isEmpty) throw ArgumentError('Choose a pass before checkout.');
    return TicketCheckout(
      packageId: lines.first.packageId,
      visitDate: lines.first.visitDate,
      requestId: requestId,
      quantity: lines.fold(
        0,
        (accumulatedQuantity, line) => accumulatedQuantity + line.quantity,
      ),
      lines: List.unmodifiable(lines),
      guests: List.unmodifiable(guests),
      pointsUsed: pointsUsed,
      paymentMethod: paymentMethod,
      cardLast4: cardLast4,
      promoCode: promoCode,
      discountMinor: discountMinor,
      currencyQuote: currencyQuote,
    );
  }
  bool get isJourney => lines.isNotEmpty;
  int get subtotal => isJourney
      ? lines.fold(0, (amount, line) => amount + line.subtotal)
      : (expectedUnitPriceMinor ?? 0) * quantity;
  int get total => subtotal - pointsUsed - discountMinor;
  String get paymentLabel => currencyQuote?.label ?? priceLabel(total);
  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'lines': lines.map((line) => line.toMap()).toList(),
            'guests': guests.map((guest) => guest.toMap()).toList(),
            'pointsUsed': pointsUsed,
            'paymentMethod': paymentMethod,
            'cardLast4': cardLast4,
            if (promoCode.isNotEmpty) 'promoCode': promoCode,
            if (discountMinor > 0) 'discountMinor': discountMinor,
            if (currencyQuote != null) ...currencyQuote!.toMap(),
          }),
        ),
      )
      .toString();
  Map<String, dynamic> toMap() => {
    'packageId': packageId,
    'visitDate': visitDate,
    'quantity': quantity,
    'requestId': requestId,
    if (expectedUnitPriceMinor != null)
      'expectedUnitPriceMinor': expectedUnitPriceMinor,
    if (isJourney) ...{
      'version': 2,
      'lines': lines.map((line) => line.toMap()).toList(),
      'guests': guests.map((guest) => guest.toMap()).toList(),
      'pointsUsed': pointsUsed,
      'paymentMethod': paymentMethod,
      'cardLast4': cardLast4,
      'promoCode': promoCode,
      'discountMinor': discountMinor,
      if (currencyQuote != null) ...currencyQuote!.toMap(),
    },
  };
  factory TicketCheckout.fromMap(Map<String, dynamic> data) => TicketCheckout(
    packageId: data['packageId'] as String,
    visitDate: data['visitDate'] as String,
    requestId: data['requestId'] as String,
    quantity: (data['quantity'] as num).toInt(),
    expectedUnitPriceMinor: (data['expectedUnitPriceMinor'] as num?)?.toInt(),
    lines:
        (data['lines'] as List?)
            ?.map(
              (line) => TicketCartLine.fromMap(
                Map<String, dynamic>.from(line as Map),
              ),
            )
            .toList() ??
        [],
    guests:
        (data['guests'] as List?)
            ?.map(
              (guest) =>
                  TicketGuest.fromMap(Map<String, dynamic>.from(guest as Map)),
            )
            .toList() ??
        [],
    pointsUsed: (data['pointsUsed'] as num?)?.toInt() ?? 0,
    paymentMethod: data['paymentMethod'] as String? ?? 'card',
    cardLast4: data['cardLast4'] as String? ?? '',
    promoCode: data['promoCode'] as String? ?? '',
    discountMinor: (data['discountMinor'] as num?)?.toInt() ?? 0,
    currencyQuote:
        data['paymentCurrency'] != null && data['paymentCurrency'] != 'MYR'
        ? TicketCurrencyQuote.fromMap(data, 0)
        : null,
  );
}
