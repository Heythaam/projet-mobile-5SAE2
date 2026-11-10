import 'package:flutter/material.dart';

import '../../entities/stadium/stadium.dart';
import '../../items/kickoff_style.dart';
import '../../items/stadium/stadium_widgets.dart';
import '../../services/stadium/stadium_api.dart';
import 'stadium_editor_screen.dart';

class StadiumDetailScreen extends StatefulWidget {
  const StadiumDetailScreen({
    required this.api,
    required this.stadium,
    super.key,
  });

  final StadiumApi api;
  final Stadium stadium;

  @override
  State<StadiumDetailScreen> createState() => _StadiumDetailScreenState();
}

class _StadiumDetailScreenState extends State<StadiumDetailScreen> {
  late Stadium _stadium = widget.stadium;
  final DateTime _today = stadiumDateOnly(DateTime.now());
  late DateTime _day = _today;
  int _pitch = 0;
  DayAvailability? _data;
  String? _error;
  bool _loading = true;
  bool _blockMode = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final day = _day;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.availability(_stadium.id, day);
      if (!mounted || day != _day) return;
      setState(() {
        _data = data;
        _loading = false;
        _pitch = _pitch.clamp(0, (data.pitches.length - 1).clamp(0, 99));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = stadiumMessage(error);
        _loading = false;
      });
    }
  }

  void _selectDay(DateTime day) {
    if (day == _day) return;
    setState(() {
      _day = day;
      _data = null;
    });
    _load();
  }

  Future<void> _tapSlot(PitchAvailability pitch, StadiumSlot slot) async {
    if (_busy.contains(slot.start)) return;
    if (_blockMode) {
      if (slot.state == SlotState.free) {
        await _run(slot.start, () {
          return widget.api.block(
            _stadium.id,
            pitch.pitch.id!,
            _day,
            slot.start,
          );
        });
      } else if (slot.state == SlotState.blocked && slot.blockId != null) {
        await _run(slot.start, () => widget.api.unblock(slot.blockId!));
      } else if (slot.state == SlotState.past) {
        stadiumToast(context, 'That slot has already passed.');
      } else {
        stadiumToast(context, 'Booked slots cannot be blocked.');
      }
      return;
    }
    switch (slot.state) {
      case SlotState.pending:
      case SlotState.confirmed:
        await _showBooking(pitch, slot);
      case SlotState.blocked:
        stadiumToast(context, 'Blocked. Tap “Block a slot” to reopen it.');
      case SlotState.free:
        stadiumToast(context, 'Free to book. Tap “Block a slot” to close it.');
      case SlotState.past:
        break;
    }
  }

  Future<void> _run(int start, Future<void> Function() action) async {
    setState(() => _busy.add(start));
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) stadiumToast(context, stadiumMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(start));
    }
  }

  Future<void> _showBooking(PitchAvailability pitch, StadiumSlot slot) async {
    final booking = slot.booking;
    if (booking == null) return;
    final decision = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: KickoffColors.panelDark,
      shape: stadiumSheetShape(context),
      builder: (context) => _BookingSheet(
        booking: booking,
        pitchLabel: 'Pitch ${pitch.pitch.name} · ${pitch.pitch.size}',
      ),
    );
    if (decision == null) return;
    await _run(
      slot.start,
      () => widget.api.decide(booking.id, accept: decision),
    );
    if (mounted) {
      stadiumToast(context, decision ? 'Booking accepted.' : 'Booking declined.');
    }
  }

  Future<void> _manage() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KickoffColors.panelDark,
      shape: stadiumSheetShape(context),
      builder: (context) => StadiumSheetBody(
        title: _stadium.name,
        children: [
          StadiumSheetOption(
            icon: Icons.edit_rounded,
            label: 'Edit details',
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          StadiumSheetOption(
            icon: _stadium.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: _stadium.paused ? 'Resume bookings' : 'Pause bookings',
            onTap: () => Navigator.of(context).pop('pause'),
          ),
          StadiumSheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete stadium',
            color: const Color(0xFFFFB7AB),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        final saved = await Navigator.of(context).push<Stadium>(
          MaterialPageRoute(
            builder: (_) =>
                StadiumEditorScreen(api: widget.api, stadium: _stadium),
          ),
        );
        if (saved == null || !mounted) return;
        setState(() => _stadium = saved);
        stadiumToast(context, 'Changes saved.');
        await _load();
      case 'pause':
        await _togglePause();
      case 'delete':
        await _delete();
    }
  }

  Future<void> _togglePause() async {
    try {
      final updated = await widget.api.setPaused(_stadium.id, !_stadium.paused);
      if (!mounted) return;
      setState(() => _stadium = updated);
      stadiumToast(
        context,
        updated.paused
            ? 'Paused. Players can’t book ${updated.name} for now.'
            : '${updated.name} is taking bookings again.',
      );
    } catch (error) {
      if (mounted) stadiumToast(context, stadiumMessage(error), error: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scale = kickoffScale(context);
        return AlertDialog(
          backgroundColor: KickoffColors.panelDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22 * scale),
          ),
          title: Text(
            'Delete ${_stadium.name}?',
            style: stadiumText(scale, 19, weight: FontWeight.w600),
          ),
          content: Text(
            'Its pitches, hours and blocked slots are removed. '
            'This cannot be undone.',
            style: stadiumText(scale, 15, color: KickoffColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Keep it', style: stadiumText(scale, 15)),
            ),
            TextButton(
              key: const ValueKey('stadium_confirm_delete'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: stadiumText(
                  scale,
                  15,
                  color: const Color(0xFFFFB7AB),
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.delete(_stadium.id);
      if (!mounted) return;
      stadiumToast(context, '${_stadium.name} was deleted.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) stadiumToast(context, stadiumMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final data = _data;
    final pitch = data == null || data.pitches.isEmpty
        ? null
        : data.pitches[_pitch];
    return StadiumPage(
      title: _stadium.name,
      actions: [
        RoundIconButton(
          icon: Icons.settings_rounded,
          label: 'Manage stadium',
          onPressed: _manage,
        ),
      ],
      bottom: data == null || !data.open
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The hint sits above the button so the slot grid never
                // jumps when block mode turns on.
                if (_blockMode) ...[
                  const StadiumBanner(
                    icon: Icons.touch_app_rounded,
                    text:
                        'Tap free slots to block them. '
                        'Tap a locked slot to free it.',
                  ),
                  SizedBox(height: 10 * scale),
                ],
                ChunkyButton(
                  key: const ValueKey('stadium_block_mode'),
                  label: _blockMode ? 'Done' : 'Block a slot',
                  icon: _blockMode ? Icons.check_rounded : Icons.lock_rounded,
                  backgroundColor: _blockMode
                      ? KickoffColors.blue
                      : KickoffColors.yellow,
                  bottomColor: _blockMode
                      ? KickoffColors.blueDark
                      : KickoffColors.yellowDark,
                  foregroundColor: _blockMode
                      ? Colors.white
                      : KickoffColors.ink,
                  onPressed: () => setState(() => _blockMode = !_blockMode),
                ),
              ],
            ),
      child: RefreshIndicator(
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
            if (_stadium.paused) ...[
              StadiumBanner(
                icon: Icons.pause_circle_rounded,
                text: 'Paused. Players can’t book this stadium.',
                actionLabel: 'Resume',
                onAction: _togglePause,
              ),
              SizedBox(height: 12 * scale),
            ],
            if (_stadium.pitches.length > 1 || (data?.pitches.length ?? 0) > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 12 * scale),
                child: Row(
                  children: [
                    for (final (index, item)
                        in (data?.pitches.map((p) => p.pitch) ??
                                _stadium.pitches)
                            .indexed) ...[
                      StadiumLetterChip(
                        letter: item.name,
                        label: 'Pitch ${item.name}, ${item.size}',
                        selected: index == _pitch,
                        onTap: () => setState(() => _pitch = index),
                      ),
                      SizedBox(width: 8 * scale),
                    ],
                    const Spacer(),
                    if (pitch != null)
                      Text(
                        '${pitch.pitch.size} · ${pitch.pitch.surfaceLabel}',
                        style: stadiumText(scale, 14, color: KickoffColors.muted),
                      ),
                  ],
                ),
              ),
            _DayStrip(
              today: _today,
              selected: _day,
              isOpen: _stadium.isOpenOn,
              onSelect: _selectDay,
            ),
            SizedBox(height: 14 * scale),
            if (_loading && data == null)
              Padding(
                padding: EdgeInsets.only(top: 40 * scale),
                child: const StadiumLoading(),
              )
            else if (data == null)
              StadiumStatusView(
                icon: Icons.wifi_off_rounded,
                title: "Couldn't load this day",
                message: _error ?? '',
                actionLabel: 'Try again',
                onAction: _load,
                compact: true,
              )
            else if (!data.open)
              StadiumStatusView(
                icon: Icons.event_busy_rounded,
                title: 'Closed on ${stadiumDayFullNames[_day.weekday - 1]}',
                message: 'Open this day from Manage → Edit details.',
                compact: true,
              )
            else if (pitch != null) ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8 * scale,
                crossAxisSpacing: 8 * scale,
                childAspectRatio: 1.75,
                children: [
                  for (final slot in pitch.slots)
                    _SlotTile(
                      slot: slot,
                      busy: _busy.contains(slot.start),
                      onTap: () => _tapSlot(pitch, slot),
                    ),
                ],
              ),
              SizedBox(height: 14 * scale),
              const _Legend(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.busy,
    required this.onTap,
  });

  final StadiumSlot slot;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final (
      Color color,
      Color edge,
      Color fg,
      IconData? icon,
      String state,
    ) = switch (slot.state) {
      SlotState.free => (
        KickoffColors.blue,
        KickoffColors.blueDark,
        Colors.white,
        null,
        'free',
      ),
      SlotState.confirmed => (
        KickoffColors.yellow,
        KickoffColors.yellowDark,
        KickoffColors.ink,
        Icons.person_rounded,
        'booked by ${slot.booking?.hostName ?? 'a player'}',
      ),
      SlotState.pending => (
        StadiumColors.pending,
        StadiumColors.pendingDark,
        KickoffColors.ink,
        Icons.hourglass_top_rounded,
        'waiting for your answer',
      ),
      SlotState.blocked => (
        KickoffColors.panelDark,
        KickoffColors.panelDark,
        KickoffColors.dim,
        Icons.lock_rounded,
        'blocked',
      ),
      SlotState.past => (
        KickoffColors.panel.withValues(alpha: 0.45),
        Colors.transparent,
        KickoffColors.dim,
        null,
        'past',
      ),
    };
    return Semantics(
      button: slot.state != SlotState.past,
      label: '${stadiumTime(slot.start)}, $state',
      excludeSemantics: true,
      child: StadiumChunkyTile(
        color: color,
        edge: edge,
        onTap: onTap,
        radius: 14,
        edgeWidth: slot.state == SlotState.past ? 0 : 3,
        child: Center(
          child: busy
              ? SizedBox(
                  width: 18 * scale,
                  height: 18 * scale,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16 * scale, color: fg),
                        SizedBox(width: 3 * scale),
                      ],
                      Text(
                        stadiumTime(slot.start),
                        style: stadiumText(
                          scale,
                          16,
                          color: fg,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12 * scale,
          height: 12 * scale,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4 * scale),
          ),
        ),
        SizedBox(width: 5 * scale),
        Text(label, style: stadiumText(scale, 13, color: KickoffColors.muted)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14 * scale,
      runSpacing: 6 * scale,
      children: [
        item(KickoffColors.blue, 'Free'),
        item(KickoffColors.yellow, 'Booked'),
        item(StadiumColors.pending, 'Pending'),
        item(KickoffColors.panelDark, 'Blocked'),
      ],
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.today,
    required this.selected,
    required this.isOpen,
    required this.onSelect,
  });

  final DateTime today;
  final DateTime selected;
  final bool Function(DateTime day) isOpen;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final days = [
      for (var i = 0; i < 14; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    return SizedBox(
      height: 72 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => SizedBox(width: 4 * scale),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = day == selected;
          final open = isOpen(day);
          final color = active
              ? KickoffColors.ink
              : open
              ? Colors.white
              : KickoffColors.dim;
          return Semantics(
            button: true,
            selected: active,
            label:
                '${stadiumDayFullNames[day.weekday - 1]} ${day.day}${open ? '' : ', closed'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onSelect(day),
              borderRadius: BorderRadius.circular(24 * scale),
              child: Container(
                width: 48 * scale,
                decoration: BoxDecoration(
                  color: active ? KickoffColors.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(24 * scale),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stadiumDayLetters[day.weekday - 1],
                      style: stadiumText(
                        scale,
                        13,
                        color: active ? KickoffColors.ink : KickoffColors.muted,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      '${day.day}',
                      style: stadiumText(
                        scale,
                        18,
                        color: color,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingSheet extends StatelessWidget {
  const _BookingSheet({required this.booking, required this.pitchLabel});

  final StadiumBooking booking;
  final String pitchLabel;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return StadiumSheetBody(
      title: booking.isPending ? 'Booking request' : 'Confirmed booking',
      children: [
        StadiumInfoRow(icon: Icons.person_rounded, text: booking.hostName),
        StadiumInfoRow(icon: Icons.grid_view_rounded, text: pitchLabel),
        StadiumInfoRow(
          icon: Icons.schedule_rounded,
          text:
              '${stadiumShortDate(booking.date)} · ${stadiumTime(booking.start)}–'
              '${stadiumTime(booking.end)}',
        ),
        StadiumInfoRow(icon: Icons.payments_rounded, text: '${booking.price}'),
        if (booking.isPending) ...[
          SizedBox(height: 16 * scale),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  backgroundColor: KickoffColors.red,
                  bottomColor: KickoffColors.redDark,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: ChunkyButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
