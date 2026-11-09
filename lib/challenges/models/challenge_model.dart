enum ChallengeType {
  team,
  open;

  static ChallengeType fromString(String val) =>
      val == 'team' ? ChallengeType.team : ChallengeType.open;

  String get nameString => this == ChallengeType.team ? 'team' : 'open';
}

enum ChallengeStatus {
  active,
  completed,
  cancelled;

  static ChallengeStatus fromString(String val) => switch (val) {
        'completed' => ChallengeStatus.completed,
        'cancelled' => ChallengeStatus.cancelled,
        _ => ChallengeStatus.active,
      };

  String get nameString => switch (this) {
        ChallengeStatus.completed => 'completed',
        ChallengeStatus.cancelled => 'cancelled',
        ChallengeStatus.active => 'active',
      };
}

class Challenge {
  const Challenge({
    this.id,
    required this.type,
    this.teamId,
    this.teamName,
    required this.description,
    required this.difficulty,
    required this.locationName,
    required this.dateTime,
    required this.maxPlayers,
    this.currentPlayers = 1,
    required this.joinCode,
    required this.createdByUserId,
    this.status = ChallengeStatus.active,
    this.isJoined = false,
    this.isCreatedByMe = false,
  });

  final int? id;
  final ChallengeType type;
  final int? teamId;
  final String? teamName;
  final String description;
  final int difficulty; // 1 to 5
  final String locationName;
  final DateTime dateTime;
  final int maxPlayers;
  final int currentPlayers;
  final String joinCode;
  final int createdByUserId;
  final ChallengeStatus status;
  final bool isJoined;
  final bool isCreatedByMe;

  bool get isFull => currentPlayers >= maxPlayers;
  bool get isTeamChallenge => type == ChallengeType.team;

  Challenge copyWith({
    int? id,
    ChallengeType? type,
    int? teamId,
    String? teamName,
    String? description,
    int? difficulty,
    String? locationName,
    DateTime? dateTime,
    int? maxPlayers,
    int? currentPlayers,
    String? joinCode,
    int? createdByUserId,
    ChallengeStatus? status,
    bool? isJoined,
    bool? isCreatedByMe,
  }) =>
      Challenge(
        id: id ?? this.id,
        type: type ?? this.type,
        teamId: teamId ?? this.teamId,
        teamName: teamName ?? this.teamName,
        description: description ?? this.description,
        difficulty: difficulty ?? this.difficulty,
        locationName: locationName ?? this.locationName,
        dateTime: dateTime ?? this.dateTime,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        currentPlayers: currentPlayers ?? this.currentPlayers,
        joinCode: joinCode ?? this.joinCode,
        createdByUserId: createdByUserId ?? this.createdByUserId,
        status: status ?? this.status,
        isJoined: isJoined ?? this.isJoined,
        isCreatedByMe: isCreatedByMe ?? this.isCreatedByMe,
      );

  factory Challenge.fromMap(
    Map<String, dynamic> map, {
    int? currentUserId,
    bool? isJoinedOverride,
  }) {
    final creatorId = map['created_by_user_id'] as int? ?? 0;
    final isCreated = currentUserId != null && creatorId == currentUserId;
    final isJoinedVal = isJoinedOverride ??
        (map['is_joined'] != null
            ? (map['is_joined'] == 1 || map['is_joined'] == true)
            : isCreated);

    return Challenge(
      id: map['id'] as int?,
      type: ChallengeType.fromString(map['type'] as String? ?? 'open'),
      teamId: map['team_id'] as int?,
      teamName: map['team_name'] as String?,
      description: map['description'] as String? ?? '',
      difficulty: map['difficulty'] as int? ?? 1,
      locationName: map['location_name'] as String? ?? '',
      dateTime: DateTime.tryParse(map['date_time'] as String? ?? '') ??
          DateTime.now(),
      maxPlayers: map['max_players'] as int? ?? 10,
      currentPlayers: map['current_players'] as int? ?? 1,
      joinCode: map['join_code'] as String? ?? '',
      createdByUserId: creatorId,
      status: ChallengeStatus.fromString(
          map['challenge_status'] as String? ?? 'active'),
      isJoined: isJoinedVal,
      isCreatedByMe: isCreated,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type.nameString,
        'team_id': teamId,
        'description': description,
        'difficulty': difficulty,
        'location_name': locationName,
        'date_time': dateTime.toIso8601String(),
        'max_players': maxPlayers,
        'current_players': currentPlayers,
        'join_code': joinCode,
        'created_by_user_id': createdByUserId,
        'challenge_status': status.nameString,
      };
}
