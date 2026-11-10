import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament_stats.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import 'tournament_states.dart';

class TournamentStatsWidget extends StatefulWidget {
  const TournamentStatsWidget({
    required this.service,
    required this.tournamentId,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  @override
  State<TournamentStatsWidget> createState() => _TournamentStatsWidgetState();
}

class _TournamentStatsWidgetState extends State<TournamentStatsWidget> {
  bool _isLoading = true;
  String? _error;
  TournamentStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool showLoading = true}) async {
    setState(() {
      _isLoading = showLoading;
      _error = null;
    });
    try {
      final stats = await widget.service.getTournamentStats(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } on TournamentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = TournamentStrings.ERROR_LOAD_STATS;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (_isLoading) return const TournamentLoading();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadStats);
    }
    final stats = _stats;
    if (stats == null ||
        (stats.totals.totalMatches == 0 &&
            stats.topScorers.isEmpty &&
            stats.winRates.isEmpty)) {
      return RefreshIndicator(
        onRefresh: () => _loadStats(showLoading: false),
        color: KickoffColors.ink,
        backgroundColor: KickoffColors.yellow,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            TournamentEmpty(
              icon: Icons.bar_chart_rounded,
              title: TournamentStrings.NO_STATS_YET,
              message: TournamentStrings.NO_STATS_HINT,
            ),
          ],
        ),
      );
    }

    final scale = kickoffScale(context);
    return RefreshIndicator(
      onRefresh: () => _loadStats(showLoading: false),
      color: KickoffColors.ink,
      backgroundColor: KickoffColors.yellow,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 12 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Cards
            _buildTotalsGrid(stats.totals, scale),
            SizedBox(height: 20 * scale),

            // Top Scorers
            if (stats.topScorers.isNotEmpty) ...[
              _buildSectionHeader(
                TournamentStrings.TOP_SCORERS,
                Icons.emoji_events_rounded,
                scale,
              ),
              SizedBox(height: 8 * scale),
              _buildTopScorersList(stats.topScorers, scale),
              SizedBox(height: 20 * scale),
            ],

            // Win Rates
            if (stats.winRates.isNotEmpty) ...[
              _buildSectionHeader(
                TournamentStrings.WIN_RATES,
                Icons.pie_chart_rounded,
                scale,
              ),
              SizedBox(height: 8 * scale),
              _buildWinRatesList(stats.winRates, stats.topScorers, scale),
              SizedBox(height: 16 * scale),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsGrid(TournamentTotals totals, double scale) {
    return Row(
      children: [
        Expanded(
          child: _StatSummaryCard(
            label: TournamentStrings.TOTAL_GOALS,
            value: totals.totalGoals.toString(),
            icon: Icons.sports_soccer_rounded,
            scale: scale,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _StatSummaryCard(
            label: TournamentStrings.MATCHES_PLAYED,
            value: totals.totalMatches.toString(),
            icon: Icons.sports_rounded,
            scale: scale,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _StatSummaryCard(
            label: TournamentStrings.AVG_GOALS,
            value: totals.averageGoalsPerMatch.toStringAsFixed(1),
            icon: Icons.trending_up_rounded,
            scale: scale,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, double scale) {
    return Row(
      children: [
        Icon(icon, color: KickoffColors.yellow, size: 20 * scale),
        SizedBox(width: 8 * scale),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: TournamentSizes.CARD_TITLE * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTopScorersList(List<ScorerStat> scorers, double scale) {
    return Container(
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: scorers.length,
        separatorBuilder: (_, _) => Divider(
          color: KickoffColors.panelDark,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final scorer = scorers[index];
          final rank = index + 1;
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 10 * scale,
            ),
            child: Row(
              children: [
                _RankBadge(rank: rank, scale: scale),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    scorer.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TournamentSizes.BODY * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${scorer.goals} goals',
                  style: TextStyle(
                    color: KickoffColors.yellow,
                    fontSize: TournamentSizes.BODY * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWinRatesList(
    Map<int, double> winRates,
    List<ScorerStat> scorers,
    double scale,
  ) {
    final teamNameMap = {for (final s in scorers) s.id: s.name};
    final entries = winRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale),
      ),
      child: Column(
        children: entries.map((entry) {
          final teamName = teamNameMap[entry.key] ?? 'Team #${entry.key}';
          final percentage = entry.value;
          final fraction = (percentage / 100.0).clamp(0.0, 1.0);

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      teamName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TournamentSizes.BODY * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: KickoffColors.yellow,
                        fontSize: TournamentSizes.BODY * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * scale),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4 * scale),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8 * scale,
                    backgroundColor: KickoffColors.panelDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      KickoffColors.yellow,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  const _StatSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.scale,
  });

  final String label;
  final String value;
  final IconData icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale),
      ),
      child: Column(
        children: [
          Icon(icon, color: KickoffColors.yellow, size: 22 * scale),
          SizedBox(height: 6 * scale),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.scale});

  final int rank;
  final double scale;

  Color get _badgeColor {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => KickoffColors.dim,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = 26 * scale;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _badgeColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: KickoffColors.ink,
          fontSize: 12 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
