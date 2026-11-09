import 'dart:math';

import '../challenges/models/challenge_model.dart';
import '../challenges/repository/challenge_repository.dart';
import '../local/match_local_store.dart';
import '../screens/match/match_mock_data.dart';

/// Players that fill the demo matches and challenges.
const demoPlayers = [
  'Sami', 'Yassine', 'Amine', 'Karim', 'Mehdi', 'Nour', 'Hatem', 'Ali',
  'Rami', 'Walid', 'Aymen', 'Oussama', 'Firas', 'Skander', 'Bilel', 'Anis',
  'Hamza', 'Zied', 'Marwen', 'Slim',
];

/// Adds public matches by other players around Tunis, some almost full, so
/// the lists, the nearby sorting and the calendar have something to show.
/// Returns how many matches were added.
Future<int> seedDemoMatches(MatchLocalStore store, {Random? random}) async {
  final rng = random ?? Random();
  final now = DateTime.now();
  var added = 0;
  for (var i = 0; i < 12; i++) {
    final stadium = matchStadiums[i % matchStadiums.length];
    final host = demoPlayers[i % demoPlayers.length];
    final start = DateTime(
      now.year,
      now.month,
      now.day + 1 + rng.nextInt(9),
      16 + rng.nextInt(7),
      rng.nextBool() ? 0 : 30,
    );
    final match = await store.create(
      hostUid: 'demo-$host',
      hostName: host,
      stadium: stadium.name,
      scheduledAt: start,
      capacity: stadium.players,
      isPublic: true,
      latitude: stadium.latitude,
      longitude: stadium.longitude,
    );
    final others = demoPlayers.where((name) => name != host).toList()
      ..shuffle(rng);
    final fill = 1 + rng.nextInt(stadium.players - 1);
    for (final name in others.take(fill)) {
      try {
        await store.join(match.code, 'demo-$name', name: name);
      } on LocalMatchException {
        break;
      }
    }
    added++;
  }
  return added;
}

/// Adds open challenges by other players, with some of them joined. Returns
/// how many challenges were added.
Future<int> seedDemoChallenges(
  ChallengeRepository repository, {
  Random? random,
}) async {
  final rng = random ?? Random();
  const places = [
    'Green Arena, La Marsa',
    'City Pitch, Tunis',
    'Sport Hall, Ariana',
    'Riverside Park, Ben Arous',
    'Stade du Lac',
    'Carthage Turf',
    'Menzah Five',
    'Sousse Indoor Arena',
  ];
  const formats = ['5v5', '7v7', '11v11'];
  const pitches = ['Turf', 'Indoor', 'Grass'];
  const levels = ['All Levels', 'Beginner', 'Intermediate', 'Advanced'];
  final now = DateTime.now();
  var added = 0;
  for (var i = 0; i < 10; i++) {
    final format = formats[i % formats.length];
    final perSide = int.parse(format.split('v').first);
    final creator = 9000 + i;
    final challenge = await repository.createChallenge(
      Challenge(
        type: ChallengeType.open,
        description:
            '${demoPlayers[i % demoPlayers.length]} is looking for players. '
            'Friendly $format, bring water and good vibes.',
        difficulty: 1 + rng.nextInt(5),
        locationName: places[i % places.length],
        dateTime: DateTime(
          now.year,
          now.month,
          now.day + 1 + rng.nextInt(10),
          17 + rng.nextInt(5),
        ),
        maxPlayers: perSide * 2,
        joinCode: await repository.generateUniqueJoinCode(),
        createdByUserId: creator,
        gameFormat: format,
        pitchType: pitches[rng.nextInt(pitches.length)],
        skillLevel: levels[rng.nextInt(levels.length)],
        durationMinutes: [60, 90, 120][rng.nextInt(3)],
      ),
    );
    final joiners = rng.nextInt(perSide * 2 - 1);
    for (var j = 0; j < joiners; j++) {
      await repository.joinChallenge(challenge.id!, 9100 + j);
    }
    added++;
  }
  return added;
}
