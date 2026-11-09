import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/team_details.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import 'confirm_action_sheet.dart';
import 'sheet_frame.dart';
import 'tournament_states.dart';

/// Shows a team's roster and results. Resolves to true when the captain
/// removed a player, so the caller can refresh team counts.
Future<bool> showTeamDetailsSheet(
  BuildContext context, {
  required TournamentService service,
  required int tournamentId,
  required int teamId,
}) async {
  final changed = await showTournamentSheet<bool>(
    context,
    builder: (_) => TeamDetailsSheet(
      service: service,
      tournamentId: tournamentId,
      teamId: teamId,
    ),
  );
  return changed ?? false;
}

class TeamDetailsSheet extends StatefulWidget {
  const TeamDetailsSheet({
    required this.service,
    required this.tournamentId,
    required this.teamId,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;
  final int teamId;

  @override
  State<TeamDetailsSheet> createState() => _TeamDetailsSheetState();
}

class _TeamDetailsSheetState extends State<TeamDetailsSheet> {
  bool _isLoading = true;
  String? _error;
  TeamDetails? _team;
  String? _notice;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final team = await widget.service.getTeam(
        widget.tournamentId,
        widget.teamId,
      );
      if (!mounted) return;
      setState(() {
        _team = team;
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

  Future<void> _confirmRemove(TeamDetails team, TeamPlayer player) async {
    setState(() => _notice = null);
    await showRemovePlayerSheet(
      context,
      playerName: player.username,
      teamName: team.name,
      onRemove: () async {
        try {
          final updated = await widget.service.removePlayer(
            widget.tournamentId,
            team.id,
            player.id,
          );
          if (mounted) {
            setState(() {
              _team = updated;
              _changed = true;
              _notice = TournamentStrings.PLAYER_REMOVED;
            });
          }
          return null;
        } on TournamentException catch (error) {
          return error.message;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => TournamentSheetFrame(
    title: _team?.name ?? TournamentStrings.TEAMS,
    notice: _notice,
    onClose: () => Navigator.of(context).pop(_changed),
    child: _body(),
  );

  Widget _body() {
    final error = _error;
    final team = _team;
    if (_isLoading) return const TournamentLoading();
    if (error != null || team == null) {
      return TournamentError(
        message: error ?? TournamentStrings.ERROR_LOAD_TEAM,
        onRetry: _loadTeam,
      );
    }
    final scale = kickoffScale(context);
    final stats = team.stats;
    return ListView(
      padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
      children: [
        Text(
          TournamentStrings.captainLine(team.captainName),
          style: TextStyle(
            color: KickoffColors.muted,
            fontSize: TournamentSizes.BODY * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SheetSectionTitle(TournamentStrings.PLAYERS),
        for (final player in team.players) ...[
          _PlayerRow(
            player: player,
            onRemove: team.canManage && !player.isCaptain
                ? () => _confirmRemove(team, player)
                : null,
          ),
          SizedBox(height: 6 * scale),
        ],
        const SheetSectionTitle(TournamentStrings.TEAM_STATS),
        StatGrid(
          tiles: [
            StatTile(
              label: TournamentStrings.STAT_PLAYERS,
              value: '${stats.players}/${team.teamSize}',
            ),
            StatTile(
              label: TournamentStrings.STAT_TOTAL_XP,
              value: '${stats.totalXp}',
            ),
            StatTile(
              label: TournamentStrings.STAT_AVERAGE_LEVEL,
              value: '${stats.averageLevel}',
            ),
            StatTile(
              label: TournamentStrings.STAT_POINTS,
              value: '${stats.points}',
            ),
            StatTile(
              label: TournamentStrings.STAT_RECORD,
              value: '${stats.wins}-${stats.draws}-${stats.losses}',
            ),
            StatTile(
              label: TournamentStrings.STAT_GOALS,
              value: '${stats.goalsFor}:${stats.goalsAgainst}',
            ),
          ],
        ),
        if (stats.played == 0) ...[
          SizedBox(height: 8 * scale),
          Text(
            TournamentStrings.NO_MATCHES_PLAYED,
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: TournamentSizes.CAPTION * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, this.onRemove});

  final TeamPlayer player;

  /// Null when the viewer cannot remove this player.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final onRemove = this.onRemove;
    return Container(
      constraints: BoxConstraints(minHeight: TournamentSizes.MIN_TAP * scale),
      padding: EdgeInsets.fromLTRB(12 * scale, 6 * scale, 4 * scale, 6 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Row(
        children: [
          Icon(
            player.isCaptain ? Icons.star_rounded : Icons.person_rounded,
            color: KickoffColors.yellow,
            size: 22 * scale,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.isCaptain
                      ? '${player.username} · ${TournamentStrings.CAPTAIN}'
                      : player.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  TournamentStrings.playerLine(
                    player.level,
                    player.xp,
                    player.currentStreak,
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
          if (onRemove != null)
            IconButton(
              key: ValueKey('team_remove_${player.id}'),
              tooltip: TournamentStrings.REMOVE_PLAYER,
              onPressed: onRemove,
              constraints: BoxConstraints(
                minWidth: TournamentSizes.MIN_TAP * scale,
                minHeight: TournamentSizes.MIN_TAP * scale,
              ),
              icon: Icon(
                Icons.person_remove_rounded,
                color: TournamentColors.ERROR_TEXT,
                size: 22 * scale,
              ),
            ),
        ],
      ),
    );
  }
}
