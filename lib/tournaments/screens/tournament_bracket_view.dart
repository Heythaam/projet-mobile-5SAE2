import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/bracket.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../widgets/bracket_widget.dart';
import '../widgets/tournament_states.dart';

/// Loads and shows a tournament's knockout bracket with loading, error and
/// empty states. Used by the detail Bracket tab.
class TournamentBracketView extends StatefulWidget {
  const TournamentBracketView({
    required this.service,
    required this.tournamentId,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView> {
  bool _isLoading = true;
  String? _error;
  List<BracketRound> _rounds = const [];

  @override
  void initState() {
    super.initState();
    _loadBracket();
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
        child: BracketWidget(rounds: _rounds),
      ),
    );
  }
}
