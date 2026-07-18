import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
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
/// Uses Google Maps when configured, falls back to manual coordinate entry.
class MapPickerView extends StatefulWidget {
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
  State<MapPickerView> createState() => _MapPickerViewState();
}

class _MapPickerViewState extends State<MapPickerView> {
  late double _lat;
  late double _lng;
  final _searchController = TextEditingController();
  bool _useManualEntry = true; // Set to false when Google Maps SDK is configured

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a place...',
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
            child: _useManualEntry
                ? _ManualLocationEditor(
                    latitude: _lat,
                    longitude: _lng,
                    onChanged: (lat, lng) {
                      setState(() {
                        _lat = lat;
                        _lng = lng;
                      });
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_rounded,
                            size: 64, color: AppTheme.textDisabled),
                        const SizedBox(height: 16),
                        const Text(
                          'Google Maps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set your Google Maps API key in\nAppConstants to enable the map view.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() => _useManualEntry = true);
                          },
                          child: const Text('Use Manual Entry'),
                        ),
                      ],
                    ),
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
                const Icon(Icons.location_on_rounded,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchController.text.isNotEmpty
                            ? _searchController.text
                            : 'Current Location',
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
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual coordinate entry with sliders for demo/fallback mode
class _ManualLocationEditor extends StatelessWidget {
  final double latitude;
  final double longitude;
  final void Function(double lat, double lng) onChanged;

  const _ManualLocationEditor({
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 8),
                Text(
                  '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Adjust using sliders below',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(width: 40,
                  child: Text('Lat', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              Expanded(
                child: Slider(
                  value: latitude,
                  min: 31.3,
                  max: 31.6,
                  divisions: 300,
                  label: latitude.toStringAsFixed(4),
                  onChanged: (val) => onChanged(val, longitude),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 40,
                  child: Text('Lng', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              Expanded(
                child: Slider(
                  value: longitude,
                  min: 74.2,
                  max: 74.5,
                  divisions: 300,
                  label: longitude.toStringAsFixed(4),
                  onChanged: (val) => onChanged(latitude, val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '📍 Set approximate location — your address won\'t be shared until you accept a worker.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textDisabled,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
