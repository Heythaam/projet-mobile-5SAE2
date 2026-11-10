import 'package:flutter/material.dart';

import '../../services/awards/local_awards.dart';
import '../../entities/user/models.dart';
import '../../items/kickoff_style.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: _content(context),
  );

  Widget _content(BuildContext context) => ArcadeBackdrop(
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: KickoffColors.muted,
                ),
              ),
            ),
            const Spacer(),
            Icon(icon, color: KickoffColors.yellow, size: 56),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon',
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({
    required this.profile,
    this.localAwards = const [],
    super.key,
  });

  final GamificationProfile? profile;

  /// Awards worked out from the matches on this phone; they work offline.
  final List<LocalAward> localAwards;

  // Without a Material ancestor the text gets the yellow underline.
  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: _content(context));

  Widget _content(BuildContext context) {
    final achievements = profile?.achievements ?? const <Achievement>[];
    final unlocked = localAwards.where((a) => a.unlocked).length;
    return ArcadeBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: KickoffColors.muted,
                    ),
                  ),
                  const Text(
                    'Awards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (localAwards.isNotEmpty)
                    Text(
                      '$unlocked / ${localAwards.length}',
                      key: const ValueKey('awards_count'),
                      style: const TextStyle(
                        color: KickoffColors.yellow,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: localAwards.isEmpty && achievements.isEmpty
                  ? const Center(
                      child: Text(
                        'Awards unavailable',
                        style: TextStyle(
                          color: KickoffColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final award in localAwards)
                          _AwardTile(
                            key: ValueKey('award_${award.id}'),
                            icon: award.icon,
                            title: award.title,
                            description: award.description,
                            unlocked: award.unlocked,
                            fraction: award.fraction,
                            trailing: award.unlocked
                                ? 'Done'
                                : '${award.progress}/${award.target}',
                          ),
                        if (achievements.isNotEmpty && localAwards.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Text(
                              'Career',
                              style: TextStyle(
                                color: KickoffColors.yellow,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        for (final achievement in achievements)
                          _AwardTile(
                            icon: achievement.unlocked
                                ? Icons.workspace_premium_rounded
                                : Icons.lock_outline_rounded,
                            title: achievement.title,
                            description: achievement.description,
                            unlocked: achievement.unlocked,
                            trailing: '+${achievement.rewardXp}',
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.trailing,
    this.fraction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final String trailing;

  /// Progress bar value, or null for no bar.
  final double? fraction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: unlocked ? KickoffColors.yellow : KickoffColors.muted,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (fraction != null && !unlocked) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      color: KickoffColors.yellow,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              color: unlocked ? KickoffColors.yellow : KickoffColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
