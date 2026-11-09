import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NfcPassService {
  static const channel = MethodChannel('themepark/nfc-pass');
  static Future<String?> read(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use the connected NFC reader'),
          content: const Text(
            'Tap the pass on your NDEF reader. A reader configured for keyboard input enters the pass value in the field. You can also scan the QR code with the camera.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ready'),
            ),
          ],
        ),
      );
      return null;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Ready to read a pass'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc, size: 65),
              SizedBox(height: 20),
              Text(
                'Hold the visitor’s unlocked phone or pass near the back of this device.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => channel.invokeMethod<void>('stopReader'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    String? value, message;
    try {
      value = await channel
          .invokeMethod<String>('readPass')
          .timeout(const Duration(seconds: 35));
    } on PlatformException catch (e) {
      message =
          e.message ?? 'Unable to read the pass. Please scan its QR code.';
    } catch (_) {
      message =
          'NFC reading is unavailable on this device. Please scan the QR code.';
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
    return value;
  }

  static Future<void> present(BuildContext context, String payload) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Use your QR pass'),
            content: const Text(
              'NFC pass sharing is available in the Android app on supported phones. You can show this QR code at the scanner.',
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
      return;
    }
    try {
      final ready = await channel.invokeMethod<bool>('preparePass', {
        'payload': payload,
        'durationSeconds': 60,
      });
      if (!context.mounted) return;
      if (ready != true) throw PlatformException(code: 'unsupported');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ready to tap'),
          content: const Text(
            'Keep your phone unlocked and hold its back near the entrance or kiosk NFC reader. Your pass is available for one minute.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await channel.invokeMethod<void>('stopPass');
    } on PlatformException catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NFC is unavailable'),
            content: Text(
              e.code == 'disabled'
                  ? 'Turn on NFC in your phone settings, then try again. Your QR pass is also ready to scan.'
                  : 'This phone cannot share the pass over NFC. Show the QR code at the scanner instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Use QR Pass'),
              ),
            ],
          ),
        );
      }
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This device cannot share the pass over NFC. Please use the QR code.',
            ),
          ),
        );
      }
    }
  }
}
