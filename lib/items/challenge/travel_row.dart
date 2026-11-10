import 'package:flutter/material.dart';

import '../../entities/challenge/travel.dart';
import '../../services/challenge/travel_service.dart';
import '../kickoff_style.dart';

/// "How long to get there?" The trip is timed only when the player taps, so
/// no location permission is asked just by looking at a challenge.
class TravelRow extends StatefulWidget {
  const TravelRow({required this.service, required this.place, super.key});

  final TravelService service;
  final String place;

  @override
  State<TravelRow> createState() => _TravelRowState();
}

class _TravelRowState extends State<TravelRow> {
  bool _loading = false;
  TravelResult? _result;

  Future<void> _go() async {
    setState(() => _loading = true);
    final result = await widget.service.estimate(widget.place);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _result?.estimate;
    final text = _loading
        ? 'Timing the trip…'
        : estimate != null
        ? 'Car ${TravelEstimate.format(estimate.driveMinutes)}'
              ' · Walk ${TravelEstimate.format(estimate.walkMinutes)}'
              ' · ${estimate.kilometres.toStringAsFixed(1)} km'
        : _result?.message ?? 'How long to get there?';
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        key: const ValueKey('travel_row'),
        onTap: _loading ? null : _go,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                estimate == null
                    ? Icons.directions_rounded
                    : Icons.directions_car_rounded,
                color: KickoffColors.yellow,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: estimate == null
                        ? KickoffColors.muted
                        : Colors.white,
                    fontSize: 13,
                    decoration: estimate == null
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
