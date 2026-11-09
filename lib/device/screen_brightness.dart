import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PassScreenBrightness {
  static const channel = MethodChannel('themepark/screen');
  static Future<bool> setBright(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await channel.invokeMethod<bool>('brightness', {
            'enabled': enabled,
          }) ==
          true;
    } catch (_) {
      return false;
    }
  }
}
