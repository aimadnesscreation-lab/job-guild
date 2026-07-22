import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationUtils {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Get current location as (lat, lng) tuple, with graceful fallback
  static Future<(double lat, double lng)> getCurrentLatLng() async {
    try {
      final pos = await getCurrentLocation();
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (31.5204, 74.3587); // Lahore default
    }
  }
}

/// Provider for location utilities — returns lat/lng or defaults
final locationUtilsProvider = Provider<LocationUtils>((ref) {
  return LocationUtils();
});

/// Provider for current position (async)
final currentPositionProvider = FutureProvider<(double, double)>((ref) async {
  return LocationUtils.getCurrentLatLng();
});
