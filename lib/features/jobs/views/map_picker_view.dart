import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// Result from the map picker
class MapPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// Callback when a location is selected
typedef LocationPickedCallback = void Function(MapPickerResult location);

/// Map picker screen for selecting a location.
/// Uses OpenStreetMap via flutter_map (free, no API key needed).
class MapPickerView extends ConsumerStatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final LocationPickedCallback? onLocationPicked;

  const MapPickerView({
    super.key,
    this.initialLatitude = AppConstants.defaultLatitude,
    this.initialLongitude = AppConstants.defaultLongitude,
    this.onLocationPicked,
  });

  @override
  ConsumerState<MapPickerView> createState() => _MapPickerViewState();
}

class _MapPickerViewState extends ConsumerState<MapPickerView> {
  late double _lat;
  late double _lng;
  final _searchController = TextEditingController();
  // Use Google Maps when a real API key is configured, fall back to manual entry
  @override
  void initState() {
    super.initState();
    _lat = widget.initialLatitude;
    _lng = widget.initialLongitude;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmLocation() {
    final result = MapPickerResult(
      latitude: _lat,
      longitude: _lng,
      address: _searchController.text.isNotEmpty
          ? _searchController.text
          : '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
    );
    widget.onLocationPicked?.call(result);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.selectLocation),
        actions: [TextButton(onPressed: _confirmLocation, child: Text(s.done))],
      ),
      body: Column(
        children: [
          // ─── Search ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchForPlace,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ─── Map Area ──────────────────────────────────────
          Expanded(
            child: _FlutterMapView(
              latitude: _lat,
              longitude: _lng,
              onChanged: (lat, lng) {
                setState(() {
                  _lat = lat;
                  _lng = lng;
                });
              },
            ),
          ),

          // ─── Coordinate Display ────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchController.text.isNotEmpty
                            ? _searchController.text
                            : s.currentLocation,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _confirmLocation,
                  child: Text(s.confirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OpenStreetMap view using flutter_map — no API key needed.
class _FlutterMapView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final void Function(double lat, double lng) onChanged;

  const _FlutterMapView({
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });

  @override
  State<_FlutterMapView> createState() => _FlutterMapViewState();
}

class _FlutterMapViewState extends State<_FlutterMapView> {
  late MapController _mapController;
  LatLng _selectedPoint = const LatLng(31.5204, 74.3587);

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(widget.latitude, widget.longitude);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedPoint,
        initialZoom: 14,
        onTap: (tapPos, latlng) {
          setState(() => _selectedPoint = latlng);
          widget.onChanged(latlng.latitude, latlng.longitude);
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aimadness.local_services_marketplace',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _selectedPoint,
              child: const Icon(
                Icons.location_on_rounded,
                color: AppTheme.primaryColor,
                size: 36,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
