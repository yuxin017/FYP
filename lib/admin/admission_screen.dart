import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../device/nfc_pass.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../visitor/models/tickets.dart';
import 'admin_models.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';

class AdmissionScreen extends StatefulWidget {
  final AdminStore store;
  final ParkTicket? initialTicket;
  const AdmissionScreen({super.key, required this.store, this.initialTicket});
  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  late final code = TextEditingController(text: widget.initialTicket?.id ?? '');
  late ParkTicket? ticket = widget.initialTicket;
  late String requestId = widget.store.newRequestId();
  AdmissionResult? result;
  String? error;
  bool camera = false, busy = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> find(String value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final known = widget.store.tickets
          .where((t) => t.reference == value.trim().toUpperCase())
          .firstOrNull;
      final found = await widget.store.repository.findTicket(
        known?.id ?? value,
      );
      if (mounted) {
        setState(() {
          ticket = found;
          camera = false;
          requestId = widget.store.newRequestId();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          ticket = null;
          error = adminError(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> admit() async {
    if (busy || ticket == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final admitted = await widget.store.repository.admit(
        ticket!.id,
        requestId,
      );
      if (mounted) {
        setState(() {
          result = admitted;
          ticket = admitted.ticket;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = adminError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = visitDateString(parkToday());
    final eligible =
        ticket != null &&
        ticket!.filter == 'Upcoming' &&
        ticket!.visitDate.compareTo(today) <= 0;
    final scanner = AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan Ticket QR',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          AdminButton(
            'Read NFC Ticket',
            outlined: true,
            icon: Icons.nfc,
            onPressed: busy
                ? null
                : () async {
                    final value = await NfcPassService.read(context);
                    if (value != null && mounted) find(value);
                  },
          ),
          const SizedBox(height: 16),
          if (camera)
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null && !busy) find(value);
                  },
                  errorBuilder: (_, exception) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Unable to access the camera. Check its permission or enter the ticket ID below.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 230,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF1EF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: adminRose,
                size: 100,
              ),
            ),
          const SizedBox(height: 16),
          AdminButton(
            camera ? 'Close Camera' : 'Open Camera',
            icon: Icons.qr_code_scanner,
            outlined: true,
            onPressed:
                busy ||
                    (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                ? null
                : () => setState(() => camera = !camera),
          ),
          const SizedBox(height: 25),
          const Text(
            'Or enter Ticket ID',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            enabled: !busy,
            onSubmitted: find,
            decoration: const InputDecoration(
              hintText: 'TP-… or ticket QR value',
              prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          AdminButton(
            busy ? 'Checking…' : 'Find Ticket',
            onPressed: busy ? null : () => find(code.text),
          ),
        ],
      ),
    );
    final preview = AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admission Details',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          if (error != null)
            AdminCard(
              color: const Color(0xFFFFEFEF),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (ticket == null && error == null)
            const AdminEmpty(
              'Ready to scan',
              'Find a ticket to verify its admission date and status.',
              icon: Icons.confirmation_number_outlined,
            ),
          if (ticket != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                ticketCastleAsset,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              ticket!.packageName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _detail(
              'Guest',
              ticket!.guestName.isEmpty ? 'Not assigned' : ticket!.guestName,
            ),
            _detail('Ticket ID', ticket!.reference),
            _detail('Visit Date', displayParkDate(ticket!.visitDate)),
            if (ticket!.endDate != ticket!.visitDate)
              _detail('Valid Until', displayParkDate(ticket!.endDate)),
            _detail('Guest Type', titleCase(ticket!.ticketType)),
            const SizedBox(height: 10),
            AdminBadge(
              result?.accepted == true
                  ? 'Accepted'
                  : ticket!.filter == 'Upcoming'
                  ? 'Valid'
                  : ticket!.filter,
            ),
            const SizedBox(height: 20),
            if (result != null)
              AdminCard(
                color: result!.accepted
                    ? const Color(0xFFEEF8F0)
                    : const Color(0xFFFFF5E9),
                child: Row(
                  children: [
                    Icon(
                      result!.accepted
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: result!.accepted ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result!.message,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (result == null && !eligible)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(
                  ticket!.visitDate.compareTo(today) > 0
                      ? 'This ticket is valid from ${displayParkDate(ticket!.visitDate)}.'
                      : 'This ticket has already been used today, has expired, or is no longer active.',
                  style: const TextStyle(color: adminMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AdminButton(
                busy
                    ? 'Confirming…'
                    : result?.accepted == true
                    ? 'Admission Confirmed'
                    : 'Admit Visitor',
                icon: Icons.verified_outlined,
                onPressed: busy || !eligible || result?.accepted == true
                    ? null
                    : admit,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Each ticket allows one admission per valid day. Duplicate scans cannot admit the same ticket twice on that day.',
            style: TextStyle(fontSize: 12, color: adminMuted, height: 1.5),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminHeading(
          'Ticket Validation',
          'Verify digital tickets at the park entrance',
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 850
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: scanner),
                    const SizedBox(width: 24),
                    Expanded(child: preview),
                  ],
                )
              : Column(
                  children: [scanner, const SizedBox(height: 20), preview],
                ),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(color: adminMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}
