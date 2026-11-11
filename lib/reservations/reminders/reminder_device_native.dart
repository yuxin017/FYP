import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import '../../attractions/models/park_time.dart';
import '../models/reservation.dart';
import 'reminder_device.dart';

ReminderDevice createReminderDevice() => NativeReminderDevice();

class NativeReminderDevice implements ReminderDevice {
  final plugin = FlutterLocalNotificationsPlugin();
  final _openings = StreamController<String>.broadcast();
  Future<void>? _initializing;
  Future<void> _work = Future.value();
  String? _initial;
  static String preference(String uid) => 'closed_reminders_$uid';
  static int notificationId(String uid, String id) {
    final bytes = sha256.convert(utf8.encode('$uid/$id')).bytes;
    return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7fffffff;
  }

  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  @override
  Stream<String> get openings => _openings.stream;
  @override
  String? takeInitialOpening() {
    final value = _initial;
    _initial = null;
    return value;
  }

  Future<void> _initialize() => _initializing ??= () async {
    zones.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_reservation_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final value = response.payload;
        if (value != null && value.startsWith('ride:')) {
          _openings.add(value.split(':').last);
        }
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final value = launch?.notificationResponse?.payload;
      if (value != null && value.startsWith('ride:')) {
        _initial = value.split(':').last;
      }
    }
  }();
  Future<void> _serial(Future<void> Function() action) {
    final next = _work.then((_) => action());
    _work = next.catchError((Object _) {});
    return next;
  }

  Future<bool> _allowed() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      return await android.areNotificationsEnabled() == true &&
          await android.canScheduleExactNotifications() == true;
    }
    return (await plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ==
        true;
  }

  @override
  Future<ReminderDeviceStatus> status(String uid) async {
    if (!supported) {
      return const ReminderDeviceStatus(
        supported: false,
        enabled: false,
        message:
            'Open the app on Android or iPhone to enable device reminders.',
      );
    }
    try {
      await _initialize();
      final saved =
          (await SharedPreferences.getInstance()).getBool(preference(uid)) ==
          true;
      final allowed = await _allowed();
      return ReminderDeviceStatus(
        supported: true,
        enabled: saved && allowed,
        message: saved && !allowed
            ? 'Allow notifications and alarms in this device’s app settings.'
            : null,
      );
    } catch (_) {
      return const ReminderDeviceStatus(
        supported: false,
        enabled: false,
        message: 'Device notifications are unavailable here.',
      );
    }
  }

  @override
  Future<void> enable(String uid) async {
    if (!supported) {
      throw StateError('Open the installed app to enable device reminders.');
    }
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (await android.requestNotificationsPermission() != true) {
        throw StateError(
          'Allow notifications in this device’s app settings to receive reminders.',
        );
      }
      if (await android.canScheduleExactNotifications() != true &&
          await android.requestExactAlarmsPermission() != true) {
        throw StateError(
          'Allow Alarms & reminders in this device’s app settings for timed reservation reminders.',
        );
      }
    } else {
      if (await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: true) !=
          true) {
        throw StateError(
          'Allow notifications in Settings to receive reminders.',
        );
      }
    }
    await (await SharedPreferences.getInstance()).setBool(
      preference(uid),
      true,
    );
  }

  @override
  Future<void> synchronize(
    String uid,
    List<RideReservation> records,
    Set<String> enabled,
  ) => _serial(() async {
    if (!(await status(uid)).enabled) {
      await _cancelOwned(uid);
      return;
    }
    final now = DateTime.now();
    final upcoming =
        records
            .where(
              (r) =>
                  r.status == 'confirmed' &&
                  r.startsAt.isAfter(now) &&
                  enabled.contains(r.id),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    // Leave headroom below iOS's 64 pending-notification limit.
    final chosen = upcoming.take(50).toList(),
        wanted = {for (final r in upcoming.take(50)) notificationId(uid, r.id)};
    final pending = await plugin.pendingNotificationRequests();
    for (final old in pending) {
      if (old.payload?.startsWith('ride:$uid:') == true &&
          !wanted.contains(old.id)) {
        await plugin.cancel(old.id);
        await (await SharedPreferences.getInstance()).remove(
          'scheduled_ride_${uid}_${old.id}',
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final r in chosen) {
      final id = notificationId(uid, r.id),
          timestamp = r.startsAt.subtract(const Duration(minutes: 15));
      final signature =
          '${r.startsAt.millisecondsSinceEpoch}/${r.endsAt.millisecondsSinceEpoch}/${r.attractionName}';
      if (prefs.getString('scheduled_ride_${uid}_$id') == signature &&
          (pending.any((old) => old.id == id) || !timestamp.isAfter(now))) {
        continue;
      }
      final body =
          '${r.attractionName}: return between ${ParkTime.time(r.startsAt)} and ${ParkTime.time(r.endsAt)}.';
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'reservation_reminders',
          'Attraction reminders',
          channelDescription:
              'Reminders before confirmed attraction return windows',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_reservation_notification',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );
      if (timestamp.isAfter(now)) {
        await plugin.zonedSchedule(
          id,
          'Your attraction reservation',
          body,
          tz.TZDateTime.from(timestamp, tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'ride:$uid:${r.id}',
        );
      } else {
        await plugin.show(
          id,
          'Your attraction reservation',
          body,
          details,
          payload: 'ride:$uid:${r.id}',
        );
      }
      await prefs.setString('scheduled_ride_${uid}_$id', signature);
    }
  });
  Future<void> _cancelOwned(String uid) async {
    if (!supported) return;
    await _initialize();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'scheduled_ride_${uid}_';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final id = int.tryParse(key.substring(prefix.length));
      if (id == null) continue;
      await plugin.cancel(id);
      final start = int.tryParse((prefs.getString(key) ?? '').split('/').first);
      if (start == null || start > DateTime.now().millisecondsSinceEpoch) {
        await prefs.remove(key);
      }
    }
  }

  @override
  Future<void> disable(String uid) => _serial(() async {
    await (await SharedPreferences.getInstance()).setBool(
      preference(uid),
      false,
    );
    await _cancelOwned(uid);
  });
  @override
  Future<void> endSession(String uid) => _serial(() => _cancelOwned(uid));
}
