import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/tickets.dart';

Future<void> downloadTicketReceipt(
  BuildContext context,
  TicketOrder order,
) async {
  try {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'THEME PARK',
            style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Booking Receipt', style: const pw.TextStyle(fontSize: 19)),
          pw.SizedBox(height: 25),
          pw.Text('Booking: ${order.reference}'),
          pw.Text('Visit date: ${displayParkDate(order.visitDate)}'),
          pw.Text('Status: Confirmed'),
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: ['Pass', 'Guests', 'Amount'],
            data: order.lines.isEmpty
                ? [
                    [
                      order.packageName,
                      '${order.quantity}',
                      money(order.subtotal),
                    ],
                  ]
                : order.lines
                      .map(
                        (line) => [
                          line.packageName,
                          line.guestSummary.replaceAll('·', ','),
                          money(line.subtotal),
                        ],
                      )
                      .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Subtotal: ${money(order.subtotal)}'),
          if (order.discountMinor > 0)
            pw.Text(
              'Promotion ${order.promoCode}: -${money(order.discountMinor)}',
            ),
          pw.Text('Points discount: ${money(order.pointsUsed)}'),
          pw.Text(
            'Total: ${money(order.totalMinor)}',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 25),
          pw.Text(
            'Your digital tickets are available in My Tickets. Present each guest\'s QR code at the park entrance.',
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: '${order.reference}-receipt.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to download your receipt. Please try again.'),
        ),
      );
    }
  }
}
