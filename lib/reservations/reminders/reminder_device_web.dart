import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/application_api.dart';
import '../models/reservation.dart';
import 'reminder_device.dart';

@JS('parkReminders.status')
external JSPromise<JSString> _status(JSString device);
@JS('parkReminders.subscribe')
external JSPromise<JSString> _subscribe(JSString key);
@JS('parkReminders.bind')
external JSPromise<JSAny?> _bind(JSString device);
@JS('parkReminders.remove')
external JSPromise<JSAny?> _remove(JSString device);
@JS('parkReminders.origin')
external JSString _origin();
@JS('parkReminders.onOpen')
external void _onOpen(JSFunction callback);

ReminderDevice createReminderDevice() => WebReminderDevice();

class WebReminderDevice implements ReminderDevice {
  final _openings = StreamController<String>.broadcast();
  final _saved = <String, String>{};
  bool _listening = false;
  String? _registeredUid;
  bool _initialTaken = false;
  Future<String> _id(String uid) async {
    final prefs = await SharedPreferences.getInstance(),
        key = 'browser_reminder_device_$uid';
    final old = prefs.getString(key);
    if (old != null) return old;
    final random = Random.secure(),
        id = List.generate(
          24,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await prefs.setString(key, id);
    return id;
  }

  @override
  Stream<String> get openings {
    if (!_listening) {
      _listening = true;
      _onOpen(((JSString id) => _openings.add(id.toDart)).toJS);
    }
    return _openings.stream;
  }

  @override
  String? takeInitialOpening() {
    if (_initialTaken) return null;
    _initialTaken = true;
    return Uri.base.queryParameters['reservationReminder'];
  }

  @override
  Future<ReminderDeviceStatus> status(String uid) async {
    try {
      final value =
          jsonDecode((await _status((await _id(uid)).toJS).toDart).toDart)
              as Map;
      return ReminderDeviceStatus(
        supported: value['supported'] == true,
        enabled: value['enabled'] == true,
        message: value['message'] as String?,
      );
    } catch (_) {
      return const ReminderDeviceStatus(
        supported: false,
        enabled: false,
        message:
            'Open this application in a browser that supports notifications.',
      );
    }
  }

  @override
  Future<void> enable(String uid) async {
    final permission = _subscribe(''.toJS);
    final api = ApplicationApi();
    // Permission is requested directly from this user action before any network wait.
    final push =
        jsonDecode((await permission.toDart).toDart) as Map<String, dynamic>;
    if (push['permission'] != 'granted') {
      throw StateError(
        push['message'] as String? ??
            'Allow notifications in your browser settings to receive reminders.',
      );
    }
    final id = await _id(uid);
    final settings = await api.post('/v1/reminders/settings');
    final subscription =
        jsonDecode(
              (await _subscribe(
                (settings['publicKey'] as String).toJS,
              ).toDart).toDart,
            )
            as Map<String, dynamic>;
    if (subscription['subscription'] == null) {
      throw StateError(
        subscription['message'] as String? ??
            'Browser notifications could not be enabled.',
      );
    }
    await api.post('/v1/reminders/register', {
      'deviceId': id,
      'subscription': subscription['subscription'],
      'origin': _origin().toDart,
    });
    await _bind(id.toJS).toDart;
    _registeredUid = uid;
    _saved.clear();
  }

  @override
  Future<void> synchronize(
    String uid,
    List<RideReservation> records,
    Set<String> enabled,
  ) async {
    if (!(await status(uid)).enabled) return;
    if (_registeredUid != uid) await enable(uid);
    final device = await _id(uid);
    for (final r in records) {
      final value =
          enabled.contains(r.id) &&
          r.status == 'confirmed' &&
          r.startsAt.isAfter(DateTime.now());
      final key = '$uid/${r.id}',
          signature = '$value/${r.startsAt.millisecondsSinceEpoch}';
      if (_saved[key] == signature || !value && !_saved.containsKey(key)) {
        continue;
      }
      await ApplicationApi().post('/v1/reminders/preference', {
        'deviceId': device,
        'reservationId': r.id,
        'enabled': value,
      });
      _saved[key] = signature;
    }
  }

  @override
  Future<void> disable(String uid) async {
    final device = await _id(uid);
    await _remove(device.toJS).toDart;
    _saved.clear();
    _registeredUid = null;
    try {
      await ApplicationApi()
          .post('/v1/reminders/unregister', {'deviceId': device})
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      /* The browser subscription is already removed. */
    }
  }

  @override
  Future<void> endSession(String uid) => disable(uid);
}
