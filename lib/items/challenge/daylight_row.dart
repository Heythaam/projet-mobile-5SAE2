import 'package:flutter/material.dart';

import '../../entities/challenge/daylight.dart';
import '../../services/challenge/daylight_service.dart';
import '../kickoff_style.dart';

/// A line telling whether a game is played in daylight, such as
/// "Sunset 17:32 · Ends after dark: pick a pitch with floodlights".
/// Shows nothing while loading or when the service cannot be reached.
class DaylightRow extends StatefulWidget {
  const DaylightRow({
    required this.service,
    required this.start,
    required this.minutes,
    this.latitude = 36.8065,
    this.longitude = 10.1815,
    super.key,
  });

  final DaylightService service;
  final DateTime start;
  final int minutes;
  final double latitude;
  final double longitude;

  @override
  State<DaylightRow> createState() => _DaylightRowState();
}

class _DaylightRowState extends State<DaylightRow> {
  Daylight? _daylight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = widget.start;
    final daylight = await widget.service.forDay(
      latitude: widget.latitude,
      longitude: widget.longitude,
      day: start,
    );
    if (!mounted || start != widget.start) return;
    setState(() => _daylight = daylight);
  }

  static String _hm(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final daylight = _daylight;
    if (daylight == null) return const SizedBox.shrink();
    final verdict = daylight.verdict(widget.start, widget.minutes);
    final good = verdict == DaylightVerdict.daylight;
    final color = good ? KickoffColors.yellow : KickoffColors.orange;
    return Row(
      key: const ValueKey('daylight_row'),
      children: [
        Icon(
          good ? Icons.wb_twilight_rounded : Icons.nightlight_round,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Sunrise ${_hm(daylight.sunrise)} · Sunset ${_hm(daylight.sunset)}'
            ' · ${verdict.label}',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
