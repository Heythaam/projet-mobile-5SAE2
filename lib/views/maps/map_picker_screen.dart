import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/location/player_location.dart';
import '../../items/kickoff_style.dart';

/// A place chosen on the map.
class PickedPlace {
  const PickedPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;

  /// A short address, or the coordinates when none could be found.
  final String label;
}

/// Names a point on the map, in French, using OpenStreetMap's free Nominatim
/// service.
/// Never throws: a missing connection gives the coordinates instead.
class PlaceNamer {
  PlaceNamer({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> nameOf(double latitude, double longitude) async {
    final fallback =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '18',
        'accept-language': 'fr',
      });
      final response = await _client
          .get(uri, headers: {
            'User-Agent': 'kickoff-football-app',
            'Accept-Language': 'fr',
          })
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return fallback;
      final json = jsonDecode(response.body);
      final name = json is Map<String, dynamic> ? json['display_name'] : null;
      if (name is! String || name.trim().isEmpty) return fallback;
      return name.split(',').take(3).map((part) => part.trim()).join(', ');
    } catch (_) {
      return fallback;
    }
  }
}

/// Full-screen map: tap to drop a pin, then confirm. Pops a [PickedPlace].
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    this.title = 'Pick a place',
    this.initial,
    this.namer,
    this.location = const GeolocatorLocationSource(),
    super.key,
  });

  final String title;
  final LatLng? initial;
  final PlaceNamer? namer;
  final LocationSource location;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Tunis, until the player taps somewhere else.
  static const _start = LatLng(36.8065, 10.1815);

  final _controller = MapController();
  late final PlaceNamer _namer = widget.namer ?? PlaceNamer();
  LatLng? _pin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial;
  }

  Future<void> _useMyLocation() async {
    final result = await widget.location.current();
    if (!mounted) return;
    final place = result.location;
    if (place == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not read your location.')),
        );
      return;
    }
    final point = LatLng(place.latitude, place.longitude);
    setState(() => _pin = point);
    _controller.move(point, 16);
  }

  Future<void> _confirm() async {
    final pin = _pin;
    if (pin == null || _busy) return;
    setState(() => _busy = true);
    final label = await _namer.nameOf(pin.latitude, pin.longitude);
    if (!mounted) return;
    Navigator.of(context).pop(
      PickedPlace(
        latitude: pin.latitude,
        longitude: pin.longitude,
        label: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    appBar: AppBar(
      backgroundColor: KickoffColors.bg,
      foregroundColor: Colors.white,
      title: Text(widget.title),
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: widget.initial ?? _start,
                  initialZoom: widget.initial == null ? 12 : 16,
                  onTap: (_, point) => setState(() => _pin = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'football_match_app',
                  ),
                  if (_pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin!,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: KickoffColors.orange,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  key: const ValueKey('map_my_location'),
                  heroTag: null,
                  onPressed: _useMyLocation,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pin == null
                      ? 'Tap the map to drop a pin.'
                      : 'Pin placed. Tap again to move it.',
                  key: const ValueKey('map_hint'),
                  style: const TextStyle(color: KickoffColors.muted),
                ),
                const SizedBox(height: 8),
                ChunkyButton(
                  label: _busy ? 'Finding address…' : 'Use this place',
                  icon: Icons.check_rounded,
                  onPressed: _pin == null || _busy ? null : _confirm,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A small "Pick on map" button that opens [MapPickerScreen] and reports the
/// chosen place.
class PickOnMapButton extends StatelessWidget {
  const PickOnMapButton({
    required this.onPicked,
    this.title = 'Pick a place',
    super.key,
  });

  final ValueChanged<PickedPlace> onPicked;
  final String title;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: const ValueKey('pick_on_map'),
      onPressed: () async {
        final place = await Navigator.of(context).push<PickedPlace>(
          MaterialPageRoute(builder: (_) => MapPickerScreen(title: title)),
        );
        if (place != null) onPicked(place);
      },
      icon: const Icon(Icons.map_rounded, color: KickoffColors.yellow),
      label: const Text(
        'Pick on map',
        style: TextStyle(color: KickoffColors.yellow),
      ),
    ),
  );
}
