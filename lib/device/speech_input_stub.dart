import 'package:flutter/services.dart';

Future<String> listenSpeech(String language) async {
  try {
    return await const MethodChannel(
          'themepark/speech',
        ).invokeMethod<String>('listen', {'language': language}) ??
        '';
  } on MissingPluginException {
    throw StateError(
      'Voice input is unavailable on this device. Please type your question.',
    );
  } on PlatformException catch (e) {
    throw StateError(
      e.message ?? 'Voice input could not start. Please type your question.',
    );
  }
}
