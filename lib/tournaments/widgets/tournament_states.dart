import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../tournament_constants.dart';

/// Back button, screen title and an optional trailing action.
class TournamentHeader extends StatelessWidget {
  const TournamentHeader({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final action = this.action;
    return Padding(
      padding: EdgeInsets.fromLTRB(4 * scale, 4 * scale, 8 * scale, 4 * scale),
      child: Row(
        children: [
          TournamentIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: TournamentStrings.BACK,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          SizedBox(width: 4 * scale),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: TournamentSizes.SCREEN_TITLE * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class TournamentIconButton extends StatelessWidget {
  const TournamentIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return IconButton(
      tooltip: tooltip,
      constraints: BoxConstraints(
        minWidth: TournamentSizes.MIN_TAP * scale,
        minHeight: TournamentSizes.MIN_TAP * scale,
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: KickoffColors.muted, size: 24 * scale),
    );
  }
}

class TournamentLoading extends StatelessWidget {
  const TournamentLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(
      strokeWidth: 4 * kickoffScale(context),
      color: KickoffColors.yellow,
    ),
  );
}

/// Placeholder cards shown while the tournament list loads.
class TournamentSkeletonList extends StatelessWidget {
  const TournamentSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height * scale,
        decoration: BoxDecoration(
          color: KickoffColors.field,
          borderRadius: BorderRadius.circular(6 * scale),
        ),
      ),
    );
    return Semantics(
      label: TournamentStrings.TITLE,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12 * scale, 4 * scale, 12 * scale, 0),
        itemCount: TournamentSizes.SKELETON_CARDS,
        separatorBuilder: (_, _) => SizedBox(height: 8 * scale),
        itemBuilder: (_, _) => Container(
          key: const ValueKey('tournament_skeleton'),
          padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
          decoration: BoxDecoration(
            color: KickoffColors.panel,
            borderRadius: BorderRadius.circular(
              TournamentSizes.CARD_RADIUS * scale,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(0.6, 16),
              SizedBox(height: 10 * scale),
              bar(0.8, 12),
              SizedBox(height: 8 * scale),
              bar(0.45, 12),
              SizedBox(height: 12 * scale),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 110 * scale, child: bar(1, 40)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentError extends StatelessWidget {
  const TournamentError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: KickoffColors.muted,
              size: 48 * scale,
            ),
            SizedBox(height: 12 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16 * scale),
            ChunkyButton(
              label: TournamentStrings.RETRY,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentEmpty extends StatelessWidget {
  const TournamentEmpty({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyIllustration(icon: icon),
            SizedBox(height: 16 * scale),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A flat pitch-circle illustration: the state's icon on a panel disc with a
/// ball resting at its edge.
class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final size = 120 * scale;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: KickoffColors.panel,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: KickoffColors.field,
                  width: 3 * scale,
                ),
              ),
            ),
            Icon(icon, color: KickoffColors.yellow, size: 52 * scale),
            Positioned(
              right: 4 * scale,
              bottom: 4 * scale,
              child: Container(
                padding: EdgeInsets.all(4 * scale),
                decoration: const BoxDecoration(
                  color: KickoffColors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sports_soccer_rounded,
                  color: Colors.white,
                  size: 24 * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
