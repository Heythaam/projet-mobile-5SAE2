import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../tournament_constants.dart';

/// A team in the detail Teams tab, with the user's way to join it.
class TeamTile extends StatelessWidget {
  const TeamTile({
    required this.team,
    required this.tournament,
    required this.onRequest,
    required this.onViewTeam,
    this.busy = false,
    super.key,
  });

  final TournamentTeam team;
  final Tournament tournament;
  final VoidCallback onRequest;
  final VoidCallback onViewTeam;

  /// True while this tile's request is being sent.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final status = _status();
    return Container(
      constraints: BoxConstraints(minHeight: TournamentSizes.MIN_TAP * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: KickoffColors.yellow,
                size: 20 * scale,
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TournamentSizes.BODY * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      TournamentStrings.playersCount(
                        team.players,
                        tournament.teamSize,
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
              if (status != null) ...[
                SizedBox(width: 8 * scale),
                _StatusPill(label: status.$1, color: status.$2),
              ],
            ],
          ),
          if (tournament.canRequestToJoin(team)) ...[
            SizedBox(height: 10 * scale),
            ChunkyButton(
              key: ValueKey('team_request_${team.id}'),
              label: TournamentStrings.REQUEST_TO_JOIN,
              icon: Icons.person_add_alt_1_rounded,
              busy: busy,
              onPressed: busy ? null : onRequest,
            ),
          ],
          SizedBox(height: 6 * scale),
          TextButton.icon(
            key: ValueKey('team_view_${team.id}'),
            style: TextButton.styleFrom(
              foregroundColor: KickoffColors.yellow,
              minimumSize: Size.fromHeight(TournamentSizes.MIN_TAP * scale),
              textStyle: TextStyle(
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onViewTeam,
            icon: Icon(Icons.groups_rounded, size: 20 * scale),
            label: const Text(TournamentStrings.VIEW_TEAM),
          ),
        ],
      ),
    );
  }

  /// The label and dot colour describing the user's link to this team.
  (String, Color)? _status() {
    if (team.id == tournament.myTeamId) {
      return (TournamentStrings.YOUR_TEAM, TournamentColors.SUCCESS);
    }
    if (tournament.hasTeam) return null;
    // Checked before registration status: requests expire once it closes.
    switch (tournament.requestFor(team.id)?.status) {
      case JoinRequestStatus.pending:
        return (TournamentStrings.REQUEST_PENDING, TournamentColors.UPCOMING);
      case JoinRequestStatus.declined:
        return (TournamentStrings.REQUEST_DECLINED, TournamentColors.FINISHED);
      case JoinRequestStatus.expired:
        return (TournamentStrings.REQUEST_EXPIRED, TournamentColors.FINISHED);
      case JoinRequestStatus.removed:
        return (TournamentStrings.REQUEST_REMOVED, TournamentColors.ERROR);
      case JoinRequestStatus.accepted:
      case JoinRequestStatus.cancelled:
      case null:
        break;
    }
    if (tournament.isOpen && tournament.isTeamFull(team)) {
      return (TournamentStrings.TEAM_FULL, TournamentColors.ERROR);
    }
    return null;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: KickoffColors.ink,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * scale,
            height: 8 * scale,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: TournamentSizes.CAPTION * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
