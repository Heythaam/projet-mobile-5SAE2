import 'package:flutter/material.dart';

import '../models.dart';
import 'kickoff_style.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.user,
    required this.profile,
    required this.onHistory,
    required this.onAwards,
    required this.onFriends,
    required this.onSettings,
    super.key,
  });

  final UserAccount user;
  final GamificationProfile? profile;
  final VoidCallback onHistory;
  final VoidCallback onAwards;
  final VoidCallback onFriends;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return ArcadeBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 * scale, 10 * scale, 12 * scale, 0),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(bottom: 16 * scale),
                sliver: SliverList.list(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: 'Settings',
                        onPressed: onSettings,
                        iconSize: 24 * scale,
                        constraints: BoxConstraints(
                          minWidth: 56 * scale,
                          minHeight: 56 * scale,
                        ),
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: KickoffColors.muted,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          key: const ValueKey('profile_avatar'),
                          width: 96 * scale,
                          height: 96 * scale,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: KickoffColors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: KickoffColors.blue,
                              width: 4 * scale,
                            ),
                          ),
                          child: Text(
                            user.username.isEmpty
                                ? '?'
                                : user.username[0].toUpperCase(),
                            style: TextStyle(
                              color: KickoffColors.ink,
                              fontSize: 34 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Container(
                          constraints: BoxConstraints(minHeight: 36 * scale),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * scale,
                            vertical: 4 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: KickoffColors.panel,
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: Text(
                            profile == null
                                ? 'Lv — · —'
                                : 'Lv ${profile!.level} · ${profile!.rank}',
                            style: TextStyle(
                              color: KickoffColors.yellow,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * scale),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(
                            icon: Icons.sports_soccer_rounded,
                            label: 'Matches',
                            value: '—',
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: _ProfileStat(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Streak',
                            value: profile?.currentStreak.toString() ?? '—',
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: _ProfileStat(
                            icon: Icons.bolt_rounded,
                            label: 'XP',
                            value: profile?.xp.toString() ?? '—',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16 * scale),
                    _ProfileRow(
                      icon: Icons.history_rounded,
                      title: 'History',
                      onTap: onHistory,
                    ),
                    SizedBox(height: 8 * scale),
                    _ProfileRow(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Awards',
                      onTap: onAwards,
                    ),
                    SizedBox(height: 8 * scale),
                    _ProfileRow(
                      icon: Icons.groups_rounded,
                      title: 'Friends',
                      onTap: onFriends,
                    ),
                    SizedBox(height: 8 * scale),
                    _ProfileRow(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      onTap: onSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Tooltip(
      message: label,
      child: Container(
        constraints: BoxConstraints(minHeight: 88 * scale),
        padding: EdgeInsets.symmetric(
          horizontal: 7 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: KickoffColors.yellow, size: 20 * scale),
            SizedBox(width: 6 * scale),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Material(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(14 * scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * scale),
        child: Container(
          constraints: BoxConstraints(minHeight: 64 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 12 * scale,
          ),
          child: Row(
            children: [
              Icon(icon, color: KickoffColors.yellow, size: 22 * scale),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: KickoffColors.dim,
                size: 20 * scale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
