import '../tournament_constants.dart';

enum TournamentStatus {
  upcoming('upcoming', TournamentStrings.STATUS_UPCOMING),
  active('active', TournamentStrings.STATUS_ACTIVE),
  finished('finished', TournamentStrings.STATUS_FINISHED),
  cancelled('cancelled', TournamentStrings.STATUS_CANCELLED);

  const TournamentStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TournamentStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Unknown tournament status: $value'),
  );
}

enum TournamentFormat {
  knockout('knockout', TournamentStrings.FORMAT_KNOCKOUT),
  league('league', TournamentStrings.FORMAT_LEAGUE),
  groupsKnockout('groups_knockout', TournamentStrings.FORMAT_GROUPS_KNOCKOUT),
  roundRobin('round_robin', TournamentStrings.FORMAT_ROUND_ROBIN);

  const TournamentFormat(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TournamentFormat fromApi(String value) => values.firstWhere(
    (format) => format.apiValue == value,
    orElse: () => throw FormatException('Unknown tournament format: $value'),
  );

  /// League tables: whole-tournament for leagues, per group otherwise.
  bool get hasStandings => this != knockout;

  /// Knockout tree: the whole tournament, or the stage after the groups.
  bool get hasBracket => this == knockout || this == groupsKnockout;
}

class TournamentTeam {
  const TournamentTeam({
    required this.id,
    required this.name,
    this.players = 1,
  });

  final int id;
  final String name;

  /// Captain plus accepted players.
  final int players;

  factory TournamentTeam.fromJson(Map<String, dynamic> json) => TournamentTeam(
    id: json['id'] as int,
    name: json['name'] as String,
    players: json['players'] as int? ?? 1,
  );
}

enum JoinRequestStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  cancelled('cancelled'),

  /// The captain removed the player from the team.
  removed('removed'),

  /// Reported for a pending request once registration has closed.
  expired('expired');

  const JoinRequestStatus(this.apiValue);

  final String apiValue;

  static JoinRequestStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Unknown request status: $value'),
  );
}

/// The signed-in user's own request to join a team.
class MyJoinRequest {
  const MyJoinRequest({required this.teamId, required this.status});

  final int teamId;
  final JoinRequestStatus status;

  factory MyJoinRequest.fromJson(Map<String, dynamic> json) => MyJoinRequest(
    teamId: json['teamId'] as int,
    status: JoinRequestStatus.fromApi(json['status'] as String),
  );
}

