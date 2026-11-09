import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import 'player_profile_sheet.dart';
import 'sheet_frame.dart';
import 'tournament_states.dart';

/// Shows the captain's pending join requests. Resolves to true when at least
/// one request was answered, so the caller can refresh team counts.
Future<bool> showJoinRequestsSheet(
  BuildContext context, {
  required TournamentService service,
  required int tournamentId,
}) async {
  final changed = await showTournamentSheet<bool>(
    context,
    builder: (_) =>
        JoinRequestsSheet(service: service, tournamentId: tournamentId),
  );
  return changed ?? false;
}

class JoinRequestsSheet extends StatefulWidget {
  const JoinRequestsSheet({
    required this.service,
    required this.tournamentId,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  @override
  State<JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends State<JoinRequestsSheet> {
  bool _isLoading = true;
  String? _error;
  List<TeamJoinRequest> _requests = const [];

  /// Request being answered, so only its row shows progress.
  int? _answeringId;
  final _rowErrors = <int, String>{};
  String? _notice;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await widget.service.getJoinRequests(
        widget.tournamentId,
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
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

  Future<void> _answer(TeamJoinRequest request, {required bool accept}) async {
    if (_answeringId != null) return;
    setState(() {
      _answeringId = request.id;
      _rowErrors.remove(request.id);
      _notice = null;
    });
    try {
      await widget.service.answerJoinRequest(
        widget.tournamentId,
        request.id,
        accept: accept,
      );
      if (!mounted) return;
      setState(() {
        _answeringId = null;
        _changed = true;
        _requests = _requests.where((item) => item.id != request.id).toList();
        _notice = accept
            ? TournamentStrings.REQUEST_ACCEPTED
            : TournamentStrings.REQUEST_DECLINED_MESSAGE;
      });
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() {
        _answeringId = null;
        _rowErrors[request.id] = error.message;
      });
    }
  }

  /// Closes with whether anything changed; waits while an answer is sent.
  void _close() {
    if (_answeringId != null) return;
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) => TournamentSheetFrame(
    title: TournamentStrings.JOIN_REQUESTS,
    notice: _notice,
    onClose: _close,
    child: _body(kickoffScale(context)),
  );

  Widget _body(double scale) {
    final error = _error;
    if (_isLoading) return const TournamentLoading();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadRequests);
    }
    if (_requests.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.mark_email_read_rounded,
        title: TournamentStrings.JOIN_REQUESTS_EMPTY,
        message: TournamentStrings.JOIN_REQUESTS_EMPTY_HINT,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(12 * scale),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => SizedBox(height: 8 * scale),
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _RequestTile(
          request: request,
          busy: _answeringId == request.id,
          enabled: _answeringId == null,
          error: _rowErrors[request.id],
          onAccept: () => _answer(request, accept: true),
          onDecline: () => _answer(request, accept: false),
          onViewProfile: () => showPlayerProfileSheet(
            context,
            service: widget.service,
            userId: request.requesterId,
            username: request.requesterName,
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.busy,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
    required this.onViewProfile,
    this.error,
  });

  final TeamJoinRequest request;
  final bool busy;
  final bool enabled;
  final String? error;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final error = this.error;
    return Container(
      padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      request.requesterName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TournamentSizes.CARD_TITLE * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      TournamentStrings.requestSentOn(request.createdAt),
                      style: TextStyle(
                        color: KickoffColors.muted,
                        fontSize: TournamentSizes.CAPTION * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          TextButton.icon(
            key: ValueKey('request_profile_${request.id}'),
            style: TextButton.styleFrom(
              foregroundColor: KickoffColors.yellow,
              minimumSize: Size.fromHeight(TournamentSizes.MIN_TAP * scale),
              alignment: Alignment.centerLeft,
              textStyle: TextStyle(
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onViewProfile,
            icon: Icon(Icons.person_search_rounded, size: 20 * scale),
            label: const Text(TournamentStrings.VIEW_PROFILE),
          ),
          if (error != null) ...[
            SizedBox(height: 8 * scale),
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
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  key: ValueKey('request_decline_${request.id}'),
                  label: TournamentStrings.DECLINE,
                  icon: Icons.close_rounded,
                  showIcon: false,
                  onPressed: enabled ? onDecline : null,
                  backgroundColor: KickoffColors.panelDark,
                  bottomColor: KickoffColors.ink,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: ChunkyButton(
                  key: ValueKey('request_accept_${request.id}'),
                  label: TournamentStrings.ACCEPT,
                  icon: Icons.check_rounded,
                  busy: busy,
                  showIcon: false,
                  onPressed: enabled ? onAccept : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
