/// Park display clock: Asia/Kuala_Lumpur (UTC+08:00), independent of the device.
abstract final class ParkTime {
  static DateTime local(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));
  static DateTime instant(int year, int month, int day, int hour, int minute) =>
      DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
      ).subtract(const Duration(hours: 8));
  static DateTime dayEnd(DateTime instant) {
    final date = local(instant);
    return DateTime.utc(
      date.year,
      date.month,
      date.day + 1,
    ).subtract(const Duration(hours: 8));
  }

  static String time(DateTime instant) {
    final date = local(instant);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
  }

  static String date(DateTime instant) {
    final value = local(instant);
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
