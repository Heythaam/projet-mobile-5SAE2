import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../challenges/models/challenge_model.dart';
import '../challenges/repository/challenge_repository.dart';
import '../local/match_local_store.dart';

/// True when the app was started with `--dart-define=SAMPLE_DATA=true`, which
/// `tools/phone.ps1` does. Normal builds never load the samples.
const sampleDataEnabled = bool.fromEnvironment('SAMPLE_DATA');

/// Sample players, matches and challenges use these to be told apart from the
/// real ones.
const sampleUidPrefix = 'demo-';
const sampleChallengeUserBase = 9000;

const _asset = 'assets/sample_data.json';

Future<Map<String, dynamic>> _read([String? json]) async {
  final text = json ?? await rootBundle.loadString(_asset);
  return jsonDecode(text) as Map<String, dynamic>;
}

/// Adds the matches of `assets/sample_data.json` once: public matches at real
/// places around Tunis, so "near me" has something to sort. Does nothing when
/// they are already there. Returns how many matches were added.
Future<int> loadSampleMatches(MatchLocalStore store, {String? json}) async {
  if (await store.countHostedByPrefix(sampleUidPrefix) > 0) return 0;
  final data = await _read(json);
  final now = DateTime.now();
  var added = 0;
  for (final raw in data['matches'] as List<dynamic>) {
    final m = raw as Map<String, dynamic>;
    final time = (m['time'] as String).split(':');
    final host = m['host'] as String;
    final match = await store.create(
      hostUid: '$sampleUidPrefix$host',
      hostName: host,
      stadium: m['stadium'] as String,
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day + (m['daysFromNow'] as int),
        int.parse(time[0]),
        int.parse(time[1]),
      ),
      capacity: m['capacity'] as int,
      isPublic: true,
      latitude: (m['latitude'] as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
    );
    for (final name in (m['players'] as List<dynamic>).cast<String>()) {
      try {
        await store.join(match.code, '$sampleUidPrefix$name', name: name);
      } on LocalMatchException {
        break;
      }
    }
    added++;
  }
  return added;
}

/// Adds the challenges of `assets/sample_data.json` once. Returns how many
/// were added.
Future<int> loadSampleChallenges(
  ChallengeRepository repository, {
  String? json,
}) async {
  final existing = await repository.getBrowseChallenges(0);
  if (existing.any((c) => c.createdByUserId >= sampleChallengeUserBase)) {
    return 0;
  }
  final data = await _read(json);
  final now = DateTime.now();
  var index = 0;
  for (final raw in data['challenges'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    final format = c['format'] as String;
    final perSide = int.parse(format.split('v').first);
    final created = await repository.createChallenge(
      Challenge(
        type: ChallengeType.open,
        description: c['description'] as String,
        difficulty: c['difficulty'] as int,
        locationName: c['location'] as String,
        dateTime: DateTime(
          now.year,
          now.month,
          now.day + (c['daysFromNow'] as int),
          c['hour'] as int,
        ),
        maxPlayers: perSide * 2,
        joinCode: await repository.generateUniqueJoinCode(),
        createdByUserId: sampleChallengeUserBase + index,
        gameFormat: format,
        pitchType: c['pitchType'] as String,
        skillLevel: c['skillLevel'] as String,
        durationMinutes: c['durationMinutes'] as int,
      ),
    );
    for (var j = 0; j < (c['joined'] as int); j++) {
      await repository.joinChallenge(created.id!, sampleChallengeUserBase + 100 + j);
    }
    index++;
  }
  return index;
}
