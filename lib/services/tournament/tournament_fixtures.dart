import 'tournament_rules.dart';
import 'tournament_store.dart';

/// Fixtures, results, tables, bracket and stats of one tournament document,
/// ported from the Dart server. A match is a map:
/// `id, round, stage ('group' | 'knockout'), position (knockout slot),
/// home, away (team ids, null for an open slot or a bye), homeScore,
/// awayScore, winner, status, scheduledAt, location`.
abstract final class TournamentFixtures {
  static const _winPoints = 3;
  static const _drawPoints = 1;

  static Never _fail(int status, String message) =>
      TournamentRules.fail(status, message);

  static List<Doc> _matches(Doc doc) => TournamentRules.list(doc, 'matches');

  static Doc _findMatch(Doc doc, int matchId) {
    for (final match in _matches(doc)) {
      if (match['id'] == matchId) return match;
    }
    _fail(404, 'Match not found.');
  }

  // ---- Making and changing matches --------------------------------------

  static void generate(Doc doc, int me) {
    TournamentRules.requireOrganizer(doc, me);
    final status = doc['status'] as String;
    if (status != 'upcoming' && status != 'active') {
      _fail(
        409,
        'Fixtures can only be generated for upcoming or active tournaments.',
      );
    }
    final teams = TournamentRules.activeTeams(doc)
      ..sort((a, b) {
        final byTime = (a['joinedAtMs'] as int).compareTo(
          b['joinedAtMs'] as int,
        );
        return byTime != 0
            ? byTime
            : (a['id'] as int).compareTo(b['id'] as int);
      });
    if (teams.length < 2) {
      _fail(409, 'At least 2 teams are needed to generate fixtures.');
    }
    if (_matches(doc).isNotEmpty) {
      _fail(409, 'Fixtures were already generated.');
    }
    final ids = [for (final team in teams) team['id'] as int];
    final matches = <Doc>[];
    switch (doc['format']) {
      case 'knockout':
        _knockout(doc, matches, ids);
      case 'groups_knockout':
        final groups = <String?, List<int>>{};
        for (final team in teams) {
          groups
              .putIfAbsent(team['group'] as String?, () => [])
              .add(team['id'] as int);
        }
        for (final group in groups.values) {
          _roundRobin(doc, matches, group);
        }
      default:
        _roundRobin(doc, matches, ids);
    }
    doc['matches'] = matches;
  }

  static Doc _newMatch(
    Doc doc, {
    required int? home,
    required int? away,
    required int round,
    required String stage,
    required String status,
    int? position,
    int? winner,
  }) => {
    'id': TournamentRules.nextId(doc),
    'round': round,
    'stage': stage,
    'position': position,
    'home': home,
    'away': away,
    'homeScore': null,
    'awayScore': null,
    'winner': winner,
    'status': status,
    'scheduledAt': null,
    'location': null,
  };

  static void _roundRobin(Doc doc, List<Doc> out, List<int> teamIds) {
    final ids = [...teamIds, if (teamIds.length.isOdd) -1];
    final n = ids.length;
    var round = 1;
    for (var day = 0; day < n - 1; day++) {
      for (var i = 0; i < n ~/ 2; i++) {
        final home = ids[i];
        final away = ids[n - 1 - i];
        if (home == -1 || away == -1) continue;
        out.add(
          _newMatch(
            doc,
            home: home,
            away: away,
            round: round,
            stage: 'group',
            status: 'scheduled',
          ),
        );
      }
      round++;
      final last = ids.removeLast();
      ids.insert(1, last);
    }
  }

  static void _knockout(Doc doc, List<Doc> out, List<int> teamIds) {
    final slots = _nextPowerOfTwo(teamIds.length);
    final ids = [...teamIds];
    while (ids.length < slots) {
      ids.add(-1);
    }
    for (var i = 0; i < slots ~/ 2; i++) {
      final home = ids[i * 2];
      final away = ids[i * 2 + 1];
      final isBye = home == -1 || away == -1;
      out.add(
        _newMatch(
          doc,
          home: home == -1 ? null : home,
          away: away == -1 ? null : away,
          round: 1,
          stage: 'knockout',
          position: i + 1,
          status: isBye ? 'bye' : 'scheduled',
          winner: isBye ? (home == -1 ? away : home) : null,
        ),
      );
    }
  }

