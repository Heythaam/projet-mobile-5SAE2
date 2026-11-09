import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../tournament_constants.dart';

/// Tells a former player that their captain disbanded the team. Tapping it
/// anywhere dismisses it.
class TeamDisbandedBanner extends StatelessWidget {
  const TeamDisbandedBanner({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Semantics(
      button: true,
      liveRegion: true,
      label:
          '${TournamentStrings.TEAM_DISBANDED_NOTICE}. '
          '${TournamentStrings.TEAM_DISBANDED_HINT}',
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('tournament_disbanded_notice'),
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
                  Icons.group_off_rounded,
                  color: TournamentColors.ERROR_TEXT,
                  size: 24 * scale,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TournamentStrings.TEAM_DISBANDED_NOTICE,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TournamentSizes.BODY * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        TournamentStrings.TEAM_DISBANDED_HINT,
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
