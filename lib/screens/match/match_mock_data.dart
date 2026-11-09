// TEMPORARY: replace with API data
import 'dart:math';

import 'package:flutter/material.dart';

class MatchStadiumData {
  const MatchStadiumData({
    required this.name,
    required this.distance,
    required this.coins,
    required this.players,
  });

  final String name;
  final String distance;
  final int coins;
  final int players;
}

class PublicMatchData {
  const PublicMatchData({
    required this.time,
    required this.stadium,
    required this.players,
    required this.capacity,
  });

  final String time;
  final String stadium;
  final int players;
  final int capacity;
}

class MatchHomeMatch {
  const MatchHomeMatch({
    required this.scheduledAt,
    required this.stadium,
    required this.players,
    required this.capacity,
    required this.isPublic,
    required this.code,
    this.playerSlots = const [],
  });

  final DateTime scheduledAt;
  final String stadium;
  final int players;
  final int capacity;
  final bool isPublic;
  final String code;
  final List<String?> playerSlots;
}

class MatchPublicListing {
  const MatchPublicListing({
    required this.match,
    required this.timeLabel,
    required this.isToday,
  });

  final MatchHomeMatch match;
  final String timeLabel;
  final bool isToday;
}

class CreateMatchDraft {
  const CreateMatchDraft({
    required this.stadium,
    required this.startsAt,
    required this.visibility,
  });

  final MatchStadiumData stadium;
  final DateTime startsAt;
  final String visibility;
}

const matchStadiums = [
  MatchStadiumData(
    name: 'Green Arena',
    distance: '2 km',
    coins: 40,
    players: 10,
  ),
  MatchStadiumData(
    name: 'City Pitch',
    distance: '3.5 km',
    coins: 30,
    players: 8,
  ),
  MatchStadiumData(
    name: 'Sport Hall',
    distance: '5.2 km',
    coins: 25,
    players: 8,
  ),
  MatchStadiumData(
    name: 'Riverside Park',
    distance: '7.8 km',
    coins: 20,
    players: 10,
  ),
];

const publicMatchList = [
  PublicMatchData(
    time: 'Today 18:00',
    stadium: 'Green Arena',
    players: 6,
    capacity: 10,
  ),
  PublicMatchData(
    time: 'Today 20:00',
    stadium: 'City Pitch',
    players: 2,
    capacity: 8,
  ),
  PublicMatchData(
    time: 'Sunday',
    stadium: 'Sport Hall',
    players: 8,
    capacity: 8,
  ),
];

class MatchDemoController extends ChangeNotifier {
  MatchDemoController()
    : upcomingMatch = MatchHomeMatch(
        scheduledAt: _nextSaturdayAtSix(),
        stadium: 'Green Arena',
        players: 7,
        capacity: 10,
        isPublic: false,
        code: 'K7X92',
        playerSlots: const [
          'U',
          'A',
          'S',
          null,
          null,
          'M',
          'Y',
          'K',
          null,
          'R',
        ],
      ),
      _matches = _seedMatches();

  static const usernameInitial = 'U';
  static const level = 1;
  static const streak = 1;
  static const energy = 50;

  final List<MatchStadiumData> stadiums = matchStadiums;
  final List<MatchHomeMatch> _matches;
  MatchHomeMatch? upcomingMatch;

  List<MatchPublicListing> get publicMatches => [
    for (final match in _matches.where((match) => match.isPublic))
      MatchPublicListing(
        match: match,
        timeLabel: _publicTime(match.scheduledAt),
        isToday: DateUtils.isSameDay(match.scheduledAt, DateTime.now()),
      ),
  ];

  MatchHomeMatch? findMatchByCode(String code) {
    final normalized = code.toUpperCase();
    for (final match in _matches) {
      if (match.code.toUpperCase() == normalized) return match;
    }
    final current = upcomingMatch;
    if (current != null && current.code.toUpperCase() == normalized) {
      return current;
    }
    return null;
  }

  bool hasJoined(MatchHomeMatch match) =>
      match.playerSlots.contains(usernameInitial);

