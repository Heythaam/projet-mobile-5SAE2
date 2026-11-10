import 'package:flutter/material.dart';

import '../../entities/stadium/stadium.dart';
import '../../items/kickoff_style.dart';
import '../../items/stadium/stadium_widgets.dart';
import '../../services/stadium/stadium_api.dart';

class BookingsInboxScreen extends StatefulWidget {
  const BookingsInboxScreen({required this.api, super.key});

  final StadiumApi api;

  @override
  State<BookingsInboxScreen> createState() => _BookingsInboxScreenState();
}

class _BookingsInboxScreenState extends State<BookingsInboxScreen> {
  BookingInbox? _inbox;
  String? _error;
  bool _loading = true;
  bool _savingAuto = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _inbox == null;
      _error = null;
    });
    try {
      final inbox = await widget.api.inbox();
      if (!mounted) return;
      setState(() {
        _inbox = inbox;
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

  Future<void> _setAuto(bool value) async {
    final inbox = _inbox;
    if (inbox == null || _savingAuto) return;
    setState(() {
      _savingAuto = true;
      _inbox = BookingInbox(
        autoConfirm: value,
        pending: inbox.pending,
        confirmed: inbox.confirmed,
      );
    });
    try {
      await widget.api.setAutoConfirm(value);
      if (mounted) {
        stadiumToast(
          context,
          value
              ? 'New bookings will be confirmed automatically.'
              : 'You’ll approve each new booking.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _inbox = inbox);
      stadiumToast(context, stadiumMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _savingAuto = false);
    }
  }

  Future<void> _decide(StadiumBooking booking, bool accept) async {
    setState(() => _busy.add(booking.id));
    try {
      await widget.api.decide(booking.id, accept: accept);
      await _load();
      if (mounted) {
        stadiumToast(context, accept ? 'Booking accepted.' : 'Booking declined.');
      }
    } catch (error) {
      if (mounted) stadiumToast(context, stadiumMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final inbox = _inbox;
    return StadiumPage(
      title: 'Bookings',
      icon: Icons.event_note_rounded,
      child: _loading
          ? const StadiumLoading()
          : inbox == null
          ? StadiumStatusView(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load bookings",
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
                  24 * scale,
                ),
                children: [
                  StadiumPanel(
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: KickoffColors.yellow,
                          size: 26 * scale,
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-confirm',
                                style: stadiumText(
                                  scale,
                                  16,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Accept new bookings without asking you',
                                style: stadiumText(
                                  scale,
                                  13,
                                  color: KickoffColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StadiumKickoffSwitch(
                          label: 'Auto-confirm',
                          value: inbox.autoConfirm,
                          onChanged: _setAuto,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  if (inbox.pending.isEmpty && inbox.confirmed.isEmpty)
                    const StadiumStatusView(
                      icon: Icons.inbox_rounded,
                      title: 'No bookings yet',
                      message:
                          'When players reserve one of your free slots, '
                          'the request shows up here.',
                      compact: true,
                    ),
                  if (inbox.pending.isNotEmpty) ...[
                    StadiumSectionLabel('Waiting for you · ${inbox.pending.length}'),
                    for (final booking in inbox.pending) ...[
                      _BookingCard(
                        booking: booking,
                        busy: _busy.contains(booking.id),
                        onDecline: () => _decide(booking, false),
                        onAccept: () => _decide(booking, true),
                      ),
                      SizedBox(height: 10 * scale),
                    ],
                    SizedBox(height: 6 * scale),
                  ],
                  if (inbox.confirmed.isNotEmpty) ...[
                    StadiumSectionLabel('Confirmed'),
                    for (final booking in inbox.confirmed) ...[
                      _BookingCard(booking: booking),
                      SizedBox(height: 10 * scale),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.busy = false,
    this.onDecline,
    this.onAccept,
  });

  final StadiumBooking booking;
  final bool busy;
  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final pending = booking.isPending;
    return StadiumChunkyTile(
      color: pending ? KickoffColors.blue : KickoffColors.panel,
      edge: pending ? KickoffColors.blueDark : KickoffColors.panelDark,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        8 * scale,
        10 * scale,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58 * scale,
            child: Column(
              children: [
                Text(
                  stadiumTime(booking.start),
                  style: stadiumText(scale, 18, weight: FontWeight.w600),
                ),
                Text(
                  stadiumShortDate(booking.date),
                  style: stadiumText(
                    scale,
                    12,
                    color: pending ? Colors.white : KickoffColors.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pitch ${booking.pitchName ?? '?'} · ${booking.pitchSize ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: stadiumText(scale, 15, weight: FontWeight.w600),
                ),
                Text(
                  '${booking.stadiumName ?? ''} · ${booking.hostName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: stadiumText(
                    scale,
                    13,
                    color: pending ? Colors.white : KickoffColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (!pending)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Icon(
                Icons.check_rounded,
                color: KickoffColors.yellow,
                size: 24 * scale,
              ),
            )
          else if (busy)
            Padding(
              padding: EdgeInsets.all(14 * scale),
              child: SizedBox(
                width: 20 * scale,
                height: 20 * scale,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else ...[
            StadiumCircleAction(
              icon: Icons.close_rounded,
              label: 'Decline booking',
              color: KickoffColors.red,
              foreground: Colors.white,
              onTap: onDecline,
            ),
            StadiumCircleAction(
              icon: Icons.check_rounded,
              label: 'Accept booking',
              color: KickoffColors.yellow,
              foreground: KickoffColors.ink,
              onTap: onAccept,
            ),
          ],
        ],
      ),
    );
  }
}
