import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../tournament_constants.dart';

/// Joins with a team name chosen by the captain.
///
/// [onJoin] receives the normalized name and returns an error message to show
/// in the sheet, or null once the team is registered. Resolves to true when
/// the user joined, false when they cancelled.
Future<bool> showJoinTeamSheet(
  BuildContext context, {
  required String tournamentName,
  required Future<String?> Function(String teamName) onJoin,
  String? warning,
}) async {
  final scale = kickoffScale(context);
  final joined = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // The sheet has a Cancel button; dragging could close it mid-request.
    enableDrag: false,
    backgroundColor: KickoffColors.panelDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TournamentSizes.SHEET_RADIUS * scale),
      ),
    ),
    builder: (_) => JoinTeamSheet(
      tournamentName: tournamentName,
      onJoin: onJoin,
      warning: warning,
    ),
  );
  return joined ?? false;
}

class JoinTeamSheet extends StatefulWidget {
  const JoinTeamSheet({
    required this.tournamentName,
    required this.onJoin,
    this.warning,
    super.key,
  });

  final String tournamentName;
  final Future<String?> Function(String teamName) onJoin;

  /// Shown above the field, e.g. when joining cancels a pending request.
  final String? warning;

  @override
  State<JoinTeamSheet> createState() => _JoinTeamSheetState();
}

class _JoinTeamSheetState extends State<JoinTeamSheet> {
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _serverError;
  String _lastName = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// A server error describes the submitted name, so editing clears it.
  void _onNameChanged() {
    final name = _nameController.text;
    if (name == _lastName) return;
    _lastName = name;
    setState(() => _serverError = null);
  }

  Future<void> _submit() async {
    if (_isSubmitting || TeamName.validate(_nameController.text) != null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });
    final error = await widget.onJoin(TeamName.normalize(_nameController.text));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _serverError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final name = _nameController.text;
    final validationError = name.trim().isEmpty
        ? null
        : TeamName.validate(name);
    final error = _serverError ?? validationError;
    final canSubmit = !_isSubmitting && TeamName.validate(name) == null;
    final captionStyle = TextStyle(
      fontSize: TournamentSizes.CAPTION * scale,
      fontWeight: FontWeight.w500,
    );

    return PopScope(
      canPop: !_isSubmitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
                  TournamentStrings.TEAM_NAME_TITLE,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Text(
                  TournamentStrings.confirmJoinMessage(widget.tournamentName),
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.warning case final warning?) ...[
                  SizedBox(height: 12 * scale),
                  _WarningBox(message: warning),
                ],
                SizedBox(height: 16 * scale),
                PillField(
                  key: const ValueKey('tournament_team_name'),
                  controller: _nameController,
                  hint: TournamentStrings.TEAM_NAME_HINT,
                  icon: Icons.shield_rounded,
                  enabled: !_isSubmitting,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      TournamentSizes.TEAM_NAME_MAX_LENGTH,
                    ),
                  ],
                  onSubmitted: (_) => _submit(),
                ),
                SizedBox(height: 6 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: error != null,
                          child: Text(
                            error ?? TournamentStrings.TEAM_NAME_RULES,
                            style: captionStyle.copyWith(
                              color: error == null
                                  ? KickoffColors.muted
                                  : TournamentColors.ERROR_TEXT,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Text(
                        TournamentStrings.teamNameCounter(name.length),
                        style: captionStyle.copyWith(
                          color: KickoffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16 * scale),
                ChunkyButton(
                  key: const ValueKey('tournament_confirm_join'),
                  label: TournamentStrings.CONFIRM_JOIN,
                  icon: Icons.check_rounded,
                  busy: _isSubmitting,
                  onPressed: canSubmit ? _submit : null,
                ),
                SizedBox(height: 8 * scale),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: KickoffColors.muted,
                    minimumSize: Size.fromHeight(
                      TournamentSizes.MIN_TAP * scale,
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
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
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      key: const ValueKey('join_pending_warning'),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.ink,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: KickoffColors.orange,
            size: 22 * scale,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
