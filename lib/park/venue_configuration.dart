import 'dart:convert';
import 'package:flutter/foundation.dart';

class VenueConfiguration {
  static const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN'),
      mapboxStyle = String.fromEnvironment(
        'MAPBOX_STYLE',
        defaultValue: 'mapbox/streets-v12',
      ),
      situmApiKey = String.fromEnvironment('SITUM_API_KEY'),
      situmBuildingId = String.fromEnvironment('SITUM_BUILDING_ID'),
      situmProfile = String.fromEnvironment('SITUM_PROFILE'),
      situmPoiMap = String.fromEnvironment('SITUM_POI_MAP', defaultValue: '{}');
  static bool get mapboxReady =>
      mapboxToken.startsWith('pk.') &&
      RegExp(r'^[\w-]+/[\w-]+$').hasMatch(mapboxStyle);
  static bool get situmReady =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform) &&
      situmApiKey.isNotEmpty &&
      situmBuildingId.isNotEmpty;
  static double? get north =>
      double.tryParse(const String.fromEnvironment('PARK_NORTH'));
  static double? get south =>
      double.tryParse(const String.fromEnvironment('PARK_SOUTH'));
  static double? get east =>
      double.tryParse(const String.fromEnvironment('PARK_EAST'));
  static double? get west =>
      double.tryParse(const String.fromEnvironment('PARK_WEST'));
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
  static String? poiFor(String id) {
    try {
      return (jsonDecode(situmPoiMap) as Map)[id] as String?;
    } catch (_) {
      return null;
    }
  }
}
