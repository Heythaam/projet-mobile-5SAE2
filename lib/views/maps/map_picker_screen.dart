import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../entities/maps/picked_place.dart';
import '../../items/kickoff_style.dart';
import '../../services/location/player_location.dart';
import '../../services/maps/place_namer.dart';

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
