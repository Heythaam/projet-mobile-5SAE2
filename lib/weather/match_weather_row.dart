import 'package:flutter/material.dart';

import '../screens/kickoff_style.dart';
import 'weather_service.dart';

/// Where the forecast is read until stadiums carry their own coordinates:
/// the centre of Tunis.
const defaultWeatherLatitude = 36.8065;
const defaultWeatherLongitude = 10.1815;

/// One line with the forecast for a match, such as "19° Partly cloudy · Good
/// to play". It shows nothing while loading or when no forecast is available,
/// so it never gets in the way of the match card.
class MatchWeatherRow extends StatefulWidget {
  const MatchWeatherRow({
    required this.service,
    required this.when,
    this.latitude = defaultWeatherLatitude,
    this.longitude = defaultWeatherLongitude,
    super.key,
  });

  final WeatherService service;
  final DateTime when;
  final double latitude;
  final double longitude;

  @override
  State<MatchWeatherRow> createState() => _MatchWeatherRowState();
}

class _MatchWeatherRowState extends State<MatchWeatherRow> {
  MatchWeather? _weather;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MatchWeatherRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.when != widget.when ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _load();
    }
  }

  Future<void> _load() async {
    final when = widget.when;
    final weather = await widget.service.forecastAt(
      latitude: widget.latitude,
      longitude: widget.longitude,
      when: when,
    );
    if (!mounted || when != widget.when) return;
    setState(() => _weather = weather);
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    if (weather == null) return const SizedBox.shrink();
    final color = weather.isGoodToPlay
        ? KickoffColors.yellow
        : KickoffColors.orange;
    final label =
        '${weather.temperatureC.round()}° ${weather.description} · '
        '${weather.verdict}';
    return Semantics(
      label: 'Forecast: $label',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(weather.icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
