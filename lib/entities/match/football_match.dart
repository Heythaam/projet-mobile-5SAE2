enum MatchParticipation { created, joined }

class FootballMatch {
  const FootballMatch({
    required this.id,
    required this.scheduledAt,
    required this.stadium,
    required this.joinedSlots,
    required this.totalSlots,
    required this.isPublic,
    required this.participation,
  });

  final String id;
  final DateTime scheduledAt;
  final String stadium;
  final int joinedSlots;
  final int totalSlots;
  final bool isPublic;
  final MatchParticipation participation;
}
