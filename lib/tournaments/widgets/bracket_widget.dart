import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/bracket.dart';
import '../tournament_constants.dart';

/// Line height used for bracket text, so card heights can be computed.
const _lineHeight = 1.25;

/// A knockout tree: one column per round, each match centred between the two
/// matches that feed it, joined by connector lines. Scrolls horizontally;
/// the caller provides vertical scrolling.
class BracketWidget extends StatelessWidget {
  const BracketWidget({required this.rounds, super.key});

  final List<BracketRound> rounds;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final cardWidth = TournamentSizes.BRACKET_CARD_WIDTH * scale;
    final connector = TournamentSizes.BRACKET_CONNECTOR * scale;
    final cardHeight = BracketMatchCard.heightFor(context);
    final slot = cardHeight + TournamentSizes.BRACKET_SLOT_GAP * scale;
    final mostMatches = rounds.fold<int>(
      1,
      (most, round) =>
          round.matches.length > most ? round.matches.length : most,
    );
    final height = mostMatches * slot;
    final width = rounds.length * cardWidth + (rounds.length - 1) * connector;

    double centerY(int roundIndex, int matchIndex) =>
        (matchIndex + 0.5) * height / rounds[roundIndex].matches.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var index = 0; index < rounds.length; index++) ...[
                  if (index > 0) SizedBox(width: connector),
                  SizedBox(
                    width: cardWidth,
                    child: Text(
                      TournamentStrings.roundName(
                        rounds[index].roundsFromEnd,
                        rounds[index].round,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: KickoffColors.yellow,
                        fontSize: TournamentSizes.BODY * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8 * scale),
            SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConnectorPainter(
                        rounds: rounds,
                        cardWidth: cardWidth,
                        connector: connector,
                        centerY: centerY,
                        strokeWidth: TournamentSizes.BRACKET_LINE * scale,
                      ),
                    ),
                  ),
                  for (var r = 0; r < rounds.length; r++)
                    for (var m = 0; m < rounds[r].matches.length; m++)
                      Positioned(
                        left: r * (cardWidth + connector),
                        top: centerY(r, m) - cardHeight / 2,
                        width: cardWidth,
                        height: cardHeight,
                        child: BracketMatchCard(
                          match: rounds[r].matches[m],
                          roundName: TournamentStrings.roundName(
                            rounds[r].roundsFromEnd,
                            rounds[r].round,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elbow lines from each pair of matches to the match they feed.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.rounds,
    required this.cardWidth,
    required this.connector,
    required this.centerY,
    required this.strokeWidth,
  });

  final List<BracketRound> rounds;
  final double cardWidth;
  final double connector;
  final double Function(int roundIndex, int matchIndex) centerY;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KickoffColors.panel
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    for (var r = 1; r < rounds.length; r++) {
      final feeders = rounds[r - 1].matches.length;
      for (var m = 0; m < rounds[r].matches.length; m++) {
        final startX = (r - 1) * (cardWidth + connector) + cardWidth;
        final midX = startX + connector / 2;
        final endX = startX + connector;
        final targetY = centerY(r, m);
        for (final feeder in [m * 2, m * 2 + 1]) {
          if (feeder >= feeders) continue;
          final path = Path()
            ..moveTo(startX, centerY(r - 1, feeder))
            ..lineTo(midX, centerY(r - 1, feeder))
            ..lineTo(midX, targetY)
            ..lineTo(endX, targetY);
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.rounds != rounds ||
      oldDelegate.cardWidth != cardWidth ||
      oldDelegate.connector != connector;
}

/// One bracket match: two team rows with scores and a status line.
class BracketMatchCard extends StatelessWidget {
  const BracketMatchCard({
    required this.match,
    required this.roundName,
    super.key,
  });

  final BracketMatch match;
  final String roundName;

  static const _verticalPadding = 8.0;
  static const _rowSpacing = 4.0;

  /// Absorbs text-line rounding so the computed height never clips.
  static const _heightSlack = 2.0;

  /// Card height for the current text scale, so text never clips.
  static double heightFor(BuildContext context) {
    final scale = kickoffScale(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final row = textScaler.scale(TournamentSizes.BODY * scale) * _lineHeight;
    final footer =
        textScaler.scale(TournamentSizes.CAPTION * scale) * _lineHeight;
    return 2 * _verticalPadding * scale +
        2 * row +
        footer +
        2 * _rowSpacing * scale +
        _heightSlack * scale;
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final winner = match.winner;
    final decided = winner != null;
    final home = match.home;
    final away = match.away;
    return Semantics(
      container: true,
      label: TournamentStrings.bracketMatchLabel(
        roundName: roundName,
        position: match.position,
        home: home?.name ?? TournamentStrings.TBD,
        away: away?.name ?? _missingOpponentLabel,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        winner: winner?.name,
      ),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: _verticalPadding * scale,
        ),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(
            TournamentSizes.CARD_RADIUS * scale,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TeamLine(
              name: home?.name,
              placeholder: TournamentStrings.TBD,
              score: match.homeScore,
              isWinner: decided && winner.id == home?.id,
              isLoser: decided && winner.id != home?.id,
            ),
            SizedBox(height: _rowSpacing * scale),
            _TeamLine(
              name: away?.name,
              placeholder: _missingOpponentLabel,
              score: match.awayScore,
              isWinner: decided && winner.id == away?.id,
              isLoser: decided && winner.id != away?.id,
            ),
            SizedBox(height: _rowSpacing * scale),
            Text(
              _footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: TournamentSizes.CAPTION * scale,
                fontWeight: FontWeight.w500,
                height: _lineHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _missingOpponentLabel =>
      match.isBye ? TournamentStrings.BYE : TournamentStrings.TBD;

  String get _footer {
    final scheduledAt = match.scheduledAt;
    return switch (match.status) {
      BracketMatchStatus.played =>
        match.wonOnPenalties
            ? TournamentStrings.MATCH_PENALTIES
            : TournamentStrings.MATCH_PLAYED,
      BracketMatchStatus.bye => TournamentStrings.MATCH_ADVANCES,
      BracketMatchStatus.cancelled => TournamentStrings.MATCH_CANCELLED,
      BracketMatchStatus.scheduled =>
        scheduledAt == null
            ? TournamentStrings.MATCH_SCHEDULED
            : TournamentStrings.shortDate(scheduledAt),
      BracketMatchStatus.pending => TournamentStrings.MATCH_NOT_SCHEDULED,
    };
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.name,
    required this.placeholder,
    required this.score,
    required this.isWinner,
    required this.isLoser,
  });

  /// Null while the team is not known yet; [placeholder] is shown instead.
  final String? name;
  final String placeholder;
  final int? score;
  final bool isWinner;
  final bool isLoser;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final name = this.name;
    final score = this.score;
    final color = isWinner
        ? KickoffColors.yellow
        : isLoser || name == null
        ? KickoffColors.muted
        : Colors.white;
    final style = TextStyle(
      color: color,
      fontSize: TournamentSizes.BODY * scale,
      fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
      fontStyle: name == null ? FontStyle.italic : FontStyle.normal,
      height: _lineHeight,
    );
    return Row(
      children: [
        if (isWinner) ...[
          Icon(
            Icons.emoji_events_rounded,
            color: KickoffColors.yellow,
            size: TournamentSizes.BODY * scale,
          ),
          SizedBox(width: 4 * scale),
        ],
        Expanded(
          child: Text(
            name ?? placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (score != null) ...[
          SizedBox(width: 6 * scale),
          Text('$score', style: style),
        ],
      ],
    );
  }
}
