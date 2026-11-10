import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import '../../services/match/weather_service.dart';

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
      label: 'Forecast: $label. Tap for the whole day.',
      button: true,
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('weather_row'),
          onTap: _showDay,
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
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
        ),
      ),
    );
  }

  void _showDay() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KickoffColors.panel,
      isScrollControlled: true,
      builder: (_) => _DayForecastSheet(
        service: widget.service,
        day: widget.when,
        latitude: widget.latitude,
        longitude: widget.longitude,
        matchHour: widget.when.hour,
      ),
    );
  }
}

class _DayForecastSheet extends StatelessWidget {
  const _DayForecastSheet({
    required this.service,
    required this.day,
    required this.latitude,
    required this.longitude,
    required this.matchHour,
  });

  final WeatherService service;
  final DateTime day;
  final double latitude;
  final double longitude;
  final int matchHour;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather on ${day.day.toString().padLeft(2, '0')}/'
              '${day.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: FutureBuilder<List<MatchWeather>>(
                future: service.forecastDay(
                  latitude: latitude,
                  longitude: longitude,
                  day: day,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hours = snapshot.data ?? const [];
                  if (hours.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No forecast available for this day.',
                        key: ValueKey('no_day_forecast'),
                        style: TextStyle(color: KickoffColors.muted),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final h in hours)
                        _HourTile(weather: h, isMatch: h.time.hour == matchHour),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.weather, required this.isMatch});

  final MatchWeather weather;
  final bool isMatch;

  @override
  Widget build(BuildContext context) {
    final color = isMatch ? KickoffColors.yellow : Colors.white;
    final rain = weather.rainChance;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMatch ? const Color(0x22FFD60A) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${weather.time.hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(weather.icon, color: color, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${weather.temperatureC.round()}°',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              '${weather.description}'
              '${rain == null ? '' : ' · $rain% rain'}'
              ' · ${weather.windKmh.round()} km/h',
              style: const TextStyle(color: KickoffColors.muted, fontSize: 13),
            ),
          ),
          if (isMatch)
            const Text(
              'Match',
              style: TextStyle(
                color: KickoffColors.yellow,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
