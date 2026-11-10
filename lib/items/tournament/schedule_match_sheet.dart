import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import '../../entities/tournament/bracket.dart';
import '../../services/tournament/tournament_service.dart';
import 'tournament_constants.dart';

/// Shows a bottom sheet for the organizer to set a match's date/time and
/// location. Returns true when at least one field was saved.
Future<bool> showScheduleMatchSheet(
  BuildContext context, {
  required TournamentService service,
  required int tournamentId,
  required BracketMatch match,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: KickoffColors.panelDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TournamentSizes.SHEET_RADIUS),
      ),
    ),
    builder: (_) => _ScheduleMatchSheet(
      service: service,
      tournamentId: tournamentId,
      match: match,
    ),
  );
  return saved ?? false;
}

class _ScheduleMatchSheet extends StatefulWidget {
  const _ScheduleMatchSheet({
    required this.service,
    required this.tournamentId,
    required this.match,
  });

  final TournamentService service;
  final int tournamentId;
  final BracketMatch match;

  @override
  State<_ScheduleMatchSheet> createState() => _ScheduleMatchSheetState();
}

class _ScheduleMatchSheetState extends State<_ScheduleMatchSheet> {
  late DateTime? _scheduledAt;
  late final TextEditingController _locationController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.match.scheduledAt;
    _locationController = TextEditingController(
      text: widget.match.location ?? '',
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : const TimeOfDay(hour: 15, minute: 0),
    );
    if (!mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 15,
      time?.minute ?? 0,
    );
    setState(() => _scheduledAt = combined);
  }

  Future<void> _save() async {
    final matchId = widget.match.id;
    if (matchId == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final location = _locationController.text.trim();
      await widget.service.scheduleMatch(
        widget.tournamentId,
        matchId,
        scheduledAt: _scheduledAt,
        location: location.isEmpty ? null : location,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TournamentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final scheduledAt = _scheduledAt;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16 * scale, 18 * scale, 16 * scale, 12 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              TournamentStrings.SCHEDULE_MATCH,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              _matchLabel,
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 10 * scale),
              Text(
                _error!,
                style: TextStyle(
                  color: TournamentColors.ERROR_TEXT,
                  fontSize: TournamentSizes.CAPTION * scale,
                ),
              ),
            ],
            SizedBox(height: 16 * scale),
            GestureDetector(
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: TournamentStrings.FIELD_MATCH_DATE,
                  labelStyle: TextStyle(color: KickoffColors.muted),
                  prefixIcon: Icon(
                    Icons.calendar_today_rounded,
                    color: KickoffColors.yellow,
                    size: 20 * scale,
                  ),
                  filled: true,
                  fillColor: KickoffColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                    borderSide: BorderSide.none,
                  ),
                ),
                child: Text(
                  scheduledAt != null
                      ? TournamentStrings.shortDate(scheduledAt)
                      : TournamentStrings.TAP_TO_SET,
                  style: TextStyle(
                    color: scheduledAt != null ? Colors.white : KickoffColors.dim,
                    fontSize: TournamentSizes.BODY * scale,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10 * scale),
            TextFormField(
              controller: _locationController,
              style: TextStyle(color: Colors.white, fontSize: TournamentSizes.BODY * scale),
              decoration: InputDecoration(
                labelText: TournamentStrings.FIELD_LOCATION,
                labelStyle: TextStyle(color: KickoffColors.muted),
                prefixIcon: Icon(
                  Icons.place_rounded,
                  color: KickoffColors.yellow,
                  size: 20 * scale,
                ),
                filled: true,
                fillColor: KickoffColors.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8 * scale),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
            ChunkyButton(
              label: TournamentStrings.SAVE,
              icon: Icons.check_rounded,
              busy: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
            SizedBox(height: 8 * scale),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: KickoffColors.muted,
                minimumSize: Size.fromHeight(TournamentSizes.MIN_TAP * scale),
              ),
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              child: Text(
                TournamentStrings.CANCEL,
                style: TextStyle(
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _matchLabel {
    final home = widget.match.home?.name ?? TournamentStrings.TBD;
    final away = widget.match.away?.name ?? TournamentStrings.TBD;
    return '$home vs $away';
  }
}
