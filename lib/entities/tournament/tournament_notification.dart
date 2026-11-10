class TournamentNotification {
  const TournamentNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.isRead,
    this.tournamentId,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String title;
  final String body;
  final bool isRead;
  final int? tournamentId;
  final String createdAt;

  factory TournamentNotification.fromJson(Map<String, dynamic> json) =>
      TournamentNotification(
        id: json['id'] as int,
        userId: json['userId'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        tournamentId: json['tournamentId'] as int?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
