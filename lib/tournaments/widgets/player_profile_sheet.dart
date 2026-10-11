import 'package:flutter/material.dart';

import '../../achievement_icons.dart';
import '../../screens/kickoff_style.dart';
import '../models/player_profile.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import 'sheet_frame.dart';
import 'tournament_states.dart';

/// Shows another player's stats, achievements and recent matches.
Future<void> showPlayerProfileSheet(
  BuildContext context, {
  required TournamentService service,
  required int userId,
  required String username,
}) => showTournamentSheet<void>(
  context,
  builder: (_) =>
      PlayerProfileSheet(service: service, userId: userId, username: username),
);

class PlayerProfileSheet extends StatefulWidget {
  const PlayerProfileSheet({
    required this.service,
    required this.userId,
    required this.username,
    super.key,
  });

  final TournamentService service;
  final int userId;

  /// Shown as the title while the profile loads.
  final String username;

  @override
  State<PlayerProfileSheet> createState() => _PlayerProfileSheetState();
}

class _PlayerProfileSheetState extends State<PlayerProfileSheet> {
  bool _isLoading = true;
  String? _error;
  PlayerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await widget.service.getPlayerProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => TournamentSheetFrame(
    title: _profile?.username ?? widget.username,
    onClose: () => Navigator.of(context).pop(),
    child: _body(),
  );

  Widget _body() {
    final error = _error;
    final profile = _profile;
    if (_isLoading) return const TournamentLoading();
    if (error != null || profile == null) {
      return TournamentError(
        message: error ?? TournamentStrings.ERROR_LOAD_PROFILE,
        onRetry: _loadProfile,
      );
    }
    final scale = kickoffScale(context);
    final emptyStyle = TextStyle(
      color: KickoffColors.muted,
      fontSize: TournamentSizes.CAPTION * scale,
      fontWeight: FontWeight.w500,
    );
    return ListView(
      padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
      children: [
        Text(
          TournamentStrings.profileRank(profile.rank, profile.level),
          style: TextStyle(
            color: KickoffColors.yellow,
            fontSize: TournamentSizes.BODY * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12 * scale),
        StatGrid(
          tiles: [
            StatTile(
              label: TournamentStrings.PROFILE_XP,
              value: '${profile.xp}',
            ),
            StatTile(
              label: TournamentStrings.PROFILE_STREAK,
              value: '🔥 ${profile.currentStreak}',
            ),
            StatTile(
              label: TournamentStrings.PROFILE_BEST_STREAK,
              value: '${profile.bestStreak}',
            ),
          ],
        ),
        const SheetSectionTitle(TournamentStrings.PROFILE_ACHIEVEMENTS),
        if (profile.achievements.isEmpty)
          Text(TournamentStrings.PROFILE_NO_ACHIEVEMENTS, style: emptyStyle)
        else
          for (final achievement in profile.achievements)
            _ProfileRow(
              icon: achievementIcon(achievement.icon),
              title: achievement.title,
            ),
        const SheetSectionTitle(TournamentStrings.PROFILE_MATCHES),
        if (profile.recentMatches.isEmpty)
          Text(TournamentStrings.NO_MATCHES_PLAYED, style: emptyStyle)
        else
          for (final match in profile.recentMatches) _MatchRow(match: match),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      child: Row(
        children: [
          Icon(icon, color: KickoffColors.yellow, size: 22 * scale),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final ProfileMatch match;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final (label, color) = switch (match.result) {
      MatchResult.win => (
        TournamentStrings.RESULT_WIN,
        TournamentColors.SUCCESS,
      ),
      MatchResult.draw => (
        TournamentStrings.RESULT_DRAW,
        TournamentColors.FINISHED,
      ),
      MatchResult.loss => (
        TournamentStrings.RESULT_LOSS,
        TournamentColors.ERROR,
      ),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      child: Row(
        children: [
          Container(
            width: 32 * scale,
            height: 32 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              label,
              style: TextStyle(
                color: KickoffColors.ink,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TournamentStrings.matchScore(
                    match.goalsFor,
                    match.goalsAgainst,
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  TournamentStrings.matchOpponent(
                    match.opponentName,
                    match.tournamentName,
                    match.playedAt,
                  ),
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: TournamentSizes.CAPTION * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
