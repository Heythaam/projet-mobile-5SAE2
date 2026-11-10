import 'package:flutter/material.dart';

/// Numbers the awards are worked out from. All come from matches saved on the
/// phone, so awards work offline.
class AwardStats {
  const AwardStats({
    this.played = 0,
    this.hosted = 0,
    this.finished = 0,
    this.hostedPublic = 0,
    this.stadiums = 0,
  });

  /// Matches the player is in, past ones included.
  final int played;

  /// Matches the player created.
  final int hosted;

  /// Matches the player was in that already started.
  final int finished;

  /// Created matches that are open to everyone.
  final int hostedPublic;

  /// Different places the player has a match at.
  final int stadiums;
}

class LocalAward {
  const LocalAward({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int progress;
  final int target;

  bool get unlocked => progress >= target;

  /// 0 to 1, for the progress bar.
  double get fraction => target == 0 ? 1 : (progress / target).clamp(0, 1);
}

/// Every award with the player's progress. Unlocked ones come first.
List<LocalAward> localAwards(AwardStats s) {
  final all = [
    LocalAward(
      id: 'first_kickoff',
      title: 'First kickoff',
      description: 'Join or create your first match',
      icon: Icons.sports_soccer_rounded,
      progress: s.played,
      target: 1,
    ),
    LocalAward(
      id: 'final_whistle',
      title: 'Final whistle',
      description: 'Play a match to the end',
      icon: Icons.sports_rounded,
      progress: s.finished,
      target: 1,
    ),
    LocalAward(
      id: 'organiser',
      title: 'Organiser',
      description: 'Create a match',
      icon: Icons.edit_calendar_rounded,
      progress: s.hosted,
      target: 1,
    ),
    LocalAward(
      id: 'open_doors',
      title: 'Open doors',
      description: 'Create a public match',
      icon: Icons.public_rounded,
      progress: s.hostedPublic,
      target: 1,
    ),
    LocalAward(
      id: 'regular',
      title: 'Regular',
      description: 'Be in 5 matches',
      icon: Icons.repeat_rounded,
      progress: s.played,
      target: 5,
    ),
    LocalAward(
      id: 'explorer',
      title: 'Explorer',
      description: 'Play at 3 different places',
      icon: Icons.explore_rounded,
      progress: s.stadiums,
      target: 3,
    ),
    LocalAward(
      id: 'captain',
      title: 'Captain',
      description: 'Create 5 matches',
      icon: Icons.military_tech_rounded,
      progress: s.hosted,
      target: 5,
    ),
    LocalAward(
      id: 'veteran',
      title: 'Veteran',
      description: 'Finish 10 matches',
      icon: Icons.workspace_premium_rounded,
      progress: s.finished,
      target: 10,
    ),
  ];
  return [
    ...all.where((a) => a.unlocked),
    ...all.where((a) => !a.unlocked),
  ];
}
