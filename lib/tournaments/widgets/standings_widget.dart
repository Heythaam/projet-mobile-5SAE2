import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../tournament_constants.dart';

/// Ranked league table. Top three get a medal; the user's team is highlighted.
class StandingsWidget extends StatelessWidget {
  const StandingsWidget({required this.rows, super.key});

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Column(
        children: [
          const _StandingsLine.header(),
          for (final row in rows) _StandingsLine(row: row),
        ],
      ),
    );
  }
}

class _StandingsLine extends StatelessWidget {
  const _StandingsLine({required StandingRow this.row});

  const _StandingsLine.header() : row = null;

  final StandingRow? row;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final row = this.row;
    final header = row == null;
    final highlighted = row?.isUserTeam ?? false;
    final color = header
        ? KickoffColors.dim
        : highlighted
        ? KickoffColors.ink
        : Colors.white;
    final style = TextStyle(
      color: color,
      fontSize:
          (header ? TournamentSizes.CAPTION : TournamentSizes.BODY) * scale,
      fontWeight: header ? FontWeight.w500 : FontWeight.w600,
    );

    Widget stat(String value) => SizedBox(
      width: 28 * scale,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: style, maxLines: 1),
      ),
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6 * scale),
      constraints: BoxConstraints(minHeight: (header ? 28 : 44) * scale),
      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
      decoration: highlighted
          ? BoxDecoration(
              color: KickoffColors.yellow,
              borderRadius: BorderRadius.circular(10 * scale),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 30 * scale,
            child: row != null && row.position <= _medalCount
                ? Semantics(
                    label: '${row.position}',
                    excludeSemantics: true,
                    child: Text(
                      TournamentStrings.MEDALS[row.position - 1],
                      style: TextStyle(fontSize: 18 * scale),
                    ),
                  )
                : Text(
                    row == null
                        ? TournamentStrings.COLUMN_POSITION
                        : '${row.position}',
                    style: style,
                  ),
          ),
          Expanded(
            child: Text(
              row?.teamName ?? TournamentStrings.COLUMN_TEAM,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          stat(row == null ? TournamentStrings.COLUMN_PLAYED : '${row.played}'),
          stat(row == null ? TournamentStrings.COLUMN_WINS : '${row.wins}'),
          stat(row == null ? TournamentStrings.COLUMN_DRAWS : '${row.draws}'),
          stat(row == null ? TournamentStrings.COLUMN_LOSSES : '${row.losses}'),
          stat(
            row == null
                ? TournamentStrings.COLUMN_GOAL_DIFFERENCE
                : _signed(row.goalDifference),
          ),
          SizedBox(
            width: 34 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                row == null ? TournamentStrings.COLUMN_POINTS : '${row.points}',
                maxLines: 1,
                style: style.copyWith(
                  color: header || highlighted ? color : KickoffColors.yellow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final _medalCount = TournamentStrings.MEDALS.length;

  static String _signed(int value) => value > 0 ? '+$value' : '$value';
}
