import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../widgets/standings_widget.dart';
import '../widgets/tournament_states.dart';

class TournamentStandingsScreen extends StatelessWidget {
  const TournamentStandingsScreen({
    required this.service,
    required this.tournamentId,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    body: SafeArea(
      child: Column(
        children: [
          const TournamentHeader(title: TournamentStrings.STANDINGS),
          Expanded(
            child: TournamentStandingsView(
              service: service,
              tournamentId: tournamentId,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Loads and shows a tournament's standings with loading, error and empty
/// states. Used by [TournamentStandingsScreen] and the detail Standings tab.
class TournamentStandingsView extends StatefulWidget {
  const TournamentStandingsView({
    required this.service,
    required this.tournamentId,
    this.grouped = false,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  /// Groups + knockout tournaments show one titled table per group.
  final bool grouped;

  @override
  State<TournamentStandingsView> createState() =>
      _TournamentStandingsViewState();
}

class _TournamentStandingsViewState extends State<TournamentStandingsView> {
  bool _isLoading = true;
  String? _error;
  List<StandingRow> _standings = const [];

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final standings = await widget.service.getStandings(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _standings = standings;
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

  /// Rows split by group, keeping the service's group order.
  List<({String? label, List<StandingRow> rows})> _groups() {
    final groups = <({String? label, List<StandingRow> rows})>[];
    for (final row in _standings) {
      if (groups.isEmpty || groups.last.label != row.group) {
        groups.add((label: row.group, rows: []));
      }
      groups.last.rows.add(row);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (_isLoading) return const TournamentLoading();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadStandings);
    }
    if (_standings.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.leaderboard_rounded,
        title: TournamentStrings.STANDINGS,
        message: TournamentStrings.EMPTY_STANDINGS,
      );
    }
    final scale = kickoffScale(context);
    return RefreshIndicator(
      onRefresh: _loadStandings,
      color: KickoffColors.ink,
      backgroundColor: KickoffColors.yellow,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          8 * scale,
          12 * scale,
          16 * scale,
        ),
        children: widget.grouped
            ? [
                for (final (index, group) in _groups().indexed) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 16 * scale,
                      bottom: 8 * scale,
                    ),
                    child: Text(
                      TournamentStrings.groupTitle(group.label),
                      style: TextStyle(
                        color: KickoffColors.yellow,
                        fontSize: TournamentSizes.CARD_TITLE * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StandingsWidget(rows: group.rows),
                ],
              ]
            : [StandingsWidget(rows: _standings)],
      ),
    );
  }
}
