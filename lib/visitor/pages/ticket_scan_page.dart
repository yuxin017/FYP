import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/tickets.dart';
import '../services/ticket_journey.dart';
import '../services/ticket_repository.dart';
import '../widgets/ticket_widgets.dart';
import 'tickets_page.dart';

class TicketScanPage extends StatefulWidget {
  final TicketRepository repository;
  final ValueChanged<ParkTicket> onFound;
  const TicketScanPage({
    super.key,
    required this.repository,
    required this.onFound,
  });
  @override
  State<TicketScanPage> createState() => _TicketScanPageState();
}

class _TicketScanPageState extends State<TicketScanPage> {
  final code = TextEditingController();
  bool camera = false, busy = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _lookup(String value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ticket = await widget.repository.findTicket(value);
      if (mounted) widget.onFound(ticket);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError ? e.message : bookingError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TicketPageBody(
    children: [
      const Text(
        'Add a ticket to your account',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const Text(
        'Scan a park ticket QR code or enter its ticket ID. The ticket must belong to you or be assigned to your account’s email address.',
        style: TextStyle(color: ticketMuted, height: 1.5),
      ),
      const SizedBox(height: 22),
      TicketSurface(
        child: Column(
          children: [
            if (camera)
              SizedBox(
                height: 255,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null && !busy) _lookup(raw);
                    },
                    errorBuilder: (context, exception) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Unable to access the camera. Check camera permissions or enter your ticket ID below.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7EFEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 110,
                  color: ticketMutedRose,
                ),
              ),
            const SizedBox(height: 16),
            TicketButton(
              camera ? 'Close Camera' : 'Scan Ticket QR',
              icon: Icons.qr_code_scanner,
              onPressed:
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
                  ? null
                  : () => setState(() => camera = !camera),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'Enter Ticket ID',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: code,
        enabled: !busy,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: 'TP-…',
          prefixIcon: Icon(Icons.confirmation_number_outlined),
        ),
        onSubmitted: _lookup,
      ),
      const SizedBox(height: 14),
      if (error != null) ...[
        TicketSurface(
          color: const Color(0xFFF8E7E4),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: ticketRose),
              const SizedBox(width: 12),
              Expanded(
                child: Text(error!, style: const TextStyle(color: ticketRose)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      TicketButton(
        busy ? 'Checking ticket…' : 'Find Ticket',
        onPressed: busy ? null : () => _lookup(code.text),
      ),
      const SizedBox(height: 20),
      const TicketMeta(
        Icons.info_outline,
        'Tickets are private. A ticket assigned to another email cannot be added to your account.',
      ),
    ],
  );
}
