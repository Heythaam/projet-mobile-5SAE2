import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/kickoff_style.dart';

/// Sunrise and sunset at one place on one day, in the phone's local time.
class Daylight {
  const Daylight({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;

  /// How a game from [start] for [minutes] sits against the daylight.
  DaylightVerdict verdict(DateTime start, int minutes) {
    final end = start.add(Duration(minutes: minutes));
    if (!start.isBefore(sunset) || end.isBefore(sunrise)) {
      return DaylightVerdict.dark;
    }
    if (start.isBefore(sunrise) || end.isAfter(sunset)) {
      return DaylightVerdict.partlyDark;
    }
    return DaylightVerdict.daylight;
  }
}

enum DaylightVerdict {
  daylight('Played in full daylight'),
  partlyDark('Ends after dark: pick a pitch with floodlights'),
  dark('After dark: floodlights needed');

  const DaylightVerdict(this.label);

  final String label;
}

/// Reads sunrise and sunset from sunrise-sunset.org (free, no key). Returns
/// null instead of throwing, so a missing connection never blocks a screen.
class DaylightService {
  DaylightService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.sunrise-sunset.org/json');

  final http.Client _client;
  final Uri _baseUri;

  Future<Daylight?> forDay({
    required double latitude,
    required double longitude,
    required DateTime day,
  }) async {
    try {
      final uri = _baseUri.replace(
        queryParameters: {
          'lat': '$latitude',
          'lng': '$longitude',
          'date':
              '${day.year}-${day.month.toString().padLeft(2, '0')}-'
              '${day.day.toString().padLeft(2, '0')}',
          'formatted': '0',
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parse(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
  }

  /// Reads the answer of sunrise-sunset.org; null when it has another shape.
  static Daylight? parse(Object? json) {
    if (json is! Map<String, dynamic> || json['status'] != 'OK') return null;
    final results = json['results'];
    if (results is! Map<String, dynamic>) return null;
    final sunrise = results['sunrise'];
    final sunset = results['sunset'];
    if (sunrise is! String || sunset is! String) return null;
    final rise = DateTime.tryParse(sunrise)?.toLocal();
    final set = DateTime.tryParse(sunset)?.toLocal();
    if (rise == null || set == null) return null;
    return Daylight(sunrise: rise, sunset: set);
  }
}

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
