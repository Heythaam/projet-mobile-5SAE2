import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/team_details.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import 'sheet_frame.dart';
import 'tournament_states.dart';

/// Lets a captain pick a player of their team to become captain.
///
/// [onTransfer] returns an error message to show in the sheet, or null once
/// the transfer succeeded. Resolves to the new captain, or null when the
/// captain backed out.
Future<TeamPlayer?> showTransferCaptaincySheet(
  BuildContext context, {
  required TournamentService service,
  required int tournamentId,
  required int teamId,
  required Future<String?> Function(TeamPlayer player) onTransfer,
}) => showTournamentSheet<TeamPlayer>(
  context,
  builder: (_) => TransferCaptaincySheet(
    service: service,
    tournamentId: tournamentId,
    teamId: teamId,
    onTransfer: onTransfer,
  ),
);

class TransferCaptaincySheet extends StatefulWidget {
  const TransferCaptaincySheet({
    required this.service,
    required this.tournamentId,
    required this.teamId,
    required this.onTransfer,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;
  final int teamId;
  final Future<String?> Function(TeamPlayer player) onTransfer;

  @override
  State<TransferCaptaincySheet> createState() => _TransferCaptaincySheetState();
}

class _TransferCaptaincySheetState extends State<TransferCaptaincySheet> {
  bool _isLoading = true;
  bool _isWorking = false;
  String? _error;
  String? _transferError;
  List<TeamPlayer> _players = const [];
  TeamPlayer? _selected;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final team = await widget.service.getTeam(
        widget.tournamentId,
        widget.teamId,
      );
      if (!mounted) return;
      setState(() {
        _players = team.players.where((player) => !player.isCaptain).toList();
        _isLoading = false;
      });
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _transfer(TeamPlayer player) async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _transferError = null;
    });
    final error = await widget.onTransfer(player);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(player);
      return;
    }
    setState(() {
      _isWorking = false;
      _transferError = error;
    });
  }

  void _close() {
    // Closing mid-request would hide whether the transfer happened.
    if (!_isWorking) Navigator.of(context).pop();
  }

  /// A modal sheet's drag closes it without asking its [PopScope], so while
  /// a request is in flight this handler claims vertical drags first and the
  /// sheet cannot be swiped away. Swiping works again once it finishes.
  void _holdDrag(DragStartDetails _) {}

  @override
  Widget build(BuildContext context) => GestureDetector(
    onVerticalDragStart: _isWorking ? _holdDrag : null,
    child: TournamentSheetFrame(
      title: TournamentStrings.TRANSFER_CAPTAINCY,
      onClose: _close,
      child: _body(),
    ),
  );

  Widget _body() {
    final error = _error;
    if (_isLoading) return const TournamentLoading();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadPlayers);
    }
    if (_players.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.groups_rounded,
        title: TournamentStrings.TRANSFER_EMPTY,
        message: TournamentStrings.TRANSFER_EMPTY_HINT,
      );
    }
    final scale = kickoffScale(context);
    final selected = _selected;
    final transferError = _transferError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
            children: [
              Text(
                TournamentStrings.TRANSFER_HINT,
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12 * scale),
              for (final player in _players) ...[
                _PlayerChoice(
                  player: player,
                  selected: player.id == selected?.id,
                  onTap: _isWorking
                      ? null
                      : () => setState(() {
                          _selected = player;
                          _transferError = null;
                        }),
                ),
                SizedBox(height: 6 * scale),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            TournamentSizes.CARD_PADDING * scale,
            0,
            TournamentSizes.CARD_PADDING * scale,
            12 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (transferError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    transferError,
                    style: TextStyle(
                      color: TournamentColors.ERROR_TEXT,
                      fontSize: TournamentSizes.CAPTION * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 8 * scale),
              ],
              // Greyed out until a player is picked.
              if (selected == null)
                const ChunkyButton(
                  key: ValueKey('transfer_confirm'),
                  label: TournamentStrings.TRANSFER_CAPTAINCY,
                  icon: Icons.star_rounded,
                  onPressed: null,
                  backgroundColor: KickoffColors.panel,
                  bottomColor: KickoffColors.panelDark,
                  foregroundColor: KickoffColors.muted,
                )
              else
                ChunkyButton(
                  key: const ValueKey('transfer_confirm'),
                  label: TournamentStrings.makeCaptain(selected.username),
                  icon: Icons.star_rounded,
                  busy: _isWorking,
                  onPressed: _isWorking ? null : () => _transfer(selected),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A player the captain can hand the team to; one is selected at a time.
class _PlayerChoice extends StatelessWidget {
  const _PlayerChoice({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final TeamPlayer player;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? KickoffColors.blue : KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey('transfer_player_${player.id}'),
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: TournamentSizes.MIN_TAP * scale,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 6 * scale,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: KickoffColors.yellow,
                  size: 22 * scale,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TournamentSizes.BODY * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        TournamentStrings.playerLine(
                          player.level,
                          player.xp,
                          player.currentStreak,
                        ),
                        style: TextStyle(
                          color: selected ? Colors.white : KickoffColors.muted,
                          fontSize: TournamentSizes.CAPTION * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? KickoffColors.yellow : KickoffColors.muted,
                  size: 24 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
