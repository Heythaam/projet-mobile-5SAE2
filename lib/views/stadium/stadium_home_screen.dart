import 'package:flutter/material.dart';

import '../../entities/stadium/stadium.dart';
import '../../items/kickoff_style.dart';
import '../../items/stadium/stadium_widgets.dart';
import '../../services/stadium/stadium_api.dart';
import 'bookings_inbox_screen.dart';
import 'stadium_detail_screen.dart';
import 'stadium_editor_screen.dart';

class StadiumHomeScreen extends StatefulWidget {
  const StadiumHomeScreen({required this.api, super.key});

  final StadiumApi api;

  @override
  State<StadiumHomeScreen> createState() => _StadiumHomeScreenState();
}

class _StadiumHomeScreenState extends State<StadiumHomeScreen> {
  StadiumOverview? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _overview == null;
      _error = null;
    });
    try {
      final overview = await widget.api.overview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = stadiumMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<Stadium>(
      MaterialPageRoute(builder: (_) => StadiumEditorScreen(api: widget.api)),
    );
    if (created == null || !mounted) return;
    stadiumToast(context, '${created.name} is live. Players can book it now.');
    await _load();
  }

  Future<void> _open(Stadium stadium) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StadiumDetailScreen(api: widget.api, stadium: stadium),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BookingsInboxScreen(api: widget.api)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final overview = _overview;
    return StadiumPage(
      title: 'My stadiums',
      icon: Icons.stadium_rounded,
      actions: [
        StadiumBadgeButton(
          icon: Icons.event_note_rounded,
          label: 'Bookings',
          count: overview?.pendingBookings ?? 0,
          onPressed: _openInbox,
        ),
      ],
      bottom: overview == null
          ? null
          : ChunkyButton(
              key: const ValueKey('stadium_add'),
              label: 'Add stadium',
              icon: Icons.add_rounded,
              onPressed: _add,
            ),
      child: _loading
          ? const StadiumLoading()
          : overview == null
          ? StadiumStatusView(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load your stadiums",
              message: _error ?? '',
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: KickoffColors.ink,
              backgroundColor: KickoffColors.yellow,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  4 * scale,
                  16 * scale,
                  16 * scale,
                ),
                children: [
                  if (_error != null) ...[
                    StadiumBanner(icon: Icons.wifi_off_rounded, text: _error!),
                    SizedBox(height: 10 * scale),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: StadiumStatTile(
                          icon: Icons.event_available_rounded,
                          value: '${overview.todayBookings}',
                          label: 'today',
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: StadiumStatTile(
                          icon: Icons.payments_rounded,
                          value: '${overview.weekIncome}',
                          label: 'this week',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  if (overview.stadiums.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 24 * scale),
                      child: const StadiumStatusView(
                        icon: Icons.stadium_rounded,
                        title: 'No stadiums yet',
                        message:
                            'Add your stadium, its pitches and opening hours. '
                            'Players will be able to book your free slots.',
                        compact: true,
                      ),
                    )
                  else
                    for (final summary in overview.stadiums) ...[
                      _StadiumCard(
                        summary: summary,
                        onTap: () => _open(summary.stadium),
                      ),
                      SizedBox(height: 10 * scale),
                    ],
                ],
              ),
            ),
    );
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.summary, required this.onTap});

  final StadiumSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final stadium = summary.stadium;
    final paused = stadium.paused;
    final muted = paused ? KickoffColors.muted : Colors.white;
    return StadiumChunkyTile(
      color: paused ? KickoffColors.panel : KickoffColors.blue,
      edge: paused ? KickoffColors.panelDark : KickoffColors.blueDark,
      onTap: onTap,
      semanticLabel: '${stadium.name}${paused ? ', paused' : ''}',
      padding: EdgeInsets.all(10 * scale),
      child: Row(
        children: [
          StadiumIconSquare(
            icon: paused ? Icons.pause_rounded : Icons.stadium_rounded,
            color: paused ? KickoffColors.field : StadiumColors.green,
            foreground: paused ? KickoffColors.muted : Colors.white,
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stadium.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: stadiumText(
                    scale,
                    17,
                    color: muted,
                    weight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Wrap(
                  spacing: 12 * scale,
                  runSpacing: 2 * scale,
                  children: [
                    StadiumIconText(
                      icon: Icons.grid_view_rounded,
                      text: '${stadium.pitches.length}',
                      color: paused ? KickoffColors.dim : KickoffColors.yellow,
                      textColor: muted,
                    ),
                    if (paused)
                      StadiumIconText(
                        icon: Icons.lock_rounded,
                        text: 'Paused',
                        color: KickoffColors.yellow,
                        textColor: muted,
                      )
                    else
                      StadiumIconText(
                        icon: Icons.event_available_rounded,
                        text: summary.todaySlots == 0
                            ? 'Closed today'
                            : '${summary.todayBooked}/${summary.todaySlots}',
                        color: KickoffColors.yellow,
                        textColor: muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: paused ? KickoffColors.dim : Colors.white,
            size: 24 * scale,
          ),
        ],
      ),
    );
  }
}
