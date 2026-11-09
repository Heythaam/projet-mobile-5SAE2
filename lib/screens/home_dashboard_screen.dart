import 'package:flutter/material.dart';

import '../matches/football_match.dart';
import '../models.dart';
import 'kickoff_style.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({
    required this.user,
    required this.profile,
    required this.loading,
    required this.loadError,
    required this.nextMatch,
    required this.onRetry,
    required this.onOpenBallMenu,
    this.tournamentBanner,
    super.key,
  });

  final UserAccount user;
  final GamificationProfile? profile;
  final bool loading;
  final String? loadError;
  final FootballMatch? nextMatch;
  final VoidCallback onRetry;
  final VoidCallback onOpenBallMenu;

  /// Shortcut supplied by the tournaments module, e.g. pending join requests.
  final Widget? tournamentBanner;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return ArcadeBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 * scale, 10 * scale, 12 * scale, 0),
          child: RefreshIndicator(
            color: KickoffColors.yellow,
            backgroundColor: KickoffColors.panel,
            onRefresh: () async => onRetry(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList.list(
                  children: [
                    _TopStats(user: user, profile: profile),
                    if (tournamentBanner case final banner?) ...[
                      SizedBox(height: 10 * scale),
                      banner,
                    ],
                    if (loadError != null) ...[
                      SizedBox(height: 8 * scale),
                      _LoadError(message: loadError!, onRetry: onRetry),
                    ],
                    SizedBox(height: 16 * scale),
                    const _NextLabel(),
                    SizedBox(height: 7 * scale),
                    _NextMatchTicket(
                      match: nextMatch,
                      onCreate: onOpenBallMenu,
                    ),
                    SizedBox(height: 14 * scale),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressTile(
                            icon: Icons.bolt_rounded,
                            iconColor: KickoffColors.yellow,
                            value: profile == null
                                ? '—'
                                : '${profile!.xpIntoLevel} / ${profile!.xpForNextLevel}',
                            progress:
                                profile == null || profile!.xpForNextLevel <= 0
                                ? null
                                : profile!.xpIntoLevel /
                                      profile!.xpForNextLevel,
                          ),
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: _ProgressTile(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: KickoffColors.orange,
                            value: profile == null
                                ? '—'
                                : '${profile!.currentStreak} ${profile!.currentStreak == 1 ? 'day' : 'days'}',
                            progress:
                                profile == null || profile!.bestStreak <= 0
                                ? null
                                : profile!.currentStreak / profile!.bestStreak,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.user, required this.profile});

  final UserAccount user;
  final GamificationProfile? profile;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      children: [
        Container(
          width: 30 * scale,
          height: 30 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KickoffColors.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: KickoffColors.ink, width: 2 * scale),
          ),
          child: Text(
            user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
            style: TextStyle(
              color: KickoffColors.ink,
              fontSize: 13 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 6 * scale),
        StatChip(
          icon: Icons.shield_rounded,
          label: 'Lv ${profile?.level ?? '—'}',
        ),
        const Spacer(),
        StatChip(
          icon: Icons.local_fire_department_rounded,
          label: profile?.currentStreak.toString() ?? '—',
          iconColor: KickoffColors.orange,
        ),
        SizedBox(width: 5 * scale),
        StatChip(
          icon: Icons.bolt_rounded,
          label: profile?.xp.toString() ?? '—',
          iconColor: KickoffColors.yellow,
        ),
      ],
    );
  }
}

class _NextLabel extends StatelessWidget {
  const _NextLabel();

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Text(
      'NEXT',
      style: TextStyle(
        color: KickoffColors.dim,
        fontSize: 12 * scale,
        letterSpacing: 2 * scale,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _NextMatchTicket extends StatelessWidget {
  const _NextMatchTicket({required this.match, required this.onCreate});

  final FootballMatch? match;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final date = match?.scheduledAt.toLocal();
    final weekday = date == null ? '' : _weekday(date.weekday);
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Container(
      constraints: BoxConstraints(minHeight: 200 * scale),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.blue,
        borderRadius: BorderRadius.all(Radius.circular(18 * scale)),
        border: Border(
          bottom: BorderSide(color: KickoffColors.blueDark, width: 5 * scale),
        ),
      ),
      child: match == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 56 * scale,
                  color: KickoffColors.yellow,
                ),
                SizedBox(height: 12 * scale),
                SizedBox(
                  width: double.infinity,
                  child: ChunkyButton(
                    label: 'Create',
                    icon: Icons.add_rounded,
                    onPressed: onCreate,
                    showIcon: false,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16 * scale,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      '$weekday $time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      match!.isPublic
                          ? Icons.public_rounded
                          : Icons.lock_rounded,
                      color: Colors.white,
                      size: 20 * scale,
                    ),
                  ],
                ),
                SizedBox(height: 10 * scale),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 22 * scale,
                      color: KickoffColors.yellow,
                    ),
                    SizedBox(width: 3 * scale),
                    Expanded(
                      child: Text(
                        match!.stadium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8 * scale),
                SlotDots(joined: match!.joinedSlots, total: match!.totalSlots),
              ],
            ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.progress,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      constraints: BoxConstraints(minHeight: 110 * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24 * scale),
          SizedBox(height: 6 * scale),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(3 * scale),
            child: SizedBox(
              height: 6 * scale,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: KickoffColors.bg),
                    ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth * progress!.clamp(0.0, 1.0),
                        child: ColoredBox(color: iconColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message,
          style: TextStyle(
            color: KickoffColors.muted,
            fontSize: 13 * kickoffScale(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      RoundIconButton(
        icon: Icons.refresh_rounded,
        label: 'Retry',
        onPressed: onRetry,
      ),
    ],
  );
}

String _weekday(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
