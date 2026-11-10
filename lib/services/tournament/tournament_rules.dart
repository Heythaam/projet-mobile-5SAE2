import '../../entities/tournament/tournament.dart';
import 'tournament_service.dart';
import '../../items/tournament/tournament_constants.dart';
import 'tournament_store.dart';

/// The tournament rules that used to run on the Dart server, now applied to
/// one tournament document. Every function either changes the document in
/// place or throws a [TournamentException]; the store saves the document only
/// when nothing was thrown.
abstract final class TournamentRules {
  static const formats = {
    'knockout',
    'league',
    'groups_knockout',
    'round_robin',
  };
  static const allowedMaxTeams = [2, 4, 8, 16, 32];
  static const _nameMin = 3;
  static const _nameMax = 60;
  static const _descriptionMax = 300;
  static const _locationMax = 100;
  static const _prizeMax = 100;
  static const _teamSizeMin = 1;
  static const _teamSizeMax = 11;

  static final _controlCharacters = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final _whitespaceRun = RegExp(r'\s+');

  static Never fail(int status, String message, {String? code}) =>
      throw TournamentException(message, statusCode: status, code: code);

  // ---- Reading a document ------------------------------------------------

  static List<Doc> list(Doc doc, String key) =>
      ((doc[key] as List<dynamic>?) ?? const []).cast<Doc>();

  static List<Doc> activeTeams(Doc doc) => [
    for (final team in list(doc, 'teams'))
      if (team['status'] == 'active') team,
  ];

  static Doc? teamById(Doc doc, int id, {bool activeOnly = true}) {
    for (final team in list(doc, 'teams')) {
      if (team['id'] == id && (!activeOnly || team['status'] == 'active')) {
        return team;
      }
    }
    return null;
  }

  static Doc? captainTeam(Doc doc, int user) {
    for (final team in activeTeams(doc)) {
      if (team['captain'] == user) return team;
    }
    return null;
  }

  static int? myTeamId(Doc doc, int user) {
    final captain = captainTeam(doc, user);
    if (captain != null) return captain['id'] as int;
    for (final request in list(doc, 'requests')) {
      if (request['requester'] == user && request['status'] == 'accepted') {
        return request['teamId'] as int;
      }
    }
    return null;
  }

  static int acceptedCount(Doc doc, int teamId) => [
    for (final request in list(doc, 'requests'))
      if (request['teamId'] == teamId && request['status'] == 'accepted')
        request,
  ].length;

  static bool teamHasMatches(Doc doc, int teamId) => list(doc, 'matches').any(
    (match) => match['home'] == teamId || match['away'] == teamId,
  );

  static String nameOf(Doc doc, int user) =>
      ((doc['names'] as Map<String, dynamic>?)?['$user'] as String?) ??
      'Player';

