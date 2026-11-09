import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({required this.service, super.key});

  final TournamentService service;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnread();
  }

  Future<void> _fetchUnread() async {
    try {
      final notifs = await widget.service.getNotifications();
      if (!mounted) return;
      final unread = notifs.where((n) => !n.isRead).length;
      setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(service: widget.service),
      ),
    );
    if (mounted) {
      _fetchUnread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: TournamentStrings.NOTIFICATIONS_TITLE,
          constraints: BoxConstraints(
            minWidth: TournamentSizes.MIN_TAP * scale,
            minHeight: TournamentSizes.MIN_TAP * scale,
          ),
          icon: Icon(
            Icons.notifications_rounded,
            color: _unreadCount > 0 ? KickoffColors.yellow : KickoffColors.muted,
            size: 24 * scale,
          ),
          onPressed: _openNotifications,
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 8 * scale,
            right: 8 * scale,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 4 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: KickoffColors.red,
                  shape: _unreadCount < 10 ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius:
                      _unreadCount >= 10 ? BorderRadius.circular(8 * scale) : null,
                ),
                constraints: BoxConstraints(
                  minWidth: 16 * scale,
                  minHeight: 16 * scale,
                ),
                alignment: Alignment.center,
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
