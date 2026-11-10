import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import 'tournament_constants.dart';

/// Tells a former player that the captain removed them from the team.
class TeamRemovedBanner extends StatelessWidget {
  const TeamRemovedBanner({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Semantics(
      button: true,
      liveRegion: true,
      label:
          '${TournamentStrings.TEAM_REMOVED_NOTICE}. '
          '${TournamentStrings.TEAM_REMOVED_HINT}',
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('tournament_removed_notice'),
          onTap: onDismiss,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: TournamentSizes.MIN_TAP * scale,
            ),
            padding: EdgeInsets.all(12 * scale),
            child: Row(
              children: [
                Icon(
                  Icons.person_remove_rounded,
                  color: TournamentColors.ERROR_TEXT,
                  size: 24 * scale,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TournamentStrings.TEAM_REMOVED_NOTICE,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TournamentSizes.BODY * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        TournamentStrings.TEAM_REMOVED_HINT,
                        style: TextStyle(
                          color: KickoffColors.muted,
                          fontSize: TournamentSizes.CAPTION * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8 * scale),
                Icon(
                  Icons.close_rounded,
                  color: KickoffColors.muted,
                  size: 20 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
