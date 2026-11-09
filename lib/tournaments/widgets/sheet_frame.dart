import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../tournament_constants.dart';
import 'tournament_states.dart';

/// Opens a tall tournament sheet that resolves to a value chosen by the
/// sheet itself (see [TournamentSheetFrame.onClose]).
Future<T?> showTournamentSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final scale = kickoffScale(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KickoffColors.panelDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TournamentSizes.SHEET_RADIUS * scale),
      ),
    ),
    builder: builder,
  );
}

/// Title bar, optional notice and body for tall tournament sheets.
///
/// Every way of closing (Close button, Back, barrier tap) calls [onClose], so
/// the sheet can return its result, for example whether data changed.
class TournamentSheetFrame extends StatelessWidget {
  const TournamentSheetFrame({
    required this.title,
    required this.onClose,
    required this.child,
    this.notice,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  /// A short success message shown under the title.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final notice = this.notice;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: SafeArea(
        child: SizedBox(
          height:
              MediaQuery.sizeOf(context).height * TournamentSizes.SHEET_HEIGHT,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  TournamentSizes.CARD_PADDING * scale,
                  8 * scale,
                  4 * scale,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TournamentIconButton(
                      icon: Icons.close_rounded,
                      tooltip: TournamentStrings.CLOSE,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              if (notice != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: TournamentSizes.CARD_PADDING * scale,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      notice,
                      style: TextStyle(
                        color: TournamentColors.SUCCESS_TEXT,
                        fontSize: TournamentSizes.CAPTION * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled number in a stats grid.
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: TournamentSizes.CARD_TITLE * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: TournamentSizes.CAPTION * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// [StatTile]s two per row, so values stay readable at large text sizes.
class StatGrid extends StatelessWidget {
  const StatGrid({required this.tiles, super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    final spacing = 8 * kickoffScale(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// A small heading between sheet sections.
class SheetSectionTitle extends StatelessWidget {
  const SheetSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(top: 16 * scale, bottom: 8 * scale),
      child: Text(
        text,
        style: TextStyle(
          color: KickoffColors.muted,
          fontSize: TournamentSizes.BODY * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
