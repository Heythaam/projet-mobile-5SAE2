import 'package:flutter/material.dart';

import '../../entities/maps/picked_place.dart';
import '../../views/maps/map_picker_screen.dart';
import '../kickoff_style.dart';

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
