import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../daylight/daylight_service.dart';
import '../../travel/travel_service.dart';
import '../../screens/kickoff_style.dart';
import '../models/challenge_model.dart';
import 'star_rating.dart';

final _daylight = DaylightService();
final _travel = TravelService();

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    required this.challenge,
    this.onJoin,
    this.onLeave,
    this.onEdit,
    this.onDelete,
    this.onCopyCode,
    super.key,
  });

  final Challenge challenge;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyCode;

  Future<void> _share(BuildContext context) async {
    final text =
        'Join my football challenge at ${challenge.locationName}! '
        'Open Kickoff and enter code ${challenge.joinCode}.';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } on Object {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite copied')),
      );
    }
  }

  void _showDetailBottomSheet(BuildContext context) {
    final scale = kickoffScale(context);
    final date = challenge.dateTime.toLocal();
    final dateStr =
        '${_weekday(date.weekday)} ${_month(date.month)} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24 * scale)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 24 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    color: KickoffColors.muted,
                    borderRadius: BorderRadius.circular(2 * scale),
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),

              // Title & Join Code
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.description,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                    decoration: BoxDecoration(
                      color: KickoffColors.field,
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      challenge.joinCode,
                      style: TextStyle(
                        color: KickoffColors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 14 * scale,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12 * scale),

              // Chips for Format, Pitch, Skill, Duration
              Wrap(
                spacing: 8 * scale,
                runSpacing: 8 * scale,
                children: [
                  _DetailTag(icon: Icons.sports_soccer_rounded, label: challenge.gameFormat),
                  _DetailTag(icon: Icons.grass_rounded, label: challenge.pitchType),
                  _DetailTag(icon: Icons.star_rounded, label: challenge.skillLevel),
                  _DetailTag(icon: Icons.timer_rounded, label: '${challenge.durationMinutes} min'),
                ],
              ),
              SizedBox(height: 16 * scale),

              // Location & Date
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: KickoffColors.yellow, size: 20 * scale),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      challenge.locationName,
                      style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
              if (challenge.status == ChallengeStatus.active) ...[
                DaylightRow(
                  service: _daylight,
                  start: date,
                  minutes: challenge.durationMinutes,
                ),
                SizedBox(height: 8 * scale),
                TravelRow(service: _travel, place: challenge.locationName),
                SizedBox(height: 8 * scale),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('share_challenge'),
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_rounded, color: KickoffColors.yellow),
                  label: const Text(
                    'Share challenge',
                    style: TextStyle(color: KickoffColors.yellow),
                  ),
                ),
              ),

              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: KickoffColors.yellow, size: 20 * scale),
                  SizedBox(width: 6 * scale),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                  ),
                ],
              ),
              SizedBox(height: 12 * scale),

              // Difficulty & SlotDots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Difficulty: ',
                          style: TextStyle(color: KickoffColors.muted, fontSize: 13 * scale)),
                      StarRating(rating: challenge.difficulty, size: 16),
                    ],
                  ),
                  SlotDots(joined: challenge.currentPlayers, total: challenge.maxPlayers),
                ],
              ),

              if (challenge.rulesNotes != null && challenge.rulesNotes!.isNotEmpty) ...[
                SizedBox(height: 16 * scale),
                Text(
                  'Special Rules / Notes:',
                  style: TextStyle(
                    color: KickoffColors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 13 * scale,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Container(
                  padding: EdgeInsets.all(10 * scale),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(10 * scale),
                  ),
                  child: Text(
                    challenge.rulesNotes!,
                    style: TextStyle(color: Colors.white, fontSize: 13 * scale),
                  ),
                ),
              ],

              SizedBox(height: 20 * scale),

              // Actions inside Sheet
              if (challenge.isCreatedByMe) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChunkyButton(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        backgroundColor: KickoffColors.blue,
                        bottomColor: KickoffColors.blueDark,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit?.call();
                        },
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      child: ChunkyButton(
                        label: 'Delete',
                        icon: Icons.delete_rounded,
                        backgroundColor: KickoffColors.red,
                        bottomColor: KickoffColors.redDark,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDelete?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ] else if (challenge.isJoined) ...[
                ChunkyButton(
                  label: 'Quit Challenge',
                  icon: Icons.exit_to_app_rounded,
                  backgroundColor: KickoffColors.red,
                  bottomColor: KickoffColors.redDark,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLeave?.call();
                  },
                ),
              ] else if (onJoin != null && !challenge.isFull) ...[
                ChunkyButton(
                  label: 'Join Challenge',
                  icon: Icons.add_circle_outline_rounded,
                  backgroundColor: KickoffColors.yellow,
                  bottomColor: KickoffColors.yellowDark,
                  foregroundColor: KickoffColors.ink,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onJoin?.call();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final date = challenge.dateTime.toLocal();
    final dateStr =
        '${_weekday(date.weekday)} ${_month(date.month)} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final progress = (challenge.currentPlayers / challenge.maxPlayers).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _showDetailBottomSheet(context),
      child: Container(
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
            // Header: Type badge, Team name, and Action buttons / Join Code
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
                SizedBox(width: 6 * scale),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(6 * scale),
                  ),
                  child: Text(
                    challenge.gameFormat,
                    style: TextStyle(
                      color: KickoffColors.yellow,
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.bold,
                    ),
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

            // Actions row on Card
            if (challenge.isCreatedByMe)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_rounded, size: 16 * scale, color: KickoffColors.yellow),
                      label: Text('Edit', style: TextStyle(color: KickoffColors.yellow, fontSize: 13 * scale)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: KickoffColors.yellow),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * scale)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_rounded, size: 16 * scale, color: KickoffColors.red),
                      label: Text('Delete', style: TextStyle(color: KickoffColors.red, fontSize: 13 * scale)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: KickoffColors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * scale)),
                      ),
                    ),
                  ),
                ],
              )
            else if (challenge.isJoined)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLeave,
                  icon: Icon(Icons.exit_to_app_rounded, size: 16 * scale, color: KickoffColors.red),
                  label: Text('Quit Challenge', style: TextStyle(color: KickoffColors.red, fontSize: 13 * scale)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: KickoffColors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * scale)),
                  ),
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

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: KickoffColors.yellow),
          SizedBox(width: 4 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
