import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../tournament_constants.dart';

/// Yellow pill telling a captain how many join requests are waiting.
class RequestsBadge extends StatelessWidget {
  const RequestsBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      key: const ValueKey('tournament_requests_badge'),
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.yellow,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, color: KickoffColors.ink, size: 14 * scale),
          SizedBox(width: 4 * scale),
          Text(
            TournamentStrings.pendingRequestsLabel(count),
            style: TextStyle(
              color: KickoffColors.ink,
              fontSize: TournamentSizes.CAPTION * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home-screen card for captains with join requests waiting.
class PendingRequestsBanner extends StatelessWidget {
  const PendingRequestsBanner({
    required this.count,
    required this.onOpen,
    super.key,
  });

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Semantics(
      button: true,
      label: TournamentStrings.homeRequestsTitle(count),
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('home_join_requests'),
          onTap: onOpen,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: TournamentSizes.MIN_TAP * scale,
            ),
            padding: EdgeInsets.all(12 * scale),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  color: KickoffColors.yellow,
                  size: 26 * scale,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TournamentStrings.homeRequestsTitle(count),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TournamentSizes.BODY * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        TournamentStrings.HOME_REQUESTS_HINT,
                        style: TextStyle(
                          color: KickoffColors.muted,
                          fontSize: TournamentSizes.CAPTION * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: KickoffColors.muted,
                  size: 24 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
