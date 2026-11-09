import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/kickoff_style.dart';
import '../models/challenge_model.dart';
import 'star_rating.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    required this.challenge,
    this.onJoin,
    this.onCopyCode,
    super.key,
  });

  final Challenge challenge;
  final VoidCallback? onJoin;
  final VoidCallback? onCopyCode;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final date = challenge.dateTime.toLocal();
    final dateStr =
        '${_weekday(date.weekday)} ${_month(date.month)} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final progress = (challenge.currentPlayers / challenge.maxPlayers)
        .clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border(
          bottom: BorderSide(
            color: KickoffColors.panelDark,
            width: 4 * scale,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type badge, Team name, and Join Code
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 4 * scale,
                ),
                decoration: BoxDecoration(
                  color: challenge.isTeamChallenge
                      ? KickoffColors.blue
                      : KickoffColors.orange,
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      challenge.isTeamChallenge
                          ? Icons.groups_rounded
                          : Icons.public_rounded,
                      size: 14 * scale,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      challenge.isTeamChallenge
                          ? (challenge.teamName ?? 'Team Challenge')
                          : 'Open Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Join Code Chip
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: challenge.joinCode));
                  if (onCopyCode != null) {
                    onCopyCode!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code ${challenge.joinCode} copied!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(8 * scale),
                    border: Border.all(
                      color: KickoffColors.dim.withValues(alpha: 0.5),
                      width: 1 * scale,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        challenge.joinCode,
                        style: TextStyle(
                          color: KickoffColors.yellow,
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1 * scale,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      Icon(
                        Icons.copy_rounded,
                        size: 12 * scale,
                        color: KickoffColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),

          // Title / Description
          Text(
            challenge.description,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8 * scale),

          // Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16 * scale,
                color: KickoffColors.yellow,
              ),
              SizedBox(width: 6 * scale),
              Text(
                dateStr,
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),

          // Location
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 16 * scale,
                color: KickoffColors.yellow,
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: Text(
                  challenge.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),

          // Difficulty rating & Player Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Difficulty: ',
                    style: TextStyle(
                      color: KickoffColors.dim,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  StarRating(rating: challenge.difficulty, size: 14),
                ],
              ),
              SlotDots(
                joined: challenge.currentPlayers,
                total: challenge.maxPlayers,
              ),
            ],
          ),
          SizedBox(height: 8 * scale),

          // Player progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4 * scale),
            child: SizedBox(
              height: 6 * scale,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: KickoffColors.bg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  challenge.isFull ? KickoffColors.red : KickoffColors.yellow,
                ),
              ),
            ),
          ),
          SizedBox(height: 10 * scale),

          // Join button / Joined status badge
          if (challenge.isCreatedByMe)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6 * scale),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KickoffColors.blueDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 16 * scale,
                    color: KickoffColors.yellow,
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    'Created by You',
                    style: TextStyle(
                      color: KickoffColors.yellow,
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (challenge.isJoined)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6 * scale),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KickoffColors.field,
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16 * scale,
                    color: KickoffColors.yellow,
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    'Joined',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (challenge.isFull)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6 * scale),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KickoffColors.redDark.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(
                'Challenge Full',
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (onJoin != null)
            SizedBox(
              width: double.infinity,
              height: 40 * scale,
              child: ChunkyButton(
                label: 'Join Challenge',
                icon: Icons.add_circle_outline_rounded,
                onPressed: onJoin,
                backgroundColor: KickoffColors.yellow,
                bottomColor: KickoffColors.yellowDark,
                foregroundColor: KickoffColors.ink,
              ),
            ),
        ],
      ),
    );
  }

  String _weekday(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

  String _month(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m - 1];
}