  static void rememberName(Doc doc, int user, String name) {
    final names =
        (doc['names'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    names['$user'] = name;
    doc['names'] = names;
  }

  static int pendingFor(Doc doc, int user) {
    var count = 0;
    for (final request in list(doc, 'requests')) {
      if (request['status'] != 'pending') continue;
      final team = teamById(doc, request['teamId'] as int);
      if (team != null && team['captain'] == user) count++;
    }
    return count;
  }

  /// Requests waiting for [user] as captain in a tournament still open.
  static int openPendingFor(Doc doc, int user) =>
      doc['status'] == 'upcoming' ? pendingFor(doc, user) : 0;

  static int nextId(Doc doc) {
    final id = (doc['nextId'] as int?) ?? 1;
    doc['nextId'] = id + 1;
    return id;
  }

  // ---- What the screens get ---------------------------------------------

  static Map<String, Object?> summary(Doc doc, int me) {
    final isOpen = doc['status'] == 'upcoming';
    final captain = captainTeam(doc, me);
    final teamId = myTeamId(doc, me);
    final isCaptain = captain != null;
    final isPlayer = !isCaptain && teamId != null;
    final hasPlayers = teamId != null && acceptedCount(doc, teamId) > 0;
    final hasMatches = teamId != null && teamHasMatches(doc, teamId);
    return {
      'id': doc['id'],
      'name': doc['name'],
      'description': doc['description'] ?? '',
      'format': doc['format'],
      'status': doc['status'],
      'startDate': doc['startDate'],
      'endDate': doc['endDate'],
      'maxTeams': doc['maxTeams'],
      'teamSize': doc['teamSize'],
      'currentTeams': activeTeams(doc).length,
      'location': doc['location'] ?? '',
      'prize': doc['prize'],
      'createdBy': doc['createdByName'] ?? '',
      'isOrganizer': doc['createdBy'] == me,
      'joined': isCaptain,
      'canLeave':
          isOpen && (isPlayer || (isCaptain && !hasPlayers && !hasMatches)),
      'canTransfer': isOpen && isCaptain && hasPlayers,
      'canDisband': isOpen && isCaptain && hasPlayers && !hasMatches,
      'myTeamId': teamId,
      'pendingRequests': pendingFor(doc, me),
    };
  }

  static Map<String, Object?> detail(Doc doc, int me) {
    final isOpen = doc['status'] == 'upcoming';
    final requests = list(doc, 'requests');
    bool unseen(String status) => requests.any(
      (r) => r['requester'] == me && r['status'] == status && r['seen'] != true,
    );
    final teams = activeTeams(doc)..sort(_byJoined);
    return {
      ...summary(doc, me),
      'teamDisbanded': unseen('disbanded'),
      'removedFromTeam': unseen('removed'),
      'teams': [
        for (final team in teams)
          {
            'id': team['id'],
            'name': team['name'],
            'players': 1 + acceptedCount(doc, team['id'] as int),
          },
      ],
      'myRequests': [
        for (final r in requests)
          if (r['requester'] == me &&
              !const {
                'cancelled',
                'left',
                'promoted',
                'disbanded',
              }.contains(r['status']))
            {
              'teamId': r['teamId'],
              'status': r['status'] == 'pending' && !isOpen
                  ? 'expired'
                  : r['status'],
            },
      ],
    };
  }

  static int _byJoined(Doc a, Doc b) {
    final byTime = (a['joinedAtMs'] as int).compareTo(b['joinedAtMs'] as int);
    return byTime != 0 ? byTime : (a['id'] as int).compareTo(b['id'] as int);
  }

  // ---- Creating and editing ---------------------------------------------

  static String _clean(String value) => value
      .trim()
      .replaceAll(_controlCharacters, '')
      .replaceAll(_whitespaceRun, ' ');

  static String tournamentName(String raw) {
    final name = _clean(raw);
    if (name.length < _nameMin || name.length > _nameMax) {
      fail(400, 'Tournament name must be $_nameMin to $_nameMax characters.');
    }
    return name;
  }

  static String? optionalText(String? raw, String key, int max) {
    if (raw == null) return null;
    final cleaned = _clean(raw);
    if (cleaned.isEmpty) return null;
    if (cleaned.length > max) {
      fail(400, '"$key" must be at most $max characters.');
    }
    return cleaned;
  }

  static bool validDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null;

  static Doc create({
    required int id,
    required int me,
    required String myName,
    required String name,
    required String format,
    required String startDate,
    required String endDate,
    required int maxTeams,
    required int teamSize,
    String? description,
    String? location,
    String? prize,
  }) {
    final cleanName = tournamentName(name);
    if (!formats.contains(format)) fail(400, 'Invalid tournament format.');
    if (!validDate(startDate) || !validDate(endDate)) {
      fail(400, 'Dates must be YYYY-MM-DD.');
    }
    if (endDate.compareTo(startDate) < 0) {
      fail(400, 'End date must be on or after start date.');
    }
    if (!allowedMaxTeams.contains(maxTeams)) {
      fail(400, 'maxTeams must be one of ${allowedMaxTeams.join(', ')}.');
    }
    if (teamSize < _teamSizeMin || teamSize > _teamSizeMax) {
      fail(400, 'teamSize must be between $_teamSizeMin and $_teamSizeMax.');
    }
    return {
      'id': id,
      'name': cleanName,
      'description':
          optionalText(description, 'description', _descriptionMax) ?? '',
      'format': format,
      'status': 'upcoming',
      'startDate': startDate,
      'endDate': endDate,
      'maxTeams': maxTeams,
      'teamSize': teamSize,
      'location': optionalText(location, 'location', _locationMax) ?? '',
      'prize': optionalText(prize, 'prize', _prizeMax),
      'createdBy': me,
      'createdByName': myName,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'nextId': 1,
      'teams': <Doc>[],
      'requests': <Doc>[],
      'matches': <Doc>[],
      'names': {'$me': myName},
    };
  }

  static void requireOrganizer(Doc doc, int me) {
    if (doc['createdBy'] != me) {
      fail(403, 'Only the tournament organizer can do this.');
    }
  }

  static bool _validTransition(String from, String to) => switch (from) {
    'upcoming' => to == 'active' || to == 'cancelled',
    'active' => to == 'finished' || to == 'cancelled',
    _ => false,
  };

  static void edit(
    Doc doc,
    int me, {
    String? name,
    String? description,
    String? location,
    String? prize,
    String? startDate,
    String? endDate,
    String? status,
  }) {
    requireOrganizer(doc, me);
    final current = doc['status'] as String;
    if (status != null) {
      if (!_validTransition(current, status)) {
        fail(409, 'Cannot change status from $current to $status.');
      }
      if (status == 'active' && activeTeams(doc).length < 2) {
        fail(409, 'At least 2 teams must join before starting.');
      }
    }
    final newName = name == null ? null : tournamentName(name);
    final newDescription = description == null
        ? null
        : (optionalText(description, 'description', _descriptionMax) ?? '');
    final newLocation = location == null
        ? null
        : (optionalText(location, 'location', _locationMax) ?? '');
    final newPrize = prize == null
        ? null
        : optionalText(prize, 'prize', _prizeMax);
    final hasFieldEdit =
        newName != null ||
        newDescription != null ||
        newLocation != null ||
        newPrize != null ||
        startDate != null ||
        endDate != null;
    if (hasFieldEdit) {
      if ((status ?? current) != 'upcoming') {
        fail(409, 'Tournament details can only be changed while upcoming.');
      }
      if ((startDate != null && !validDate(startDate)) ||
          (endDate != null && !validDate(endDate))) {
        fail(400, 'Dates must be YYYY-MM-DD.');
      }
    }
    if (status != null) doc['status'] = status;
    if (newName != null) doc['name'] = newName;
    if (newDescription != null) doc['description'] = newDescription;
    if (newLocation != null) doc['location'] = newLocation;
    if (newPrize != null) doc['prize'] = newPrize;
    if (startDate != null) doc['startDate'] = startDate;
    if (endDate != null) doc['endDate'] = endDate;
  }

  // ---- Teams -------------------------------------------------------------

  static Never _registrationClosed() =>
      fail(409, 'Registration for this tournament is closed.');
  static Never _alreadyOnTeam() =>
      fail(409, 'You already play for a team in this tournament.');
  static Never _notJoined() =>
      fail(409, 'You have not joined this tournament.');
  static Never _leaveClosed() =>
      fail(409, 'You can only leave before the tournament starts.');

  static void _closeRequests(
    Doc doc, {
    required int teamId,
    required Map<String, String> changes,
  }) {
    for (final request in list(doc, 'requests')) {
      if (request['teamId'] != teamId) continue;
      final next = changes[request['status']];
      if (next != null) request['status'] = next;
    }
  }

  static void join(Doc doc, int me, String myName, String rawTeamName) {
    final teamName = TeamName.normalize(rawTeamName);
    final problem = TeamName.validate(teamName);
    if (problem != null) fail(400, problem);
    if (captainTeam(doc, me) != null) {
      fail(409, 'You already joined this tournament.');
    }
    if (myTeamId(doc, me) != null) _alreadyOnTeam();
    if (doc['status'] != 'upcoming') _registrationClosed();
    final taken = activeTeams(doc).any(
      (team) =>
          (team['name'] as String).toLowerCase() == teamName.toLowerCase(),
    );
    if (taken) {
      fail(409, 'That team name is already taken in this tournament.');
    }
    if (activeTeams(doc).length >= (doc['maxTeams'] as int)) {
      fail(409, 'This tournament is full.');
    }
    final teams = list(doc, 'teams');
    teams.add({
      'id': nextId(doc),
      'name': teamName,
      'captain': me,
      'status': 'active',
      'joinedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    doc['teams'] = teams;
    for (final request in list(doc, 'requests')) {
      if (request['requester'] == me && request['status'] == 'pending') {
        request['status'] = 'cancelled';
      }
    }
    rememberName(doc, me, myName);
  }

  /// Withdraws the user while registration is open: a player leaves their
  /// team; a captain withdraws the team (with `disband`, also its players).
  static void leave(Doc doc, int me, {required bool disband}) {
    final teamId = myTeamId(doc, me);
    if (teamId == null) _notJoined();
    if (doc['status'] != 'upcoming') _leaveClosed();
    final captain = captainTeam(doc, me);
    if (captain == null) {
      for (final request in list(doc, 'requests')) {
        if (request['requester'] == me && request['status'] == 'accepted') {
          request['status'] = 'left';
        }
      }
      return;
    }
    if (teamHasMatches(doc, teamId)) {
      fail(409, 'Your team already has scheduled matches and cannot leave.');
    }
    final hasPlayers = acceptedCount(doc, teamId) > 0;
    if (hasPlayers && !disband) {
      fail(
        409,
        'Your team has players. Transfer captaincy or disband the team.',
      );
    }
    captain['status'] = hasPlayers ? 'disbanded' : 'left';
    captain['leftAtMs'] = DateTime.now().millisecondsSinceEpoch;
    _closeRequests(
      doc,
      teamId: teamId,
      changes: {'accepted': 'disbanded', 'pending': 'cancelled'},
    );
  }

  static void transferCaptaincy(Doc doc, int me, int newCaptain) {
    if (newCaptain == me) fail(400, 'You are already the captain.');
    final team = captainTeam(doc, me);
    if (team == null) {
      if (myTeamId(doc, me) != null) {
        fail(
          403,
          'You are no longer the captain of this team.',
          code: TournamentErrorCodes.NOT_CAPTAIN,
        );
      }
      final withdrawn = list(
        doc,
        'teams',
      ).any((t) => t['captain'] == me && t['status'] != 'active');
      if (withdrawn) {
        fail(
          409,
          'Your team is no longer in this tournament.',
          code: TournamentErrorCodes.TEAM_WITHDRAWN,
        );
      }
      fail(
        403,
        'Only the team captain can transfer captaincy.',
        code: TournamentErrorCodes.NOT_CAPTAIN,
      );
    }
    if (doc['status'] != 'upcoming') {
      fail(
        409,
        'Captaincy can only be transferred before the tournament starts.',
        code: TournamentErrorCodes.TRANSFER_CLOSED,
      );
    }
    final teamId = team['id'] as int;
    Doc? membership;
    for (final request in list(doc, 'requests')) {
      if (request['teamId'] == teamId &&
          request['requester'] == newCaptain &&
          request['status'] == 'accepted') {
        membership = request;
      }
    }
    if (membership == null) {
      fail(
        404,
        'Player not found on this team.',
        code: TournamentErrorCodes.PLAYER_NOT_ON_TEAM,
      );
    }
    membership['status'] = 'promoted';
    team['captain'] = newCaptain;
    final requests = list(doc, 'requests');
    requests.add({
      'id': nextId(doc),
      'teamId': teamId,
      'requester': me,
      'status': 'accepted',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    doc['requests'] = requests;
  }

  static void dismissNotice(Doc doc, int me, String status) {
    for (final request in list(doc, 'requests')) {
      if (request['requester'] == me && request['status'] == status) {
        request['seen'] = true;
      }
    }
  }

  // ---- Join requests -----------------------------------------------------

  static void requestToJoin(Doc doc, int me, String myName, int teamId) {
    if (doc['status'] != 'upcoming') _registrationClosed();
    final team = teamById(doc, teamId);
    if (team == null) fail(404, 'Team not found.');
    if (myTeamId(doc, me) != null) _alreadyOnTeam();
    final mine = [
      for (final r in list(doc, 'requests'))
        if (r['requester'] == me &&
            const {'pending', 'declined', 'removed'}.contains(r['status']))
          r,
    ];
    if (mine.any((r) => r['status'] == 'pending')) {
      fail(409, 'You already have a pending request in this tournament.');
    }
    for (final r in mine.where((r) => r['teamId'] == teamId)) {
      fail(
        409,
        r['status'] == 'removed'
            ? 'You were removed from this team.'
            : 'This team declined your request.',
      );
    }
    if (1 + acceptedCount(doc, teamId) >= (doc['teamSize'] as int)) {
      fail(409, 'This team is full.');
    }
    final requests = list(doc, 'requests');
    requests.add({
      'id': nextId(doc),
      'teamId': teamId,
      'requester': me,
      'status': 'pending',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    doc['requests'] = requests;
    rememberName(doc, me, myName);
  }

  static Map<String, Object?> requestJson(Doc doc, Doc request) {
    final team = teamById(doc, request['teamId'] as int, activeOnly: false);
    return {
      'id': request['id'],
      'teamId': request['teamId'],
      'teamName': team?['name'] ?? '',
      'requesterId': request['requester'],
      'requesterName': nameOf(doc, request['requester'] as int),
      'status': request['status'],
      'createdAt': DateTime.fromMillisecondsSinceEpoch(
        request['createdAtMs'] as int,
        isUtc: true,
      ).toIso8601String(),
    };
  }

  static List<Map<String, Object?>> pendingRequests(Doc doc, int me) {
    if (captainTeam(doc, me) == null) {
      fail(403, 'Only team captains can see join requests.');
    }
    final found = [
      for (final r in list(doc, 'requests'))
        if (r['status'] == 'pending' &&
            teamById(doc, r['teamId'] as int)?['captain'] == me)
          r,
    ]..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return [for (final r in found) requestJson(doc, r)];
  }

  /// Answers a request to the captain's team and returns it.
  static Doc answer(Doc doc, int me, int requestId, {required bool accept}) {
    Doc? request;
    for (final r in list(doc, 'requests')) {
      if (r['id'] != requestId) continue;
      final team = teamById(doc, r['teamId'] as int);
      if (team != null && team['captain'] == me) request = r;
    }
    if (request == null) fail(404, 'Join request not found.');
    if (request['status'] != 'pending') {
      fail(409, 'This request was already answered.');
    }
    if (doc['status'] != 'upcoming') _registrationClosed();
    if (accept) {
      final teamId = request['teamId'] as int;
      if (1 + acceptedCount(doc, teamId) >= (doc['teamSize'] as int)) {
        fail(409, 'Your team is full.');
      }
      if (captainTeam(doc, request['requester'] as int) != null) {
        fail(409, 'This player already has a team.');
      }
    }
    request['status'] = accept ? 'accepted' : 'declined';
    return request;
  }

  // ---- Team page ---------------------------------------------------------

  static Map<String, Object?> teamDetail(Doc doc, int me, int teamId) {
    final team = teamById(doc, teamId);
    if (team == null) fail(404, 'Team not found.');
    final captain = team['captain'] as int;
    final members = <int>[
      captain,
      for (final r in list(doc, 'requests'))
        if (r['teamId'] == teamId && r['status'] == 'accepted')
          r['requester'] as int,
    ];
    var played = 0, wins = 0, draws = 0, losses = 0, gf = 0, ga = 0;
    for (final match in list(doc, 'matches')) {
      if (match['status'] != 'played') continue;
      final isHome = match['home'] == teamId;
      if (!isHome && match['away'] != teamId) continue;
      final home = match['homeScore'] as int;
      final away = match['awayScore'] as int;
      final scored = isHome ? home : away;
      final conceded = isHome ? away : home;
      played++;
      gf += scored;
      ga += conceded;
      if (scored > conceded) {
        wins++;
      } else if (scored == conceded) {
        draws++;
      } else {
        losses++;
      }
    }
    return {
      'id': teamId,
      'name': team['name'],
      'captainId': captain,
      'captainName': nameOf(doc, captain),
      'teamSize': doc['teamSize'],
      'canManage': captain == me && doc['status'] == 'upcoming',
      'players': [
        for (final id in members)
          {
            'id': id,
            'username': nameOf(doc, id),
            'xp': 0,
            'level': 1,
            'currentStreak': 0,
            'isCaptain': id == captain,
          },
      ],
      'stats': {
        'players': members.length,
        'totalXp': 0,
        'averageLevel': 1,
        'played': played,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'goalsFor': gf,
        'goalsAgainst': ga,
        'points': wins * 3 + draws,
      },
    };
  }

  static void removePlayer(Doc doc, int me, int teamId, int playerId) {
    final team = teamById(doc, teamId);
    if (team == null || team['captain'] != me) fail(404, 'Team not found.');
    if (playerId == me) {
      fail(
        400,
        'Captains cannot remove themselves. Transfer captaincy or leave instead.',
      );
    }
    if (doc['status'] != 'upcoming') {
      fail(409, 'Players can only be removed before the tournament starts.');
    }
    Doc? membership;
    for (final r in list(doc, 'requests')) {
      if (r['teamId'] == teamId &&
          r['requester'] == playerId &&
          r['status'] == 'accepted') {
        membership = r;
      }
    }
    if (membership == null) fail(404, 'Player not found on this team.');
    membership['status'] = 'removed';
  }
}
