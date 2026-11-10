import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/kickoff_style.dart';
import '../models/bracket.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';

/// Shows a bottom sheet for the organizer to record a match result.
/// Returns true when the result was saved.
Future<bool> showRecordResultSheet(
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
    builder: (_) => _RecordResultSheet(
      service: service,
      tournamentId: tournamentId,
      match: match,
    ),
  );
  return saved ?? false;
}

class _RecordResultSheet extends StatefulWidget {
  const _RecordResultSheet({
    required this.service,
    required this.tournamentId,
    required this.match,
  });

  final TournamentService service;
  final int tournamentId;
  final BracketMatch match;

  @override
  State<_RecordResultSheet> createState() => _RecordResultSheetState();
}

class _RecordResultSheetState extends State<_RecordResultSheet> {
  late final TextEditingController _homeController;
  late final TextEditingController _awayController;
  int? _winnerId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _homeController = TextEditingController(
      text: widget.match.homeScore?.toString() ?? '',
    );
    _awayController = TextEditingController(
      text: widget.match.awayScore?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  bool get _isDraw {
    final home = int.tryParse(_homeController.text);
    final away = int.tryParse(_awayController.text);
    return home != null && away != null && home == away;
  }

  Future<void> _save() async {
    final matchId = widget.match.id;
    if (matchId == null) return;
    final homeScore = int.tryParse(_homeController.text.trim());
    final awayScore = int.tryParse(_awayController.text.trim());
    if (homeScore == null || awayScore == null || homeScore < 0 || awayScore < 0) {
      setState(() => _error = TournamentStrings.SCORES_INVALID);
      return;
    }
    if (homeScore == awayScore && _winnerId == null) {
      setState(() => _error = TournamentStrings.DRAW_WINNER_REQUIRED);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.service.recordMatchResult(
        widget.tournamentId,
        matchId,
        homeScore: homeScore,
        awayScore: awayScore,
        winnerId: homeScore != awayScore ? null : _winnerId,
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
    final home = widget.match.home;
    final away = widget.match.away;
    final showWinnerPicker = _isDraw && home != null && away != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16 * scale, 18 * scale, 16 * scale, 12 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              TournamentStrings.RECORD_RESULT,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              '${home?.name ?? TournamentStrings.TBD} vs '
              '${away?.name ?? TournamentStrings.TBD}',
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: TournamentSizes.BODY * scale,
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 10 * scale),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: TournamentColors.ERROR_TEXT,
                    fontSize: TournamentSizes.CAPTION * scale,
                  ),
                ),
              ),
            ],
            SizedBox(height: 16 * scale),
            Row(
              children: [
                Expanded(
                  child: _ScoreField(
                    controller: _homeController,
                    label: home?.name ?? TournamentStrings.HOME_SCORE,
                    onChanged: (_) => setState(() => _winnerId = null),
                    scale: scale,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: KickoffColors.muted,
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: _ScoreField(
                    controller: _awayController,
                    label: away?.name ?? TournamentStrings.AWAY_SCORE,
                    onChanged: (_) => setState(() => _winnerId = null),
                    scale: scale,
                  ),
                ),
              ],
            ),
            if (showWinnerPicker) ...[
              SizedBox(height: 12 * scale),
              Text(
                TournamentStrings.DRAW_PICK_WINNER,
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8 * scale),
              Row(
                children: [
                  Expanded(
                    child: _WinnerButton(
                      label: home.name,
                      selected: _winnerId == home.id,
                      onTap: () => setState(() => _winnerId = home.id),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _WinnerButton(
                      label: away.name,
                      selected: _winnerId == away.id,
                      onTap: () => setState(() => _winnerId = away.id),
                      scale: scale,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16 * scale),
            ChunkyButton(
              label: TournamentStrings.RESULT_RECORDED,
              icon: Icons.sports_score_rounded,
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
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.scale,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: 24 * scale,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: KickoffColors.muted,
        fontSize: TournamentSizes.CAPTION * scale,
      ),
      filled: true,
      fillColor: KickoffColors.panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _WinnerButton extends StatelessWidget {
  const _WinnerButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Material(
      color: selected ? KickoffColors.yellow : KickoffColors.panel,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(minHeight: TournamentSizes.MIN_TAP * scale),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? KickoffColors.ink : Colors.white,
              fontSize: TournamentSizes.BODY * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
