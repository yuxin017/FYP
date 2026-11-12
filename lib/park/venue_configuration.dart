class VenueConfiguration {
  static const name = 'TAR UMT Penang';
  static const latitude = 5.45235045, longitude = 100.28507965;
  static const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN'),
      mapboxStyle = String.fromEnvironment(
        'MAPBOX_STYLE',
        defaultValue: 'mapbox/streets-v12',
      );
  static bool get mapboxReady =>
      mapboxToken.startsWith('pk.') &&
      RegExp(r'^[\w-]+/[\w-]+$').hasMatch(mapboxStyle);
  static double? get north => double.tryParse(
    const String.fromEnvironment('PARK_NORTH', defaultValue: '5.4538291'),
  );
  static double? get south => double.tryParse(
    const String.fromEnvironment('PARK_SOUTH', defaultValue: '5.4508718'),
  );
  static double? get east => double.tryParse(
    const String.fromEnvironment('PARK_EAST', defaultValue: '100.2865541'),
  );
  static double? get west => double.tryParse(
    const String.fromEnvironment('PARK_WEST', defaultValue: '100.2836052'),
  );
  static bool get boundsReady =>
      north != null &&
      south != null &&
      east != null &&
      west != null &&
      north! > south! &&
      east! > west! &&
      north!.abs() <= 90 &&
      south!.abs() <= 90 &&
      east!.abs() <= 180 &&
      west!.abs() <= 180;
  static String get mapboxTiles =>
      'https://api.mapbox.com/styles/v1/$mapboxStyle/tiles/512/{z}/{x}/{y}?access_token=${Uri.encodeQueryComponent(mapboxToken)}';
}
