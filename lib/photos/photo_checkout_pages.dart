import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/application_api.dart';
import 'photo_repository.dart';
import 'photo_widgets.dart';
import 'photo_order_pages.dart';
export 'photo_order_pages.dart';

int photoItemPrice(PhotoCartItem item, Map<String, dynamic> settings) {
  final digital = (settings['digitalPriceMinor'] as num?)?.toInt() ?? 2500,
      print = (settings['printPriceMinor'] as num?)?.toInt() ?? 3500,
      bundle = (settings['bundlePriceMinor'] as num?)?.toInt() ?? 5000,
      large = item.printSize == '8x10'
          ? (settings['largePrintSurchargeMinor'] as num?)?.toInt() ?? 1000
          : 0;
  return item.format == 'digital'
      ? digital
      : item.format == 'print'
      ? (print + large) * item.quantity
      : bundle + print * (item.quantity - 1) + large * item.quantity;
}

Future<void> editPhotoDelivery(
  BuildContext context,
  PhotoRepository repo,
) async {
  await repo.cart.ready;
  if (!context.mounted) return;
  final email = TextEditingController(
    text: repo.cart.deliveryEmail.isEmpty
        ? repo.email
        : repo.cart.deliveryEmail,
  );
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: const Text('Delivery Email'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email address',
            errorText: error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = email.text.trim();
              if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(value) ||
                  value.length > 254) {
                set(() => error = 'Enter a valid email address.');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  email.dispose();
  if (result != null) {
    repo.cart.deliveryEmail = result;
    await repo.cart.save();
  }
}

class PhotoFormatPage extends StatefulWidget {
  final PhotoRepository repository;
  final ParkPhoto photo;
  final Map<String, dynamic> edits;
  final String preview, initialFormat;
  final bool ownsDigital;
  const PhotoFormatPage({
    super.key,
    required this.repository,
    required this.photo,
    required this.preview,
    this.edits = const {},
    this.initialFormat = 'digital',
    this.ownsDigital = false,
  });
  @override
  State<PhotoFormatPage> createState() => _PhotoFormatPageState();
}

class _PhotoFormatPageState extends State<PhotoFormatPage> {
  late String format = widget.ownsDigital ? 'print' : widget.initialFormat;
  late final settings = widget.repository.settings();
  int quantity = 1;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.repository.cart.ready.then((_) {
      if (mounted) setState(() {});
    });
  }

  PhotoCartItem item([String? forced]) => PhotoCartItem(
    photoId: widget.photo.photoId,
    title: widget.photo.title,
    preview: widget.preview,
    format: forced ?? format,
    quantity: forced == 'print'
        ? quantity
        : format == 'digital'
        ? 1
        : quantity,
    edits: widget.edits,
  );
  Future<void> add({bool kiosk = false}) async {
    final chosen = item(kiosk ? 'print' : null);
    if (chosen.format != 'digital') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoPrintOptionsPage(
            repository: widget.repository,
            item: chosen,
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.cart.add(chosen);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCartPage(repository: widget.repository),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Choose Photo Format',
    busy: busy,
    body: StreamBuilder<Map<String, dynamic>>(
      stream: settings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load photo prices. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final prices = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(19),
          children: [
            PhotoPanel(
              child: Row(
                children: [
                  PhotoImage(widget.preview, width: 93, height: 105),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.photo.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          (widget.edits['filter'] as String? ?? 'original')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: photoRose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            const Text(
              'Select Photo Format',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final option in ['digital', 'print', 'bundle'])
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: InkWell(
                  onTap: busy || widget.ownsDigital && option != 'print'
                      ? null
                      : () => setState(() {
                          format = option;
                          if (format == 'digital') quantity = 1;
                        }),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: format == option ? photoRose : photoBorder,
                        width: format == option ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          option == 'digital'
                              ? Icons.image_outlined
                              : option == 'print'
                              ? Icons.print_outlined
                              : Icons.collections_outlined,
                          color: photoRose,
                          size: 32,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                photoFormat(option),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final benefit
                                  in option == 'digital'
                                      ? [
                                          'High-resolution JPG',
                                          'Watermark-free',
                                          'Download after confirmation',
                                        ]
                                      : option == 'print'
                                      ? [
                                          '6 × 8 or 8 × 10 inch print',
                                          'Glossy or matte finish',
                                          'Collect from the photo kiosk',
                                        ]
                                      : [
                                          'High-resolution JPG',
                                          'Printed copy at the kiosk',
                                          'Both photo formats',
                                        ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '✓ $benefit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7C8289),
                                    ),
                                  ),
                                ),
                              if (widget.ownsDigital && option != 'print')
                                const Text(
                                  'Digital copy already purchased',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: photoRose,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(
                              format == option
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: photoRose,
                              size: 21,
                            ),
                            const SizedBox(height: 23),
                            Text(
                              photoMoney(
                                photoItemPrice(
                                  PhotoCartItem(
                                    photoId: widget.photo.photoId,
                                    title: widget.photo.title,
                                    preview: '',
                                    format: option,
                                  ),
                                  prices,
                                ),
                              ),
                              style: const TextStyle(
                                color: photoRose,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (format != 'digital')
              PhotoPanel(
                child: Row(
                  children: [
                    const Expanded(child: Text('Printed copies')),
                    IconButton(
                      tooltip: 'Fewer copies',
                      onPressed: quantity <= 1
                          ? null
                          : () => setState(() => quantity--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$quantity'),
                    IconButton(
                      tooltip: 'More copies',
                      onPressed: quantity >= 10
                          ? null
                          : () => setState(() => quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            PhotoPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline, color: photoRose),
                title: const Text(
                  'Delivery Email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.repository.cart.deliveryEmail.isEmpty
                      ? widget.repository.email
                      : widget.repository.cart.deliveryEmail,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await editPhotoDelivery(context, widget.repository);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Edit'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (error != null)
              Text(error!, style: const TextStyle(color: photoRose)),
            PhotoButton(
              'Add to Photo Cart',
              onPressed: add,
              busy: busy,
              icon: Icons.add_shopping_cart,
            ),
            const SizedBox(height: 12),
            PhotoButton(
              'Send to Kiosk Only',
              onPressed: () => add(kiosk: true),
              outlined: true,
              icon: Icons.qr_code,
            ),
          ],
        );
      },
    ),
  );
}

class PhotoPrintOptionsPage extends StatefulWidget {
  final PhotoRepository repository;
  final PhotoCartItem item;
  const PhotoPrintOptionsPage({
    super.key,
    required this.repository,
    required this.item,
  });
  @override
  State<PhotoPrintOptionsPage> createState() => _PhotoPrintOptionsPageState();
}

class _PhotoPrintOptionsPageState extends State<PhotoPrintOptionsPage> {
  late String size = widget.item.printSize, finish = widget.item.finish;
  late int quantity = widget.item.quantity;
  late final settings = widget.repository.settings();
  bool busy = false;
  String? error;
  PhotoCartItem get item => PhotoCartItem(
    photoId: widget.item.photoId,
    title: widget.item.title,
    preview: widget.item.preview,
    format: widget.item.format,
    quantity: quantity,
    printSize: size,
    finish: finish,
    edits: widget.item.edits,
  );
  Future<void> add() async {
    setState(() => busy = true);
    try {
      await widget.repository.cart.add(item);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCartPage(repository: widget.repository),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Send to Photo Kiosk',
    busy: busy,
    body: StreamBuilder<Map<String, dynamic>>(
      stream: settings,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PhotoImage(widget.item.preview, width: double.infinity, height: 235),
          const SizedBox(height: 20),
          PhotoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Print Size',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '6x8', label: Text('6 × 8')),
                    ButtonSegment(value: '8x10', label: Text('8 × 10')),
                  ],
                  selected: {size},
                  onSelectionChanged: busy
                      ? null
                      : (v) => setState(() => size = v.single),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Finish',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'glossy', label: Text('Glossy')),
                    ButtonSegment(value: 'matte', label: Text('Matte')),
                  ],
                  selected: {finish},
                  onSelectionChanged: busy
                      ? null
                      : (v) => setState(() => finish = v.single),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Quantity')),
                    IconButton(
                      tooltip: 'Fewer prints',
                      onPressed: busy || quantity == 1
                          ? null
                          : () => setState(() => quantity--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$quantity'),
                    IconButton(
                      tooltip: 'More prints',
                      onPressed: busy || quantity == 10
                          ? null
                          : () => setState(() => quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          PhotoPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined, color: photoRose),
              title: Text(
                snapshot.data?['kioskName'] as String? ?? 'Park Photo Kiosk',
              ),
              subtitle: const Text(
                'Collect with your photo collection pass.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PhotoPanel(
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: photoRose),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order total: ${photoMoney(photoItemPrice(item, snapshot.data ?? {}))}\nYour print options are saved with the order.',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (error != null)
            Text(error!, style: const TextStyle(color: photoRose)),
          PhotoButton(
            'Continue to Photo Cart',
            onPressed: add,
            busy: busy,
            icon: Icons.shopping_cart_outlined,
          ),
        ],
      ),
    ),
  );
}

class PhotoCartPage extends StatefulWidget {
  final PhotoRepository repository;
  const PhotoCartPage({super.key, required this.repository});
  @override
  State<PhotoCartPage> createState() => _PhotoCartPageState();
}

class _PhotoCartPageState extends State<PhotoCartPage> {
  final promo = TextEditingController();
  String applied = '';
  Map<String, dynamic>? quote;
  String? error;
  bool loading = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.repository.cart.addListener(changed);
    widget.repository.cart.ready.then((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    widget.repository.cart.removeListener(changed);
    promo.dispose();
    super.dispose();
  }

  void changed() {
    if (mounted) refresh();
  }

  Map<String, dynamic> get body => {
    'items': widget.repository.cart.items.map((i) => i.payload).toList(),
    'pointsUsed': 0,
    'promoCode': applied,
    'deliveryEmail': widget.repository.cart.deliveryEmail.isEmpty
        ? widget.repository.email
        : widget.repository.cart.deliveryEmail,
  };
  Future<void> refresh() async {
    final current = ++generation;
    if (widget.repository.cart.items.isEmpty) {
      setState(() {
        quote = null;
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.request('quote', body);
      if (mounted && current == generation) setState(() => quote = value);
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          quote = null;
          error = e.toString();
        });
      }
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Photo Cart',
    body: AnimatedBuilder(
      animation: widget.repository.cart,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(19),
        children: [
          Text(
            '${widget.repository.cart.items.length} items',
            style: const TextStyle(color: Color(0xFF7C8289), fontSize: 12),
          ),
          const SizedBox(height: 15),
          if (widget.repository.cart.items.isEmpty)
            const PhotoPanel(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 65,
                      color: photoRose,
                    ),
                    SizedBox(height: 17),
                    Text(
                      'Your photo cart is empty',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Choose a park photo and a format to save your memories.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (final item in widget.repository.cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: PhotoPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhotoImage(item.preview, width: 85, height: 105),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            photoFormat(item.format),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            item.format == 'digital'
                                ? 'High-resolution JPG'
                                : '${item.printSize.replaceAll('x', ' × ')} • ${item.finish}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C8289),
                            ),
                          ),
                          if (item.format != 'digital')
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Fewer copies',
                                  onPressed: item.quantity == 1
                                      ? null
                                      : () => widget.repository.cart.add(
                                          item.copies(item.quantity - 1),
                                        ),
                                  icon: const Icon(Icons.remove, size: 18),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  tooltip: 'More copies',
                                  onPressed: item.quantity == 10
                                      ? null
                                      : () => widget.repository.cart.add(
                                          item.copies(item.quantity + 1),
                                        ),
                                  icon: const Icon(Icons.add, size: 18),
                                ),
                              ],
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 9),
                              child: Text(
                                'Qty 1',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () =>
                          widget.repository.cart.remove(item.photoId),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: photoRose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.repository.cart.items.isNotEmpty) ...[
            const SizedBox(height: 9),
            const Text(
              'Promo code',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: promo,
                    decoration: const InputDecoration(
                      hintText: 'Enter promo code',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: loading
                      ? null
                      : () {
                          applied = promo.text.trim().toUpperCase();
                          refresh();
                        },
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PhotoPanel(
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Order Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  photoAmountRow('Subtotal', quote?['subtotalMinor']),
                  const SizedBox(height: 10),
                  photoAmountRow(
                    'Promotion',
                    quote == null ? null : -(quote!['discountMinor'] as num),
                  ),
                  const Divider(height: 27),
                  photoAmountRow('Total', quote?['totalMinor'], bold: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(error!, style: const TextStyle(color: photoRose)),
              ),
            PhotoButton(
              'Proceed to Payment',
              onPressed: quote == null || loading
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoPaymentPage(
                          repository: widget.repository,
                          promoCode: applied,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            PhotoPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline, color: photoRose),
                title: const Text(
                  'Digital delivery',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.repository.cart.deliveryEmail.isEmpty
                      ? widget.repository.email
                      : widget.repository.cart.deliveryEmail,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      editPhotoDelivery(context, widget.repository),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget photoAmountRow(String label, dynamic amount, {bool bold = false}) => Row(
  children: [
    Expanded(
      child: Text(
        label,
        style: TextStyle(
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
    Text(
      amount is num ? photoMoney(amount) : '—',
      style: TextStyle(
        fontSize: bold ? 20 : 13,
        color: bold ? photoRose : photoInk,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  ],
);

Future<Map<String, dynamic>> confirmPhotoPurchase(
  PhotoRepository repo,
  Map<String, dynamic> body,
) async {
  final prefs = await SharedPreferences.getInstance(),
      key = 'photo_purchase_pending_${repo.uid}';
  Map<String, dynamic>? pending;
  try {
    final raw = prefs.getString(key);
    if (raw != null) pending = Map<String, dynamic>.from(jsonDecode(raw));
  } catch (_) {
    await prefs.remove(key);
  }
  final previous = pending;
  if (previous != null) {
    final saved = await repo.request('purchaseState', {
      'requestId': previous['requestId'],
    });
    if (saved['found'] == true) {
      await prefs.remove(key);
      if (jsonEncode(previous['body']['items']) ==
          jsonEncode(repo.cart.items.map((i) => i.payload).toList())) {
        await repo.cart.clear();
      }
      return {...saved, 'recovered': true};
    }
    body = Map<String, dynamic>.from(previous['body'] as Map);
  } else {
    pending = {'requestId': repo.newRequestId(), 'body': body};
    await prefs.setString(key, jsonEncode(pending));
  }
  try {
    final result = await repo.request('checkout', {
      ...body,
      'requestId': pending!['requestId'],
    });
    await prefs.remove(key);
    if (jsonEncode(body['items']) ==
        jsonEncode(repo.cart.items.map((i) => i.payload).toList())) {
      await repo.cart.clear();
    }
    return {...result, 'recovered': previous != null};
  } on ApplicationApiException catch (e) {
    if ([
      'invalid-argument',
      'permission-denied',
      'failed-precondition',
      'already-exists',
    ].contains(e.code)) {
      await prefs.remove(key);
    }
    rethrow;
  }
}

class PhotoPaymentPage extends StatefulWidget {
  final PhotoRepository repository;
  final String promoCode;
  const PhotoPaymentPage({
    super.key,
    required this.repository,
    this.promoCode = '',
  });
  @override
  State<PhotoPaymentPage> createState() => _PhotoPaymentPageState();
}

class _PhotoPaymentPageState extends State<PhotoPaymentPage> {
  late final balance = widget.repository.balance();
  Map<String, dynamic>? quote;
  bool busy = false, loading = true, accepted = false, usePoints = false;
  int points = 0, generation = 0;
  String method = 'card';
  String? error;
  Map<String, dynamic> get body => {
    'items': widget.repository.cart.items.map((i) => i.payload).toList(),
    'pointsUsed': points,
    'promoCode': widget.promoCode,
    'deliveryEmail': widget.repository.cart.deliveryEmail.isEmpty
        ? widget.repository.email
        : widget.repository.cart.deliveryEmail,
  };
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.request('quote', body);
      if (mounted && current == generation) setState(() => quote = value);
    } catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  Future<void> pay() async {
    if (busy || loading || quote == null || !accepted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await confirmPhotoPurchase(widget.repository, {
        ...body,
        'expectedTotalMinor': quote!['totalMinor'],
        'paymentMethod': method,
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoPaymentSuccessPage(
              repository: widget.repository,
              orderId: result['orderId'] as String,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Payment',
    busy: busy,
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 13),
        PhotoPanel(
          child: photoAmountRow(
            'Total to Pay',
            quote?['totalMinor'],
            bold: true,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Payment Method',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        PhotoPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final option in [
                ('card', 'Credit / Debit Card', 'VISA · Mastercard'),
                ('fpx', 'FPX Online Banking', 'FPX'),
                ('tng', 'Touch ’n Go eWallet', 'TNG'),
                ('boost', 'Boost eWallet', 'Boost'),
                ('apple', 'Apple Pay', 'Apple Pay'),
              ])
                ListTile(
                  onTap: busy ? null : () => setState(() => method = option.$1),
                  leading: Icon(
                    method == option.$1
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: photoRose,
                    size: 22,
                  ),
                  title: Text(option.$2, style: const TextStyle(fontSize: 12)),
                  trailing: Text(
                    option.$3,
                    style: const TextStyle(
                      fontSize: 10,
                      color: photoRose,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<int>(
          stream: balance,
          builder: (context, s) {
            final max = (quote?['maxPoints'] as num?)?.toInt() ?? 0;
            return PhotoPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_outlined, color: photoRose),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Loyalty Points',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Available: ${s.data ?? 0} points',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C8289),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: usePoints,
                        onChanged: busy || loading || max < 100
                            ? null
                            : (v) {
                                setState(() {
                                  usePoints = v;
                                  points = v ? (max > 1000 ? 1000 : max) : 0;
                                });
                                refresh();
                              },
                      ),
                    ],
                  ),
                  if (usePoints && max >= 100) ...[
                    Text(
                      'Use $points points',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Slider(
                      min: 0,
                      max: max.toDouble(),
                      divisions: max ~/ 100,
                      value: points.toDouble().clamp(0, max.toDouble()),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              points = (v / 100).round() * 100;
                              loading = true;
                            }),
                      onChangeEnd: (_) => refresh(),
                    ),
                  ],
                  const Divider(height: 22),
                  photoAmountRow('Points savings', -points),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: accepted,
          onChanged: busy ? null : (v) => setState(() => accepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Wrap(
            children: [
              const Text('I agree to the ', style: TextStyle(fontSize: 11)),
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Photo Purchase Terms'),
                    content: const Text(
                      'Check your selected photos, edits, format and print options before confirming. Digital copies remain available in Photo Purchase History. Bring your collection pass to collect printed photos. Keep the pass private. Contact park support if you need help with an order.',
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
                  'Photo Purchase Terms.',
                  style: TextStyle(
                    fontSize: 11,
                    color: photoRose,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(error!, style: const TextStyle(color: photoRose)),
          ),
        const SizedBox(height: 12),
        PhotoButton(
          quote == null
              ? 'Pay & Confirm'
              : 'Pay ${photoMoney(quote!['totalMinor'] as num)}',
          onPressed: !accepted || loading || quote == null ? null : pay,
          busy: busy,
        ),
        const SizedBox(height: 15),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF7C8289), size: 13),
            SizedBox(width: 6),
            Text(
              'Your order is securely saved.',
              style: TextStyle(fontSize: 10, color: Color(0xFF7C8289)),
            ),
          ],
        ),
      ],
    ),
  );
}