  static Doc recordResult(
    Doc doc,
    int me,
    int matchId, {
    required int homeScore,
    required int awayScore,
    int? winnerId,
  }) {
    TournamentRules.requireOrganizer(doc, me);
    if (homeScore < 0 || awayScore < 0) {
      _fail(400, 'Scores must be non-negative integers.');
    }
    if (doc['status'] != 'active') {
      _fail(409, 'Results can only be recorded for active tournaments.');
    }
    final match = _findMatch(doc, matchId);
    if (match['status'] == 'played') {
      _fail(409, 'This match result was already recorded.');
    }
    match['homeScore'] = homeScore;
    match['awayScore'] = awayScore;
    match['status'] = 'played';
    match['winner'] =
        winnerId ??
        (homeScore > awayScore
            ? match['home']
            : awayScore > homeScore
            ? match['away']
            : null);
    return match;
  }

  static void schedule(
    Doc doc,
    int me,
    int matchId, {
    String? scheduledAt,
    String? location,
  }) {
    TournamentRules.requireOrganizer(doc, me);
    final cleanLocation = TournamentRules.optionalText(
      location,
      'location',
      200,
    );
    if (scheduledAt != null && DateTime.tryParse(scheduledAt) == null) {
      _fail(400, 'scheduledAt must be an ISO-8601 date-time.');
    }
    final match = _findMatch(doc, matchId);
    if (scheduledAt != null) match['scheduledAt'] = scheduledAt;
    if (cleanLocation != null) match['location'] = cleanLocation;
  }

  // ---- Tables ------------------------------------------------------------

