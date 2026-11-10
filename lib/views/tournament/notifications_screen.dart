import 'package:flutter/material.dart';

import '../../items/kickoff_style.dart';
import '../../entities/tournament/tournament_notification.dart';
import '../../services/tournament/tournament_service.dart';
import '../../items/tournament/tournament_constants.dart';
import '../../items/tournament/tournament_states.dart';
import 'tournament_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.service, super.key});

  final TournamentService service;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<TournamentNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    setState(() {
      _isLoading = showLoading;
      _error = null;
    });
    try {
      final notifications = await widget.service.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } on TournamentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = TournamentStrings.ERROR_LOAD_NOTIFICATIONS;
        _isLoading = false;
      });
    }
  }

  Future<void> _onNotificationTap(TournamentNotification notification) async {
    if (!notification.isRead) {
      // Mark as read in backend
      try {
        await widget.service.markNotificationRead(notification.id);
      } catch (_) {}
      setState(() {
        _notifications = [
          for (final n in _notifications)
            if (n.id == notification.id)
              TournamentNotification(
                id: n.id,
                userId: n.userId,
                title: n.title,
                body: n.body,
                isRead: true,
                tournamentId: n.tournamentId,
                createdAt: n.createdAt,
              )
            else
              n,
        ];
      });
    }

    if (notification.tournamentId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TournamentDetailScreen(
            service: widget.service,
            tournamentId: notification.tournamentId!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const TournamentHeader(title: TournamentStrings.NOTIFICATIONS_TITLE),
            Expanded(child: _buildBody(scale)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double scale) {
    if (_isLoading) return const TournamentLoading();
    if (_error != null) {
      return TournamentError(
        message: _error!,
        onRetry: _loadNotifications,
      );
    }
    if (_notifications.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.notifications_none_rounded,
        title: TournamentStrings.NO_NOTIFICATIONS,
        message: TournamentStrings.NO_NOTIFICATIONS_HINT,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(showLoading: false),
      color: KickoffColors.ink,
      backgroundColor: KickoffColors.yellow,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 12 * scale,
        ),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => SizedBox(height: 8 * scale),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _NotificationTile(
            notification: notif,
            scale: scale,
            onTap: () => _onNotificationTap(notif),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.scale,
    required this.onTap,
  });

  final TournamentNotification notification;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale),
      child: Container(
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(
          color: isUnread ? KickoffColors.panel : KickoffColors.panelDark,
          borderRadius: BorderRadius.circular(
            TournamentSizes.CARD_RADIUS * scale,
          ),
          border: isUnread
              ? Border.all(color: KickoffColors.yellow.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                color: isUnread
                    ? KickoffColors.yellow.withValues(alpha: 0.2)
                    : KickoffColors.field,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: isUnread ? KickoffColors.yellow : KickoffColors.muted,
                size: 20 * scale,
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TournamentSizes.BODY * scale,
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8 * scale,
                          height: 8 * scale,
                          decoration: const BoxDecoration(
                            color: KickoffColors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: isUnread ? Colors.white70 : KickoffColors.muted,
                      fontSize: TournamentSizes.CAPTION * scale,
                    ),
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
