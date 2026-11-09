import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../tournament_constants.dart';
import 'requests_badge.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({
    required this.tournament,
    required this.onTap,
    this.onJoin,
    super.key,
  });

  final Tournament tournament;
  final VoidCallback onTap;

  /// Shown as "Join now" when the tournament accepts the user; otherwise the
  /// card offers "View details".
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final dimmed =
        tournament.status == TournamentStatus.cancelled ||
        tournament.status == TournamentStatus.finished;
    final textColor = dimmed ? KickoffColors.muted : Colors.white;
    final metaColor = dimmed ? KickoffColors.dim : KickoffColors.muted;
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    final onJoin = this.onJoin;
    final showJoin = onJoin != null && tournament.canJoin;
    final metaStyle = TextStyle(
      color: metaColor,
      fontSize: TournamentSizes.CAPTION * scale,
      fontWeight: FontWeight.w500,
    );
    return Material(
      color: dimmed ? KickoffColors.panel : KickoffColors.blue,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border(
              bottom: BorderSide(
                color: dimmed
                    ? KickoffColors.panelDark
                    : KickoffColors.blueDark,
                width: 4 * scale,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: dimmed ? KickoffColors.muted : KickoffColors.yellow,
                    size: 24 * scale,
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Text(
                      tournament.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: TournamentSizes.CARD_TITLE * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
              _MetaLine(
                icon: Icons.calendar_month_rounded,
                color: metaColor,
                child: Text(
                  '${TournamentStrings.dateRange(tournament.startDate, tournament.endDate)}'
                  ' · ${tournament.format.label}',
                  style: metaStyle,
                ),
              ),
              SizedBox(height: 6 * scale),
              _MetaLine(
                icon: Icons.groups_rounded,
                color: metaColor,
                child: Wrap(
                  spacing: 8 * scale,
                  runSpacing: 4 * scale,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      TournamentStrings.teamsCount(
                        tournament.currentTeams,
                        tournament.maxTeams,
                      ),
                      style: metaStyle,
                    ),
                    StatusBadge.forTournament(tournament),
                    if (tournament.canManageRequests &&
                        tournament.pendingRequests > 0)
                      RequestsBadge(count: tournament.pendingRequests),
                  ],
                ),
              ),
              SizedBox(height: 12 * scale),
              Align(
                alignment: Alignment.centerRight,
                child: _CardAction(
                  label: tournament.joined
                      ? TournamentStrings.JOINED
                      : showJoin
                      ? TournamentStrings.JOIN_NOW
                      : TournamentStrings.VIEW_DETAILS,
                  icon: tournament.joined
                      ? Icons.check_rounded
                      : showJoin
                      ? Icons.add_rounded
                      : Icons.chevron_right_rounded,
                  primary: showJoin,
                  onPressed: showJoin ? onJoin : onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 16 * scale),
        SizedBox(width: 6 * scale),
        Expanded(child: child),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    final foreground = primary ? KickoffColors.ink : Colors.white;
    return Material(
      color: primary ? KickoffColors.yellow : KickoffColors.ink,
      borderRadius: radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(
            minHeight: TournamentSizes.MIN_TAP * scale,
            minWidth: TournamentSizes.MIN_TAP * scale,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border(
              bottom: BorderSide(
                color: primary
                    ? KickoffColors.yellowDark
                    : KickoffColors.panelDark,
                width: 3 * scale,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4 * scale),
              Icon(icon, color: foreground, size: 18 * scale),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill with a coloured dot: active green, upcoming blue, finished grey,
/// full or cancelled red (agents/ux-designer.md status indicators).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, this.full = false, super.key});

  StatusBadge.forTournament(Tournament tournament, {super.key})
    : status = tournament.status,
      full = tournament.isOpen && tournament.isFull;

  final TournamentStatus status;

  /// Only meaningful while registration is open.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final (label, dotColor) = full
        ? (TournamentStrings.STATUS_FULL, TournamentColors.ERROR)
        : switch (status) {
            TournamentStatus.active => (status.label, TournamentColors.SUCCESS),
            TournamentStatus.upcoming => (
              status.label,
              TournamentColors.UPCOMING,
            ),
            TournamentStatus.finished => (
              status.label,
              TournamentColors.FINISHED,
            ),
            TournamentStatus.cancelled => (
              status.label,
              TournamentColors.ERROR,
            ),
          };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: KickoffColors.ink,
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * scale,
            height: 8 * scale,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
