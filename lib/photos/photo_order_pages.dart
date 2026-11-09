import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../attractions/models/park_time.dart';
import '../device/nfc_pass.dart';
import 'photo_repository.dart';
import 'photo_widgets.dart';
import 'photo_gallery_pages.dart';
import 'photo_session_scope.dart';

void returnToPhotoHub(BuildContext context, PhotoRepository repository) =>
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'photos-hub'),
        builder: (_) => PhotoHubPage(repository: repository),
      ),
      (route) => route.isFirst,
    );
Future<void> photoReceipt(BuildContext context, ParkPhoto order) async {
  try {
    final pdf = pw.Document(),
        items = (order.data['items'] as List).cast<Map>();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'THEME PARK',
            style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Photo Purchase Receipt',
            style: const pw.TextStyle(fontSize: 19),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Order: ${photoOrderReference(order.id)}'),
          pw.Text('Status: Confirmed'),
          if (order.data['createdAt'] is Timestamp)
            pw.Text(
              'Date: ${ParkTime.date((order.data['createdAt'] as Timestamp).toDate())}',
            ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Photo', 'Format', 'Copies', 'Amount'],
            data: items
                .map(
                  (i) => [
                    i['title'],
                    photoFormat(i['format'] as String),
                    '${i['quantity'] ?? 1}',
                    photoMoney(i['priceMinor'] as num),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Subtotal: ${photoMoney(order.data['subtotalMinor'] as num)}',
          ),
          pw.Text(
            'Promotion: ${photoMoney(-(order.data['discountMinor'] as num))}',
          ),
          pw.Text(
            'Points savings: ${photoMoney(-(order.data['pointsUsed'] as num))}',
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Total: ${photoMoney(order.data['totalMinor'] as num)}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Your digital photos are available in Photo Purchase History. Bring the collection pass to collect printed copies.',
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${photoOrderReference(order.id)}-receipt.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to download the receipt. Please try again.'),
        ),
      );
    }
  }
}

class _PhotoOrderView extends StatefulWidget {
  final PhotoRepository repository;
  final String orderId, title;
  final Widget Function(BuildContext, ParkPhoto) builder;
  const _PhotoOrderView({
    required this.repository,
    required this.orderId,
    required this.title,
    required this.builder,
  });
  @override
  State<_PhotoOrderView> createState() => _PhotoOrderViewState();
}

class _PhotoOrderViewState extends State<_PhotoOrderView> {
  late Stream<ParkPhoto?> stream = widget.repository.order(widget.orderId);
  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: widget.title,
    body: StreamBuilder<ParkPhoto?>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load this order. Its confirmation is saved in Photo Purchase History.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => stream = widget.repository.order(widget.orderId),
                    ),
                    child: const Text('Refresh Order'),
                  ),
                ],
              ),
            ),
          );
        }
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.data == null) {
          return const Center(child: Text('Photo order not found.'));
        }
        return widget.builder(context, s.data!);
      },
    ),
  );
}