/// A request to join the signed-in captain's team.
class TeamJoinRequest {
  const TeamJoinRequest({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int teamId;
  final String teamName;
  final int requesterId;
  final String requesterName;
  final JoinRequestStatus status;
  final DateTime createdAt;

  factory TeamJoinRequest.fromJson(Map<String, dynamic> json) =>
      TeamJoinRequest(
        id: json['id'] as int,
        teamId: json['teamId'] as int,
        teamName: json['teamName'] as String,
        requesterId: json['requesterId'] as int,
        requesterName: json['requesterName'] as String,
        status: JoinRequestStatus.fromApi(json['status'] as String),
        createdAt: _parseUtc(json['createdAt'] as String),
      );

  /// SQLite's `CURRENT_TIMESTAMP` is UTC without a zone marker; values that
  /// already carry one are parsed as given.
  static DateTime _parseUtc(String value) {
    final parsed = DateTime.parse(value);
    if (parsed.isUtc || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value)) {
      return parsed;
    }
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }
}

class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.format,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.maxTeams,
    required this.currentTeams,
    required this.location,
    required this.createdBy,
    required this.joined,
    required this.canLeave,
    this.teamSize = 1,
    this.myTeamId,
    this.pendingRequests = 0,
    this.prize,
    this.teams = const [],
    this.myRequests = const [],
  });

  final int id;
  final String name;
  final String description;
  final TournamentFormat format;
  final TournamentStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final int maxTeams;
  final int currentTeams;
  final String location;
  final String createdBy;

  /// Whether the signed-in user is already registered, as reported by the API.
  final bool joined;

  /// Whether the API allows withdrawing: registration is open and the team
  /// has no matches yet.
  final bool canLeave;

  /// Players per team, captain included.
  final int teamSize;

  /// The team the user plays for, as captain or accepted player.
  final int? myTeamId;

  /// Requests waiting for this user's answer as captain.
  final int pendingRequests;
  final String? prize;

  /// Only returned by the detail endpoint; empty in list responses.
  final List<TournamentTeam> teams;

  /// The user's requests to join teams; detail endpoint only.
  final List<MyJoinRequest> myRequests;

  bool get isFull => currentTeams >= maxTeams;
  bool get isOpen => status == TournamentStatus.upcoming;
  bool get hasTeam => myTeamId != null;
  bool get canJoin => isOpen && !isFull && !hasTeam;
  int get spotsLeft => (maxTeams - currentTeams).clamp(0, maxTeams);

  /// Captains answer requests only while registration is open.
  bool get canManageRequests => joined && isOpen;
  bool get hasPendingRequest =>
      myRequests.any((request) => request.status == JoinRequestStatus.pending);

  bool isTeamFull(TournamentTeam team) => team.players >= teamSize;

  /// Name of the team the user is waiting to hear from, if it is known.
  String? get pendingRequestTeamName {
    for (final request in myRequests) {
      if (request.status != JoinRequestStatus.pending) continue;
      for (final team in teams) {
        if (team.id == request.teamId) return team.name;
      }
    }
    return null;
  }

  /// The latest request the user sent to [teamId], if any.
  MyJoinRequest? requestFor(int teamId) =>
      myRequests.where((request) => request.teamId == teamId).lastOrNull;

  /// Whether the user may ask to join [team] right now.
  bool canRequestToJoin(TournamentTeam team) =>
      isOpen &&
      !hasTeam &&
      !hasPendingRequest &&
      requestFor(team.id) == null &&
      !isTeamFull(team);

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    format: TournamentFormat.fromApi(json['format'] as String),
    status: TournamentStatus.fromApi(json['status'] as String),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    maxTeams: json['maxTeams'] as int,
    currentTeams: json['currentTeams'] as int,
    location: json['location'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    joined: json['joined'] as bool? ?? false,
    canLeave: json['canLeave'] as bool? ?? false,
    teamSize: json['teamSize'] as int? ?? 1,
    myTeamId: json['myTeamId'] as int?,
    pendingRequests: json['pendingRequests'] as int? ?? 0,
    prize: json['prize'] as String?,
    teams: (json['teams'] as List<dynamic>? ?? const [])
        .map((item) => TournamentTeam.fromJson(item as Map<String, dynamic>))
        .toList(),
    myRequests: (json['myRequests'] as List<dynamic>? ?? const [])
        .map((item) => MyJoinRequest.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class StandingRow {
  const StandingRow({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    this.isUserTeam = false,
    this.group,
  });

  final int position;
  final int teamId;
  final String teamName;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  /// True when the signed-in user plays for this team, so it can be highlighted.
  final bool isUserTeam;

  /// Group label in a groups + knockout tournament; null for one table.
  final String? group;

  factory StandingRow.fromJson(Map<String, dynamic> json) => StandingRow(
    position: json['position'] as int,
    teamId: json['teamId'] as int,
    teamName: json['teamName'] as String,
    played: json['played'] as int,
    wins: json['wins'] as int,
    draws: json['draws'] as int,
    losses: json['losses'] as int,
    goalsFor: json['goalsFor'] as int,
    goalsAgainst: json['goalsAgainst'] as int,
    goalDifference: json['goalDifference'] as int,
    points: json['points'] as int,
    isUserTeam: json['isUserTeam'] as bool? ?? false,
    group: json['group'] as String?,
  );
}

/// Team-name rules shared with the API (`POST /tournaments/:id/join`), so the
/// join sheet can explain a problem before sending the request.
abstract final class TeamName {
  static final _allowed = RegExp(r"^[\p{L}\p{M}\p{N} '._-]+$", unicode: true);
  static final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Trims the name and collapses repeated spaces, as the API does.
  static String normalize(String input) =>
      input.trim().replaceAll(_spaces, ' ');

  /// Returns a message describing what is wrong, or null for a valid name.
  static String? validate(String input) {
    final name = normalize(input);
    if (name.length < TournamentSizes.TEAM_NAME_MIN_LENGTH ||
        name.length > TournamentSizes.TEAM_NAME_MAX_LENGTH) {
      return TournamentStrings.TEAM_NAME_LENGTH;
    }
    if (!_allowed.hasMatch(name) || !_alphanumeric.hasMatch(name)) {
      return TournamentStrings.TEAM_NAME_CHARACTERS;
    }
    return null;
  }
}
