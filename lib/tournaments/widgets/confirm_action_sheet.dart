import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../tournament_constants.dart';

/// Confirms withdrawing from a tournament. See [showConfirmActionSheet].
Future<bool> showLeaveTournamentSheet(
  BuildContext context, {
  required String tournamentName,
  required Future<String?> Function() onLeave,
}) => showConfirmActionSheet(
  context,
  title: TournamentStrings.LEAVE_TITLE,
  message: TournamentStrings.confirmLeaveMessage(tournamentName),
  confirmLabel: TournamentStrings.CONFIRM_LEAVE,
  confirmIcon: Icons.logout_rounded,
  cancelLabel: TournamentStrings.STAY,
  confirmKey: const ValueKey('tournament_confirm_leave'),
  onConfirm: onLeave,
);

/// Confirms removing [playerName] from the captain's team.
Future<bool> showRemovePlayerSheet(
  BuildContext context, {
  required String playerName,
  required String teamName,
  required Future<String?> Function() onRemove,
}) => showConfirmActionSheet(
  context,
  title: TournamentStrings.REMOVE_PLAYER_TITLE,
  message: TournamentStrings.confirmRemoveMessage(playerName, teamName),
  confirmLabel: TournamentStrings.CONFIRM_REMOVE,
  confirmIcon: Icons.person_remove_rounded,
  cancelLabel: TournamentStrings.KEEP,
  confirmKey: const ValueKey('team_confirm_remove'),
  onConfirm: onRemove,
);

/// Asks before a destructive action.
///
/// [onConfirm] returns an error message to show in the sheet, or null once
/// the action succeeded. Resolves to true when it succeeded, false when the
/// user backed out.
Future<bool> showConfirmActionSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData confirmIcon,
  required String cancelLabel,
  required Key confirmKey,
  required Future<String?> Function() onConfirm,
}) async {
  final scale = kickoffScale(context);
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // The sheet has a cancel button; dragging could close it mid-request.
    enableDrag: false,
    backgroundColor: KickoffColors.panelDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TournamentSizes.SHEET_RADIUS * scale),
      ),
    ),
    builder: (_) => ConfirmActionSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmIcon: confirmIcon,
      cancelLabel: cancelLabel,
      confirmKey: confirmKey,
      onConfirm: onConfirm,
    ),
  );
  return confirmed ?? false;
}

class ConfirmActionSheet extends StatefulWidget {
  const ConfirmActionSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.cancelLabel,
    required this.confirmKey,
    required this.onConfirm,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData confirmIcon;
  final String cancelLabel;
  final Key confirmKey;
  final Future<String?> Function() onConfirm;

  @override
  State<ConfirmActionSheet> createState() => _ConfirmActionSheetState();
}

class _ConfirmActionSheetState extends State<ConfirmActionSheet> {
  bool _isWorking = false;
  String? _error;

  Future<void> _confirm() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });
    final error = await widget.onConfirm();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isWorking = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final error = _error;
    return PopScope(
      canPop: !_isWorking,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            TournamentSizes.CARD_PADDING * scale,
            18 * scale,
            TournamentSizes.CARD_PADDING * scale,
            12 * scale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                widget.message,
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (error != null) ...[
                SizedBox(height: 10 * scale),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: TournamentColors.ERROR_TEXT,
                      fontSize: TournamentSizes.CAPTION * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16 * scale),
              ChunkyButton(
                key: widget.confirmKey,
                label: widget.confirmLabel,
                icon: widget.confirmIcon,
                busy: _isWorking,
                backgroundColor: TournamentColors.DANGER,
                bottomColor: TournamentColors.DANGER_EDGE,
                foregroundColor: Colors.white,
                onPressed: _isWorking ? null : _confirm,
              ),
              SizedBox(height: 8 * scale),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: KickoffColors.muted,
                  minimumSize: Size.fromHeight(TournamentSizes.MIN_TAP * scale),
                ),
                onPressed: _isWorking
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  widget.cancelLabel,
                  style: TextStyle(
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
