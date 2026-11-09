import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../visits/visit_repository.dart';
import '../attractions/models/park_time.dart';
import 'admin_widgets.dart';
import '../device/nfc_pass.dart';

class RideEntryPage extends StatefulWidget {
  final VisitRepository repository;
  const RideEntryPage({super.key, required this.repository});
  @override
  State<RideEntryPage> createState() => _RideEntryPageState();
}

class _RideEntryPageState extends State<RideEntryPage> {
  final code = TextEditingController();
  Stream<AttractionVisit?>? stream;
  String? id, error;
  bool camera = false, busy = false;
  Map<String, dynamic>? result;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void lookup(String value) {
    if (busy) return;
    final clean = value.trim().replaceFirst(RegExp(r'^RQ1:'), '');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(clean)) {
      setState(
        () => error =
            'Scan an attraction entrance QR or enter its reservation reference.',
      );
      return;
    }
    setState(() {
      id = clean;
      stream = widget.repository.visit(clean);
      camera = false;
      result = null;
      error = null;
    });
  }

  Future<void> admit() async {
    if (id == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.repository.checkIn(id!);
      if (mounted) setState(() => result = saved);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Attraction Check-in',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: adminDark,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Validate a visitor’s return time, confirm entry and award attraction points.',
        style: TextStyle(color: adminMuted),
      ),
      const SizedBox(height: 25),
      LayoutBuilder(
        builder: (context, c) {
          final scan = AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Scan Attraction Entrance Pass',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                if (camera)
                  SizedBox(
                    height: 270,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final value = capture.barcodes.firstOrNull?.rawValue;
                        if (value != null) lookup(value);
                      },
                      errorBuilder: (_, error) => const Center(
                        child: Text(
                          'Camera access is unavailable. Enter the pass reference below.',
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 210,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF1EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      size: 95,
                      color: adminRose,
                    ),
                  ),
                const SizedBox(height: 18),
                AdminButton(
                  camera ? 'Close Camera' : 'Open Camera',
                  onPressed: busy
                      ? null
                      : () => setState(() => camera = !camera),
                  outlined: true,
                  icon: Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 25),
                AdminButton(
                  'Read NFC Pass',
                  outlined: true,
                  icon: Icons.nfc,
                  onPressed: busy
                      ? null
                      : () async {
                          final value = await NfcPassService.read(context);
                          if (value != null && mounted) lookup(value);
                        },
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: code,
                  enabled: !busy,
                  onSubmitted: lookup,
                  decoration: const InputDecoration(
                    labelText: 'Attraction pass reference',
                    hintText: 'RQ1:… or reservation reference',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                AdminButton(
                  'Find Attraction Pass',
                  onPressed: busy ? null : () => lookup(code.text),
                ),
              ],
            ),
          );
          final details = AdminCard(
            child: stream == null
                ? const AdminEmpty(
                    'Ready to scan',
                    'The reservation and return window will appear here.',
                  )
                : StreamBuilder<AttractionVisit?>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const AdminEmpty(
                          'Unable to load pass',
                          'Check your access and try again.',
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final visit = snapshot.data;
                      if (visit == null) {
                        return const AdminEmpty(
                          'Pass not found',
                          'Check the reservation reference and scan again.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            visit.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            visit.startsAt == null
                                ? 'Visit time unavailable'
                                : '${ParkTime.date(visit.startsAt!)} • ${ParkTime.time(visit.startsAt!)}–${ParkTime.time(visit.endsAt!)}',
                          ),
                          const SizedBox(height: 16),
                          AdminBadge(
                            visit.stateAt(DateTime.now()),
                            tone: visit.status == 'checked_in'
                                ? 'active'
                                : 'pending',
                          ),
                          const SizedBox(height: 24),
                          if (result != null)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                result!['alreadyCheckedIn'] == true
                                    ? 'Entry was already confirmed. Points were awarded once.'
                                    : 'Entry confirmed. ${result!['points']} loyalty points awarded.',
                                style: const TextStyle(
                                  color: Color(0xFF28784A),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          AdminButton(
                            busy ? 'Confirming…' : 'Confirm Attraction Entry',
                            onPressed: busy || visit.status != 'confirmed'
                                ? null
                                : admit,
                            icon: Icons.check_circle_outline,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'The server checks the current return window, admission ticket and account status before saving entry.',
                            style: TextStyle(fontSize: 12, color: adminMuted),
                          ),
                        ],
                      );
                    },
                  ),
          );
          return c.maxWidth > 850
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: scan),
                    const SizedBox(width: 22),
                    Expanded(child: details),
                  ],
                )
              : Column(children: [scan, const SizedBox(height: 20), details]);
        },
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(error!, style: const TextStyle(color: adminRose)),
        ),
    ],
  );
}
