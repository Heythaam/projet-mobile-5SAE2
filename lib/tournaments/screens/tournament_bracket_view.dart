import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../screens/kickoff_style.dart';
import '../models/bracket.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../widgets/bracket_widget.dart';
import '../widgets/record_result_sheet.dart';
import '../widgets/schedule_match_sheet.dart';
import '../widgets/tournament_states.dart';

/// Loads and shows a tournament's knockout bracket with loading, error and
/// empty states. Used by the detail Bracket tab.
class TournamentBracketView extends StatefulWidget {
  const TournamentBracketView({
    required this.service,
    required this.tournamentId,
    this.autoRefresh = false,
    this.isOrganizer = false,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  /// Polls for updates when the tournament is active.
  final bool autoRefresh;

  /// Shows schedule controls on each match card when true.
  final bool isOrganizer;

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isLoading = true;
  String? _error;
  List<BracketRound> _rounds = const [];
  Timer? _refreshTimer;
  StreamSubscription<dynamic>? _liveSub;

  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadBracket();
    _connectLive();
    if (widget.autoRefresh) {
      _refreshTimer = Timer.periodic(
        _refreshInterval,
        (_) => _loadBracket(showLoading: false),
      );
    }
  }

  void _connectLive() {
    try {
      _liveSub = widget.service.connectToLiveMatches(widget.tournamentId).listen(
        (dynamic message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message.toString());
            if (data is Map && data['event'] == 'match_updated') {
              _loadBracket(showLoading: false);
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _openScheduleSheet(BracketMatch match) async {
    if (match.id == null) return;
    final scheduleOnly = match.status == BracketMatchStatus.scheduled ||
        match.status == BracketMatchStatus.pending;
    bool saved;
    if (scheduleOnly) {
      saved = await showScheduleMatchSheet(
        context,
        service: widget.service,
        tournamentId: widget.tournamentId,
        match: match,
      );
    } else {
      saved = await showRecordResultSheet(
        context,
        service: widget.service,
        tournamentId: widget.tournamentId,
        match: match,
      );
    }
    if (saved && mounted) await _loadBracket(showLoading: false);
  }

  /// [showLoading] is false for pull-to-refresh, which has its own spinner.
  Future<void> _loadBracket({bool showLoading = true}) async {
    setState(() {
      _isLoading = showLoading;
      _error = null;
    });
    try {
      final rounds = await widget.service.getBracket(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
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

  Future<void> _showShareSheet() async {
    final scale = kickoffScale(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KickoffColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TournamentSizes.SHEET_RADIUS * scale),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 20 * scale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TournamentStrings.SHARE_BRACKET,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TournamentSizes.CARD_TITLE * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16 * scale),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.panelDark,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Icon(
                    Icons.image_rounded,
                    color: KickoffColors.yellow,
                    size: 22 * scale,
                  ),
                ),
                title: Text(
                  TournamentStrings.SHARE_IMAGE,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.panelDark,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: KickoffColors.yellow,
                    size: 22 * scale,
                  ),
                ),
                title: Text(
                  TournamentStrings.SHARE_LINK,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareLink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareImage() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              pngBytes,
              mimeType: 'image/png',
              name: 'bracket_${widget.tournamentId}.png',
            ),
          ],
          text: 'Tournament Bracket',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share bracket image: $e')),
        );
      }
    }
  }

  void _shareLink() {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Check out the tournament bracket: https://kickoff.app/tournaments/${widget.tournamentId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (_isLoading) return const TournamentLoading();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadBracket);
    }
    if (_rounds.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.account_tree_rounded,
        title: TournamentStrings.EMPTY_BRACKET,
        message: TournamentStrings.EMPTY_BRACKET_HINT,
      );
    }
    final scale = kickoffScale(context);
    return RefreshIndicator(
      onRefresh: () => _loadBracket(showLoading: false),
      color: KickoffColors.ink,
      backgroundColor: KickoffColors.yellow,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: const ValueKey('share_bracket_button'),
                    icon: Icon(
                      Icons.share_rounded,
                      color: KickoffColors.yellow,
                      size: 22 * scale,
                    ),
                    tooltip: TournamentStrings.SHARE_BRACKET,
                    onPressed: _showShareSheet,
                  ),
                ],
              ),
            ),
            RepaintBoundary(
              key: _repaintBoundaryKey,
              child: BracketWidget(
                rounds: _rounds,
                onMatchTap: widget.isOrganizer ? _openScheduleSheet : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