  static List<Map<String, Object?>> standings(Doc doc, int me) {
    final myTeam = TournamentRules.myTeamId(doc, me);
    final records = <int, _Record>{
      for (final team in TournamentRules.activeTeams(doc))
        team['id'] as int: _Record(
          team['id'] as int,
          team['name'] as String,
          team['group'] as String?,
          team['id'] == myTeam,
        ),
    };
    for (final match in _matches(doc)) {
      if (match['status'] != 'played' || match['stage'] != 'group') continue;
      final home = records[match['home']];
      final away = records[match['away']];
      if (home == null || away == null) continue;
      final homeScore = match['homeScore'] as int;
      final awayScore = match['awayScore'] as int;
      home.record(homeScore, awayScore);
      away.record(awayScore, homeScore);
    }
    final tables = <String?, List<_Record>>{};
    for (final record in records.values) {
      tables.putIfAbsent(record.group, () => []).add(record);
    }
    final labels = tables.keys.toList()
      ..sort((a, b) {
        if (a == null) return b == null ? 0 : 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return [
      for (final label in labels)
        ...() {
          final table = tables[label]!..sort(_Record.compare);
          return [
            for (var i = 0; i < table.length; i++) table[i].toJson(i + 1),
          ];
        }(),
    ];
  }

  // ---- Bracket -----------------------------------------------------------

  static List<Map<String, Object?>> bracket(Doc doc) {
    final rows = [
      for (final match in _matches(doc))
        if (match['stage'] == 'knockout') match,
    ];
    if (rows.isEmpty) return const [];
    rows.sort((a, b) {
      final byRound = (a['round'] as int).compareTo(b['round'] as int);
      if (byRound != 0) return byRound;
      final pa = a['position'] as int?;
      final pb = b['position'] as int?;
      if ((pa == null) != (pb == null)) return pa == null ? 1 : -1;
      if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
      return (a['id'] as int).compareTo(b['id'] as int);
    });
    final byRound = <int, List<Doc>>{};
    for (final row in rows) {
      byRound.putIfAbsent(row['round'] as int, () => []).add(row);
    }
    final firstRound = byRound.keys.reduce((a, b) => a < b ? a : b);
    final lastRound = byRound.keys.reduce((a, b) => a > b ? a : b);
    final slots = _nextPowerOfTwo(_slotsNeeded(byRound[firstRound]!));
    final expectedRounds = _log2(slots) + 1;
    final roundCount = expectedRounds > lastRound - firstRound + 1
        ? expectedRounds
        : lastRound - firstRound + 1;

    final rounds = <List<Map<String, Object?>>>[];
    for (var index = 0; index < roundCount; index++) {
      final existing = byRound[firstRound + index] ?? const <Doc>[];
      final expected = slots >> index;
      final needed = _slotsNeeded(existing);
      final count = needed > expected ? needed : expected;
      final previous = index == 0 ? null : rounds[index - 1];
      final placed = <int, Doc>{};
      final unplaced = <Doc>[];
      for (final row in existing) {
        final position = row['position'] as int?;
        if (position != null && !placed.containsKey(position - 1)) {
          placed[position - 1] = row;
        } else {
          unplaced.add(row);
        }
      }
      final matches = <Map<String, Object?>>[];
      for (var slot = 0; slot < count || unplaced.isNotEmpty; slot++) {
        var row = placed[slot];
        if (row == null && unplaced.isNotEmpty) row = unplaced.removeAt(0);
        matches.add(
          row != null
              ? {..._bracketMatch(doc, row), 'position': slot + 1}
              : _pending(
                  slot + 1,
                  _winnerOf(previous, slot * 2),
                  _winnerOf(previous, slot * 2 + 1),
                ),
        );
      }
      rounds.add(matches);
    }
    return [
      for (var index = 0; index < rounds.length; index++)
        {
          'round': firstRound + index,
          'roundsFromEnd': rounds.length - 1 - index,
          'matches': rounds[index],
        },
    ];
  }

  static int _slotsNeeded(List<Doc> rows) {
    var needed = rows.length;
    for (final row in rows) {
      final position = row['position'] as int?;
      if (position != null && position > needed) needed = position;
    }
    return needed;
  }

  static Map<String, Object?>? _team(Doc doc, Object? id) {
    if (id == null) return null;
    final team = TournamentRules.teamById(
      doc,
      id as int,
      activeOnly: false,
    );
    return {'id': id, 'name': team?['name'] ?? 'Team $id'};
  }

  static Map<String, Object?> _bracketMatch(Doc doc, Doc row) {
    final status = row['status'] as String;
    final homeScore = row['homeScore'] as int?;
    final awayScore = row['awayScore'] as int?;
    Object? winnerId;
    if (status == 'bye') {
      winnerId = row['home'] ?? row['away'];
    } else if (status == 'played' && homeScore != null && awayScore != null) {
      winnerId = homeScore == awayScore
          ? row['winner']
          : homeScore > awayScore
          ? row['home']
          : row['away'];
    }
    return {
      'id': row['id'],
      'home': _team(doc, row['home']),
      'away': _team(doc, row['away']),
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': status,
      'winnerId': winnerId,
      'scheduledAt': row['scheduledAt'],
      'location': row['location'],
    };
  }

  static Map<String, Object?> _pending(
    int position,
    Map<String, Object?>? home,
    Map<String, Object?>? away,
  ) => {
    'id': null,
    'position': position,
    'home': home,
    'away': away,
    'homeScore': null,
    'awayScore': null,
    'status': 'pending',
    'winnerId': null,
    'scheduledAt': null,
  };

  static Map<String, Object?>? _winnerOf(
    List<Map<String, Object?>>? round,
    int index,
  ) {
    if (round == null || index >= round.length) return null;
    final match = round[index];
    final winnerId = match['winnerId'];
    if (winnerId == null) return null;
    for (final side in [match['home'], match['away']]) {
      if (side is Map<String, Object?> && side['id'] == winnerId) return side;
    }
    return null;
  }

  static int _nextPowerOfTwo(int value) {
    var power = 1;
    while (power < value) {
      power *= 2;
    }
    return power;
  }

  static int _log2(int powerOfTwo) {
    var exponent = 0;
    while ((1 << exponent) < powerOfTwo) {
      exponent++;
    }
    return exponent;
  }

  // ---- Stats -------------------------------------------------------------

  static Map<String, Object?> stats(Doc doc) {
    final teams = TournamentRules.activeTeams(doc);
    final played = [
      for (final match in _matches(doc))
        if (match['status'] == 'played') match,
    ];
    final goals = <int, int>{for (final t in teams) t['id'] as int: 0};
    final games = <int, int>{for (final t in teams) t['id'] as int: 0};
    final won = <int, int>{for (final t in teams) t['id'] as int: 0};
    var totalGoals = 0;
    for (final match in played) {
      final home = (match['homeScore'] as int?) ?? 0;
      final away = (match['awayScore'] as int?) ?? 0;
      totalGoals += home + away;
      final homeId = match['home'] as int?;
      final awayId = match['away'] as int?;
      final winnerId = match['winner'] as int?;
      if (homeId != null) {
        goals[homeId] = (goals[homeId] ?? 0) + home;
        games[homeId] = (games[homeId] ?? 0) + 1;
      }
      if (awayId != null) {
        goals[awayId] = (goals[awayId] ?? 0) + away;
        games[awayId] = (games[awayId] ?? 0) + 1;
      }
      if (winnerId != null) won[winnerId] = (won[winnerId] ?? 0) + 1;
    }
    final names = {for (final t in teams) t['id'] as int: t['name'] as String};
    final ranked = goals.keys.toList()
      ..sort((a, b) {
        final diff = (goals[b] ?? 0).compareTo(goals[a] ?? 0);
        return diff != 0
            ? diff
            : (names[a] ?? '').compareTo(names[b] ?? '');
      });
    final winRates = <String, double>{};
    for (final id in goals.keys) {
      final count = games[id] ?? 0;
      winRates['$id'] = count == 0
          ? 0.0
          : double.parse((((won[id] ?? 0) / count) * 100).toStringAsFixed(1));
    }
    return {
      'topScorers': [
        for (final id in ranked.take(5))
          {'id': id, 'name': names[id] ?? 'Team $id', 'goals': goals[id] ?? 0},
      ],
      'winRates': winRates,
      'tournamentTotals': {
        'totalGoals': totalGoals,
        'totalMatches': played.length,
        'averageGoalsPerMatch': played.isEmpty
            ? 0.0
            : double.parse((totalGoals / played.length).toStringAsFixed(2)),
      },
    };
  }
}

class _Record {
  _Record(this.teamId, this.teamName, this.group, this.isUserTeam);

  final int teamId;
  final String teamName;
  final String? group;
  final bool isUserTeam;
  int wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0;

  int get played => wins + draws + losses;
  int get goalDifference => goalsFor - goalsAgainst;
  int get points =>
      wins * TournamentFixtures._winPoints +
      draws * TournamentFixtures._drawPoints;

  void record(int scored, int conceded) {
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      wins++;
    } else if (scored == conceded) {
      draws++;
    } else {
      losses++;
    }
  }

  /// Orders by points, goal difference, goals scored, then team name.
  static int compare(_Record left, _Record right) {
    for (final difference in [
      right.points - left.points,
      right.goalDifference - left.goalDifference,
      right.goalsFor - left.goalsFor,
    ]) {
      if (difference != 0) return difference;
    }
    return left.teamName.toLowerCase().compareTo(right.teamName.toLowerCase());
  }

  Map<String, Object?> toJson(int position) => {
    'position': position,
    'teamId': teamId,
    'teamName': teamName,
    'played': played,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'goalDifference': goalDifference,
    'points': points,
    'isUserTeam': isUserTeam,
    'group': group,
  };
}
