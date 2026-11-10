import 'package:flutter/material.dart';

import '../../bd/user_local_store.dart';
import '../../entities/user/models.dart';
import '../../items/user/avatar_palette.dart';
import '../../services/user/country_service.dart';
import '../../items/user/user_avatar.dart';
import '../../items/kickoff_style.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.user,
    required this.profile,
    required this.onHistory,
    required this.onAwards,
    required this.onFriends,
    required this.onSettings,
    this.onStadiums,
    this.localProfile,
    this.onEditProfile,
    this.matchesPlayed,
    this.matchesHosted,
    this.countries,
    super.key,
  });

  /// Looks up the country name for the flag line. Null shows the code only.
  final CountryService? countries;

  /// Counted from the matches on this phone. Null shows a dash.
  final int? matchesPlayed;
  final int? matchesHosted;

  /// The profile saved on this phone. When set, its username, avatar colour,
  /// position and bio are shown instead of the account's.
  final LocalUser? localProfile;

  /// Opens the edit screen. Null hides the row, for example for guests.
  final VoidCallback? onEditProfile;

  final UserAccount user;
  final GamificationProfile? profile;
  final VoidCallback onHistory;
  final VoidCallback onAwards;
  final VoidCallback onFriends;
  final VoidCallback onSettings;
  final VoidCallback? onStadiums;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final name = localProfile?.username ?? user.username;
    final position = localProfile?.position;
    final bio = localProfile?.bio ?? '';
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
                            color: avatarColor(localProfile?.avatarId ?? 0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: KickoffColors.blue,
                              width: 4 * scale,
                            ),
                          ),
                          child: UserAvatarFace(
                            username: name,
                            avatarId: localProfile?.avatarId ?? 0,
                            size: 88 * scale,
                            photoPath: localProfile?.photoPath,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          '@$name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (localProfile?.country != null)
                          _CountryLine(
                            code: localProfile!.country!,
                            service: countries,
                          ),
                        if (position != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4 * scale),
                            child: Text(
                              position,
                              key: const ValueKey('profile_position'),
                              style: TextStyle(
                                color: KickoffColors.muted,
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (bio.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4 * scale),
                            child: Text(
                              bio,
                              key: const ValueKey('profile_bio'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: KickoffColors.muted,
                                fontSize: 13 * scale,
                              ),
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
                            value: matchesPlayed?.toString() ?? '—',
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
                    if (matchesHosted != null && matchesHosted! > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 6 * scale),
                        child: Text(
                          'You created $matchesHosted of them',
                          key: const ValueKey('profile_hosted'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: KickoffColors.muted,
                            fontSize: 12 * scale,
                          ),
                        ),
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
                    if (onStadiums != null) ...[
                      SizedBox(height: 8 * scale),
                      _ProfileRow(
                        icon: Icons.stadium_rounded,
                        title: 'My stadiums',
                        onTap: onStadiums!,
                      ),
                    ],
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

class _CountryLine extends StatelessWidget {
  const _CountryLine({required this.code, required this.service});

  final String code;
  final CountryService? service;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(top: 4 * scale),
      child: FutureBuilder<Country?>(
        future: service?.byCode(code),
        builder: (context, snapshot) => Text(
          '${flagEmoji(code)} ${snapshot.data?.name ?? code}',
          key: const ValueKey('profile_country'),
          style: TextStyle(color: KickoffColors.muted, fontSize: 13 * scale),
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
