import 'reminder_device.dart';
import 'reminder_device_native.dart'
    if (dart.library.js_interop) 'reminder_device_web.dart'
    as platform;
export 'reminder_device.dart';

final ReminderDevice reservationReminderDevice = platform
    .createReminderDevice();