  MatchHomeMatch? joinByCode(String code) {
    final match = findMatchByCode(code);
    if (match == null || match.players >= match.capacity) return match;
    return _joinMatch(match);
  }

  MatchHomeMatch? joinPublicMatch(MatchHomeMatch match) {
    if (match.players >= match.capacity) return match;
    return _joinMatch(match);
  }

  MatchHomeMatch _joinMatch(MatchHomeMatch match) {
    if (hasJoined(match)) return match;
    final slots = List<String?>.of(match.playerSlots);
    while (slots.length < match.capacity) {
      slots.add(null);
    }
    final freeSlot = slots.indexOf(null);
    if (freeSlot < 0) return match;
    slots[freeSlot] = usernameInitial;
    final joined = MatchHomeMatch(
      scheduledAt: match.scheduledAt,
      stadium: match.stadium,
      players: match.players + 1,
      capacity: match.capacity,
      isPublic: match.isPublic,
      code: match.code,
      playerSlots: slots,
    );
    final index = _matches.indexWhere((item) => item.code == match.code);
    if (index >= 0) _matches[index] = joined;
    upcomingMatch = joined;
    notifyListeners();
    return joined;
  }

  void updateUpcomingMatch(MatchHomeMatch? match) {
    upcomingMatch = match;
    notifyListeners();
  }

  MatchHomeMatch createMatch(CreateMatchDraft draft) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(
      5,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final slots = List<String?>.filled(draft.stadium.players, null);
    if (slots.isNotEmpty) slots[0] = usernameInitial;
    final match = MatchHomeMatch(
      scheduledAt: draft.startsAt,
      stadium: draft.stadium.name,
      players: 1,
      capacity: draft.stadium.players,
      isPublic: draft.visibility == 'Public',
      code: code,
      playerSlots: slots,
    );
    upcomingMatch = match;
    _matches.removeWhere((item) => item.code == match.code);
    _matches.add(match);
    notifyListeners();
    return match;
  }
}

String _publicTime(DateTime date) {
  if (!DateUtils.isSameDay(date, DateTime.now())) {
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][date.weekday - 1];
  }
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

DateTime _nextSaturdayAtSix() {
  final now = DateTime.now();
  var daysUntilSaturday = DateTime.saturday - now.weekday;
  if (daysUntilSaturday <= 0) daysUntilSaturday += 7;
  return DateTime(now.year, now.month, now.day + daysUntilSaturday, 18);
}

DateTime _nextSundayAt() {
  final now = DateTime.now();
  var daysUntilSunday = DateTime.sunday - now.weekday;
  if (daysUntilSunday <= 0) daysUntilSunday += 7;
  return DateTime(now.year, now.month, now.day + daysUntilSunday, 18);
}

List<MatchHomeMatch> _seedMatches() => [
  MatchHomeMatch(
    scheduledAt: _nextSaturdayAtSix(),
    stadium: 'Green Arena',
    players: 7,
    capacity: 10,
    isPublic: false,
    code: 'K7X92',
    playerSlots: const ['U', 'A', 'S', null, null, 'M', 'Y', 'K', null, 'R'],
  ),
  MatchHomeMatch(
    scheduledAt: _todayAt(18),
    stadium: 'Green Arena',
    players: 6,
    capacity: 10,
    isPublic: true,
    code: 'GRN18',
    playerSlots: const ['A', 'B', 'C', 'D', 'E', 'F', null, null, null, null],
  ),
  MatchHomeMatch(
    scheduledAt: _todayAt(20),
    stadium: 'City Pitch',
    players: 2,
    capacity: 8,
    isPublic: true,
    code: 'CITY2',
    playerSlots: const ['A', 'B', null, null, null, null, null, null],
  ),
  MatchHomeMatch(
    scheduledAt: _nextSundayAt(),
    stadium: 'Sport Hall',
    players: 8,
    capacity: 8,
    isPublic: true,
    code: 'SPORT8',
    playerSlots: const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
  ),
];

DateTime _todayAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour);
}