class PhotoPaymentSuccessPage extends StatelessWidget {
  final PhotoRepository repository;
  final String orderId;
  const PhotoPaymentSuccessPage({
    super.key,
    required this.repository,
    required this.orderId,
  });
  @override
  Widget build(BuildContext context) => _PhotoOrderView(
    repository: repository,
    orderId: orderId,
    title: 'Purchase Confirmed',
    builder: (context, order) {
      final items = (order.data['items'] as List).cast<Map>(),
          digital = items.where((i) => i['format'] != 'print').length,
          print = items
              .where((i) => i['format'] != 'digital')
              .fold(
                0,
                (totalCopies, i) => totalCopies + (i['quantity'] as int? ?? 1),
              );
      return ListView(
        padding: const EdgeInsets.all(23),
        children: [
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 49,
              backgroundColor: photoRose,
              child: Icon(Icons.check, size: 65, color: Colors.white),
            ),
          ),
          const SizedBox(height: 23),
          const Text(
            'Your photos are ready!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: photoInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Order total ${photoMoney(order.data['totalMinor'] as num)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7C8289)),
          ),
          const SizedBox(height: 25),
          PhotoPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.confirmation_number_outlined,
                size: 37,
                color: photoRose,
              ),
              title: Text(
                'Order ${photoOrderReference(order.id)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${items.length} photos • Confirmed',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (digital > 0) ...[
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Digital delivery',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.data['emailStatus'] == 'sent'
                        ? 'Email sent to ${order.data['deliveryEmail'] ?? repository.email}'
                        : order.data['emailStatus']=='attention'?'Email delivery could not be confirmed. Your digital copies are ready to download.':'Your digital copies are ready to download. Email delivery is pending.',
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 13),
                  PhotoButton(
                    'View Digital Photos',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoOrderDetailPage(
                          repository: repository,
                          orderId: order.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (print > 0) ...[
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Print at kiosk',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '$print printed copies ready for kiosk collection.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 13),
                  PhotoButton(
                    'View Kiosk Pass',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoKioskPassPage(
                          repository: repository,
                          order: order,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          PhotoButton(
            'Download Receipt',
            onPressed: () => photoReceipt(context, order),
            outlined: true,
            icon: Icons.download_outlined,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => returnToPhotoHub(context, repository),
            child: const Text('← Back to My Park Photos'),
          ),
        ],
      );
    },
  );
}

class PhotoOrderDetailPage extends StatelessWidget {
  final PhotoRepository repository;
  final String orderId;
  const PhotoOrderDetailPage({
    super.key,
    required this.repository,
    required this.orderId,
  });
  Future<void> resend(BuildContext context) async {
    try {
      final result = await repository.request('resendEmail', {
        'orderId': orderId,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['queued'] == true
                  ? 'Email delivery requested.'
                  : 'Email delivery is pending. Your photos are available to download.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(photoError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _PhotoOrderView(
    repository: repository,
    orderId: orderId,
    title: 'Order Confirmed',
    builder: (context, order) {
      final items = (order.data['items'] as List).cast<Map>(),
          digital = items.any((i) => i['format'] != 'print'),
          print = items.any((i) => i['format'] != 'digital');
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PhotoPanel(
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: photoRose, size: 35),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your photos are ready!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Order ${photoOrderReference(order.id)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C8289),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          PhotoPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order Summary',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      photoMoney(order.data['totalMinor'] as num),
                      style: const TextStyle(
                        fontSize: 19,
                        color: photoRose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 25),
                StreamBuilder<List<ParkPhoto>>(
                  stream: repository.orderPreviews(order.id),
                  builder: (context, snapshot) => Column(
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PhotoImage(
                                    snapshot.data
                                            ?.where(
                                              (p) =>
                                                  p.photoId == item['photoId'],
                                            )
                                            .firstOrNull
                                            ?.preview ??
                                        '',
                                    width: 90,
                                    height: 100,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          photoFormat(item['format'] as String),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          'Qty ${item['quantity'] ?? 1}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF7C8289),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          photoMoney(item['priceMinor'] as num),
                                          style: const TextStyle(
                                            color: photoRose,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (item['format'] != 'print')
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => downloadParkPhoto(
                                      context,
                                      repository,
                                      item['photoId'] as String,
                                      edits: Map<String, dynamic>.from(
                                        item['edits'] as Map? ?? {},
                                      ),
                                    ),
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('Download Photo'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (digital) ...[
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mail_outline, color: photoRose),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'Digital delivery',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        order.data['emailStatus'] == 'sent'
                            ? 'Sent'
                            : order.data['emailStatus']=='attention'?'Check delivery':order.data['emailStatus']=='queued'?'Queued':'Pending',
                        style: const TextStyle(color: photoRose, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.data['deliveryEmail'] as String? ?? repository.email,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  PhotoButton(
                    'Resend Email',
                    onPressed: () => resend(context),
                    outlined: true,
                    icon: Icons.send_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (print) ...[
            PhotoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kiosk printing',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: repository.kioskRequest(order.id),
                    builder: (context, s) => Text(
                      s.data?['status'] == 'collected'
                          ? 'Collected'
                          : s.data?['status'] == 'spooled'
                          ? 'Sent to printer'
                          : 'Ready to print',
                      style: const TextStyle(fontSize: 12, color: photoRose),
                    ),
                  ),
                  const SizedBox(height: 13),
                  PhotoButton(
                    'View Kiosk Pass',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoKioskPassPage(
                          repository: repository,
                          order: order,
                        ),
                      ),
                    ),
                    outlined: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          PhotoButton(
            'Download Receipt',
            onPressed: () => photoReceipt(context, order),
            outlined: true,
            icon: Icons.download_outlined,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => returnToPhotoHub(context, repository),
            child: const Text('← Back to My Park Photos'),
          ),
        ],
      );
    },
  );
}

class PhotoHistoryPage extends StatefulWidget {
  final PhotoRepository repository;
  const PhotoHistoryPage({super.key, required this.repository});
  @override
  State<PhotoHistoryPage> createState() => _PhotoHistoryPageState();
}

class _PhotoHistoryPageState extends State<PhotoHistoryPage> {
  late final stream = widget.repository.orders();
  final search = TextEditingController();
  String filter = 'All';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Photo Purchase History',
    body: StreamBuilder<List<ParkPhoto>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load photo orders. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = search.text.trim().toLowerCase(),
            orders = snapshot.data!.where((o) {
              final items = (o.data['items'] as List).cast<Map>();
              return (query.isEmpty ||
                      photoOrderReference(o.id).toLowerCase().contains(query) ||
                      items.any(
                        (i) =>
                            i['title'].toString().toLowerCase().contains(query),
                      )) &&
                  (filter == 'All' ||
                      items.any(
                        (i) => filter == 'Digital'
                            ? i['format'] != 'print'
                            : i['format'] != 'digital',
                      ));
            }).toList();
        return ListView(
          padding: const EdgeInsets.all(19),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Digital', label: Text('Digital')),
                ButtonSegment(value: 'Print', label: Text('Print')),
              ],
              selected: {filter},
              onSelectionChanged: (v) => setState(() => filter = v.single),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search order number or photo',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            if (orders.isEmpty)
              const PhotoPanel(
                child: Padding(
                  padding: EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 60,
                        color: photoRose,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No photo orders found',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Your confirmed photo purchases will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoOrderDetailPage(
                        repository: widget.repository,
                        orderId: order.id,
                      ),
                    ),
                  ),
                  child: PhotoPanel(
                    child: Row(
                      children: [
                        StreamBuilder<List<ParkPhoto>>(
                          stream: widget.repository.orderPreviews(order.id),
                          builder: (context, s) => PhotoImage(
                            s.data?.firstOrNull?.preview ?? '',
                            width: 86,
                            height: 101,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (order.data['items'] as List).first['title']
                                    as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                photoOrderReference(order.id),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7C8289),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(order.data['items'] as List).length} photos • Confirmed',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                photoMoney(order.data['totalMinor'] as num),
                                style: const TextStyle(
                                  color: photoRose,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 19),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const Text(
              'Receipts and photo details are available for each order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF7C8289)),
            ),
          ],
        );
      },
    ),
  );
}

class PhotoKioskPassPage extends StatefulWidget {
  final PhotoRepository repository;
  final ParkPhoto order;
  const PhotoKioskPassPage({
    super.key,
    required this.repository,
    required this.order,
  });
  @override
  State<PhotoKioskPassPage> createState() => _PhotoKioskPassPageState();
}

class _PhotoKioskPassPageState extends State<PhotoKioskPassPage> {
  late final stream = widget.repository.kioskRequest(widget.order.id),
      settings = widget.repository.settings();
  String get qr => 'PK1:${widget.order.id}:${widget.order.data['kioskCode']}';
  Future<void> navigate(Map<String, dynamic> config) async {
    final latitude = config['kioskLatitude'],
        longitude = config['kioskLongitude'];
    if (latitude is num && longitude is num) {
      if (!await launchUrl(
            Uri.https('www.google.com', '/maps/dir/', {
              'api': '1',
              'destination': '$latitude,$longitude',
              'travelmode': 'walking',
            }),
            mode: LaunchMode.externalApplication,
          ) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open directions. Please try again.'),
          ),
        );
      }
    } else if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo kiosk'),
          content: const Text(
            'Ask a park staff member for directions to the photo kiosk. Bring this collection pass.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  void enlarge() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Photo Collection Pass',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1,
              child: QrImageView(data: qr, backgroundColor: Colors.white),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Kiosk Print Pass',
    body: StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load this collection pass. Please try again.',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final request = snapshot.data;
        if (request == null) {
          return const Center(
            child: Text('No printed photos are included in this order.'),
          );
        }
        final collected = request['status'] == 'collected',
            items = (request['items'] as List).cast<Map>(),
            copies = items.fold(
              0,
              (total, item) => total + (item['quantity'] as int? ?? 1),
            );
        return StreamBuilder<Map<String, dynamic>>(
          stream: settings,
          builder: (context, config) => ListView(
            padding: const EdgeInsets.all(21),
            children: [
              Center(
                child: Chip(
                  avatar: Icon(
                    collected
                        ? Icons.check_circle_outline
                        : Icons.print_outlined,
                    color: Colors.green.shade700,
                  ),
                  label: Text(
                    collected
                        ? 'Collected'
                        : request['status'] == 'spooled'
                        ? 'Sent to printer'
                        : 'Ready to Print',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PhotoPanel(
                child: Column(
                  children: [
                    if (!collected)
                      QrImageView(
                        data: qr,
                        size: 245,
                        backgroundColor: Colors.white,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(45),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 100,
                          color: photoRose,
                        ),
                      ),
                    const SizedBox(height: 17),
                    Text(
                      collected
                          ? 'Your printed photos have been collected.'
                          : 'Scan this QR code at the photo kiosk',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (!collected) ...[
                      const SizedBox(height: 18),
                      PhotoButton(
                        'Enlarge QR Pass',
                        onPressed: enlarge,
                        outlined: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!collected) ...[
                PhotoPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.nfc, color: photoRose, size: 35),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Hold your phone near the kiosk reader',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 9),
                      FilledButton(
                        onPressed: () => NfcPassService.present(context, qr),
                        child: const Text(
                          'Tap with NFC',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PhotoPanel(
                child: Column(
                  children: [
                    _row(
                      Icons.confirmation_number_outlined,
                      'Order',
                      photoOrderReference(widget.order.id),
                    ),
                    const Divider(height: 26),
                    _row(
                      Icons.location_on_outlined,
                      'Kiosk',
                      config.data?['kioskName'] as String? ??
                          'Park Photo Kiosk',
                    ),
                    const Divider(height: 26),
                    _row(
                      Icons.collections_outlined,
                      'Quantity',
                      '$copies printed copies',
                    ),
                    for (final item in items) ...[
                      const Divider(height: 26),
                      _row(
                        Icons.aspect_ratio,
                        'Print options',
                        '${item['printSize'].toString().replaceAll('x', ' × ')} • ${item['finish']}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PhotoButton(
                PhotoSessionScope.of(context) == null
                    ? 'Navigate to Kiosk'
                    : 'Continue to Printing',
                onPressed: () => PhotoSessionScope.of(context) == null
                    ? navigate(config.data ?? {})
                    : PhotoSessionScope.of(context)!.finish(qr),
                outlined: true,
                icon: Icons.near_me_outlined,
              ),
              const SizedBox(height: 13),
              const Text(
                'Keep this pass private. Each printed order can be collected once.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF7C8289)),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 22, color: photoRose),
      const SizedBox(width: 13),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7C8289)),
        ),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
