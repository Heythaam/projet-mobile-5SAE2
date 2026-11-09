import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import 'match_create_screens.dart';
import 'match_join_screen.dart';
import 'match_lobby_screen.dart';
import 'match_mock_data.dart';

class MatchHomeScreen extends StatefulWidget {
  const MatchHomeScreen({required this.controller, super.key});

  final MatchDemoController controller;

  @override
  State<MatchHomeScreen> createState() => _MatchHomeScreenState();
}

class _MatchHomeScreenState extends State<MatchHomeScreen> {
  bool _routeOpening = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      backgroundColor: KickoffColors.bg,
      body: ArcadeBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _topBar(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: 'Create',
                      icon: Icons.add_rounded,
                      largeCard: true,
                      onPressed: _routeOpening
                          ? null
                          : () => _startCreateFlow(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Join',
                      icon: Icons.vpn_key_rounded,
                      backgroundColor: KickoffColors.blue,
                      bottomColor: KickoffColors.blueDark,
                      foregroundColor: Colors.white,
                      largeCard: true,
                      onPressed: _routeOpening
                          ? null
                          : () => _openJoin(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _nextMatchCard(context, widget.controller.upcomingMatch),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topBar(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: KickoffColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KickoffColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: KickoffColors.ink, width: 2),
            ),
            child: Text(
              MatchDemoController.usernameInitial,
              style: const TextStyle(
                color: KickoffColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const StatChip(label: 'Lv ${MatchDemoController.level}'),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatChip(
            icon: Icons.local_fire_department_rounded,
            iconColor: KickoffColors.orange,
            label: '${MatchDemoController.streak}',
          ),
          const SizedBox(width: 4),
          const StatChip(
            icon: Icons.bolt_rounded,
            iconColor: KickoffColors.yellow,
            label: '${MatchDemoController.energy}',
          ),
        ],
      ),
    ],
  );

  Widget _nextMatchCard(BuildContext context, MatchHomeMatch? match) {
    if (match == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No match yet — create one or join with a code',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: KickoffColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Material(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _routeOpening ? null : () => _openLobby(context, match),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: KickoffColors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_weekday(match.scheduledAt.weekday)} '
                      '${_time(match.scheduledAt)}',
                      style: const TextStyle(
                        color: KickoffColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    match.isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    color: KickoffColors.muted,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    color: KickoffColors.yellow,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      match.stadium,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SlotDots(joined: match.players, total: match.capacity),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekday(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  static String _time(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _startCreateFlow(BuildContext context) async {
    if (_routeOpening) return;
    setState(() => _routeOpening = true);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StadiumPickScreen(controller: widget.controller),
      ),
    );
    if (!context.mounted) return;
    setState(() => _routeOpening = false);
    if (created == true) {
      final match = widget.controller.upcomingMatch;
      if (match != null) _openLobby(context, match);
    }
  }

  Future<void> _openJoin(BuildContext context) async {
    if (_routeOpening) return;
    setState(() => _routeOpening = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchJoinScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() => _routeOpening = false);
  }

  Future<void> _openLobby(BuildContext context, MatchHomeMatch match) async {
    if (_routeOpening) return;
    setState(() => _routeOpening = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MatchLobbyScreen(match: match)),
    );
    if (mounted) setState(() => _routeOpening = false);
  }
}
