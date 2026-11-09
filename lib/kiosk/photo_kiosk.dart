import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../admin/admin_widgets.dart';
import '../photos/photo_editor.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_widgets.dart';
import 'customer_session.dart';
import '../device/nfc_pass.dart';

Future<Uint8List> buildKioskPrintPdf(List<Map<String, dynamic>> images) async {
  final document = pw.Document();
  for (final image in images) {
    final provider = pw.MemoryImage(
      base64Decode(image['imageBase64'] as String),
    );
    final large = image['printSize'] == '8x10';
    final format = PdfPageFormat(
      (large ? 8 : 6) * PdfPageFormat.inch,
      (large ? 10 : 8) * PdfPageFormat.inch,
      marginAll: 0,
    );
    for (int copy = 0; copy < (image['quantity'] as int? ?? 1); copy++) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(provider, fit: pw.BoxFit.contain)),
        ),
      );
    }
  }
  return document.save();
}

class PhotoKiosk extends StatefulWidget {
  final PhotoRepository repository;
  final Future<void> Function() onSignOut;
  final Future<bool> Function(Uint8List bytes, String name)? printDocument;
  const PhotoKiosk({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.printDocument,
  });
  @override
  State<PhotoKiosk> createState() => _PhotoKioskState();
}

class _PhotoKioskState extends State<PhotoKiosk> {
  final code = TextEditingController(), inputFocus = FocusNode();
  Map<String, dynamic>? request;
  String? currentCode, error;
  bool busy = false, camera = false, waitingForPrinter = false;
  @override
  void dispose() {
    code.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get images => (request?['images'] as List? ?? [])
      .map((i) => Map<String, dynamic>.from(i))
      .toList();
  Future<void> retrieve([String? scanned]) async {
    if (busy) return;
    final value = scanned ?? code.text.trim();
    if (value.isEmpty) {
      setState(
        () => error = 'Scan your photo collection pass or enter its QR value.',
      );
      return;
    }
    setState(() {
      busy = true;
      camera = false;
      error = null;
    });
    try {
      final result = await widget.repository.request('kioskRetrieve', {
        'code': value,
      });
      if (mounted) {
        setState(() {
          request = result;
          currentCode = value;
          code.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> photo) async {
    if (busy || request == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final source = await widget.repository.request('kioskEditSource', {
        'requestId': request!['requestId'],
        'photoId': photo['photoId'],
      });
      if (!mounted) return;
      final edits = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEditorPage(
            preview: source['imageBase64'] as String,
            initialEdits: Map<String, dynamic>.from(
              source['edits'] as Map? ?? {},
            ),
          ),
        ),
      );
      if (edits != null) {
        await widget.repository.request('kioskSaveEdits', {
          'requestId': request!['requestId'],
          'photoId': photo['photoId'],
          'edits': edits,
        });
        final updated = await widget.repository.request('kioskRetrieve', {
          'code': currentCode,
        });
        if (mounted) setState(() => request = updated);
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printPhotos() async {
    if (busy || request == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await buildKioskPrintPdf(images);
      final sent = widget.printDocument != null
          ? await widget.printDocument!(
              bytes,
              'ThemePark-${request!['requestId']}.pdf',
            )
          : await Printing.layoutPdf(
              name: 'ThemePark-${request!['requestId']}.pdf',
              onLayout: (_) async => bytes,
              dynamicLayout: false,
            );
      if (sent) {
        if (!mounted) return;
        setState(() => waitingForPrinter = true);
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm printer status'),
            content: const Text(
              'Did the printer accept this photo job? Confirm after selecting the printer and sending the requested copies.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Sent'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Job Sent to Printer'),
              ),
            ],
          ),
        );
        if (mounted) setState(() => waitingForPrinter = false);
        if (accepted != true || !mounted) return;
        await widget.repository.request('kioskStatus', {
          'requestId': request!['requestId'],
          'status': 'spooled',
        });
        if (mounted) {
          setState(() => request = {...request!, 'status': 'spooled'});
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> collect() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm photo collection'),
        content: const Text(
          'Confirm that the printed copies are ready and have been handed to this visitor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Collected'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || request == null) return;
    setState(() => busy = true);
    try {
      await widget.repository.request('kioskStatus', {
        'requestId': request!['requestId'],
        'status': 'collected',
      });
      if (mounted) {
        setState(() => request = {...request!, 'status': 'collected'});
      }
    } catch (e) {
      if (mounted) setState(() => error = photoError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clear() {
    setState(() {
      request = null;
      currentCode = null;
      error = null;
      camera = false;
      code.clear();
    });
    PaintingBinding.instance.imageCache.clearLiveImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) inputFocus.requestFocus();
    });
  }

  Future<void> nfcInstructions() async {
    final value = await NfcPassService.read(context);
    if (value != null && mounted) await retrieve(value);
    if (mounted) inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = request?['status'] as String?,
        printed = state == 'spooled',
        collected = state == 'collected';
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: adminBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Theme Park Photo Kiosk',
            style: TextStyle(fontWeight: FontWeight.w700, color: adminDark),
          ),
          actions: [
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/admin',
                      (r) => false,
                    ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin Portal'),
            ),
            TextButton(
              onPressed: busy ? null : widget.onSignOut,
              child: const Text('Sign Out'),
            ),
            const SizedBox(width: 15),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(27),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bring your park memories home',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      color: adminDark,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Scan your collection pass, preview your photos and collect your prints.',
                    style: TextStyle(fontSize: 15, color: adminMuted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 22,
                    runSpacing: 12,
                    children: [
                      _step(1, 'Scan Pass', request != null),
                      _step(2, 'Preview & Edit', printed || collected),
                      _step(3, 'Print & Collect', collected),
                    ],
                  ),
                  const SizedBox(height: 25),
                  if (request == null)
                    _scanner()
                  else ...[
                    AdminCard(
                      child: Row(
                        children: [
                          Icon(
                            collected
                                ? Icons.check_circle_outline
                                : Icons.confirmation_number_outlined,
                            size: 38,
                            color: adminRose,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photoOrderReference(
                                    request!['requestId'] as String,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${images.length} photos • ${images.fold<int>(0, (total, p) => total + (p['quantity'] as int? ?? 1))} printed copies',
                                  style: const TextStyle(color: adminMuted),
                                ),
                              ],
                            ),
                          ),
                          AdminBadge(
                            collected
                                ? 'Collected'
                                : printed
                                ? 'Sent to printer'
                                : 'Ready to print',
                            tone: 'active',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 23),
                    LayoutBuilder(
                      builder: (context, c) {
                        final columns = c.maxWidth > 850
                            ? 3
                            : c.maxWidth > 520
                            ? 2
                            : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: images.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 19,
                                mainAxisSpacing: 19,
                                childAspectRatio: .82,
                              ),
                          itemBuilder: (context, index) {
                            final photo = images[index];
                            return AdminCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: PhotoImage(
                                      photo['imageBase64'] as String,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Text(
                                    photo['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    '${photo['printSize'].toString().replaceAll('x', ' × ')} • ${photo['finish']} • Qty ${photo['quantity'] ?? 1}',
                                    style: const TextStyle(
                                      color: adminMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AdminButton(
                                    'Edit Photo',
                                    outlined: true,
                                    icon: Icons.edit_outlined,
                                    onPressed: busy || printed || collected
                                        ? null
                                        : () => edit(photo),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            collected
                                ? 'Your photos have been collected'
                                : printed
                                ? 'Collect the printed copies'
                                : 'Ready to print your photos',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: adminDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            collected
                                ? 'Thank you for visiting Theme Park.'
                                : 'Check the photo sizes and load the selected paper finish before printing. Confirm collection after the copies have been handed to the visitor.',
                            style: const TextStyle(
                              color: adminMuted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 15,
                            runSpacing: 14,
                            children: [
                              if (!collected)
                                AdminButton(
                                  printed ? 'Print Again' : 'Print Photos',
                                  onPressed: busy ? null : printPhotos,
                                  icon: Icons.print_outlined,
                                ),
                              if (printed && !collected)
                                AdminButton(
                                  'Confirm Printed & Collected',
                                  onPressed: busy ? null : collect,
                                  icon: Icons.check_circle_outline,
                                ),
                              AdminButton(
                                collected
                                    ? 'Next Visitor'
                                    : 'Scan Another Pass',
                                outlined: true,
                                onPressed: busy ? null : clear,
                                icon: Icons.qr_code_scanner,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (busy && !waitingForPrinter)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: LinearProgressIndicator(color: adminRose),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(int value, String text, bool complete) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: complete ? adminRose : const Color(0xFFF4E4E0),
        child: complete
            ? const Icon(Icons.check, size: 19, color: Colors.white)
            : Text(
                '$value',
                style: const TextStyle(
                  color: adminRose,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: adminDark,
        ),
      ),
    ],
  );
  Widget _scanner() => AdminCard(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome to the photo kiosk',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Have your photo collection QR or NFC pass ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: adminMuted),
          ),
          const SizedBox(height: 25),
          if (camera)
            SizedBox(
              height: 290,
              child: MobileScanner(
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null && !busy) retrieve(value);
                },
                errorBuilder: (_, e) => const Center(
                  child: Text(
                    'Camera unavailable. Enter the collection code instead.',
                  ),
                ),
              ),
            )
          else
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF1EF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                size: 115,
                color: adminRose,
              ),
            ),
          const SizedBox(height: 25),
          Center(
            child: Wrap(
              spacing: 15,
              runSpacing: 12,
              children: [
                AdminButton(
                  camera ? 'Close Camera' : 'Scan QR Pass',
                  outlined: true,
                  icon: Icons.camera_alt_outlined,
                  onPressed: busy
                      ? null
                      : () => setState(() => camera = !camera),
                ),
                AdminButton(
                  'Use NFC Reader',
                  outlined: true,
                  icon: Icons.nfc,
                  onPressed: busy ? null : nfcInstructions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: code,
            focusNode: inputFocus,
            autofocus: true,
            enabled: !busy,
            onSubmitted: retrieve,
            decoration: const InputDecoration(
              labelText: 'Collection pass value',
              hintText: 'PK1:…',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 17),
          AdminButton(
            'Open Photo Order',
            onPressed: busy ? null : () => retrieve(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 23),
            child: Divider(),
          ),
          const Text(
            'Choose and purchase at this kiosk',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'View your gallery, edit your photos, choose print sizes and use your points.',
            textAlign: TextAlign.center,
            style: TextStyle(color: adminMuted),
          ),
          const SizedBox(height: 18),
          AdminButton(
            'Browse & Purchase Photos',
            outlined: true,
            icon: Icons.add_photo_alternate_outlined,
            onPressed: busy
                ? null
                : () async {
                    setState(() => camera = false);
                    final pass = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KioskCustomerSession(),
                      ),
                    );
                    if (pass != null && mounted) await retrieve(pass);
                  },
          ),
        ],
      ),
    ),
  );
}
