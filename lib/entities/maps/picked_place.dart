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
