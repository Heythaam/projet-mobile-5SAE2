import 'package:flutter/material.dart';

import '../matches/football_match.dart';
import 'kickoff_style.dart';

enum MatchFilter { all, created, joined }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.matches,
    required this.loading,
    required this.loadError,
    required this.onRetry,
    super.key,
    this.initialHistory = false,
  });

  final List<FootballMatch> matches;
  final bool loading;
  final String? loadError;
  final VoidCallback onRetry;
  final bool initialHistory;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late bool _showHistory = widget.initialHistory;
  MatchFilter _filter = MatchFilter.all;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sortedMatches = widget.matches.toList()
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    final upcoming = sortedMatches
        .where(
          (match) =>
              !match.scheduledAt.isBefore(DateTime.now()) &&
              _matchesFilter(match),
        )
        .toList();
    final past = _showHistory
        ? sortedMatches
              .where(
                (match) =>
                    match.scheduledAt.isBefore(DateTime.now()) &&
                    _matchesFilter(match),
              )
              .toList()
        : const <FootballMatch>[];

    final scale = kickoffScale(context);
    return ArcadeBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 * scale, 10 * scale, 12 * scale, 0),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(bottom: 16 * scale),
                sliver: SliverList.list(
                  children: [
                    _MonthHeader(
                      date: _selectedDate,
                      onPrevious: () => setState(
                        () => _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month - 1,
                          1,
                        ),
                      ),
                      onNext: () => setState(
                        () => _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month + 1,
                          1,
                        ),
                      ),
                    ),
                    _WeekStrip(
                      selectedDate: _selectedDate,
                      matches: widget.matches,
                      onSelect: (date) => setState(() => _selectedDate = date),
                    ),
                    SizedBox(height: 6 * scale),
                    _FilterRow(
                      selected: _filter,
                      history: _showHistory,
                      onFilter: (filter) => setState(() => _filter = filter),
                      onHistory: () =>
                          setState(() => _showHistory = !_showHistory),
                    ),
                    if (widget.loading)
                      Padding(
                        padding: EdgeInsets.all(18 * scale),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 4 * scale,
                            color: KickoffColors.yellow,
                          ),
                        ),
                      )
                    else if (widget.loadError != null)
                      _CalendarError(
                        message: widget.loadError!,
                        onRetry: widget.onRetry,
                      )
                    else ...[
                      if (upcoming.isEmpty && past.isEmpty)
                        const _EmptyCalendar()
                      else ...[
                        for (final match in upcoming)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8 * scale),
                            child: _MatchRow(match: match),
                          ),
                        if (past.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 5 * scale),
                            child: _PastDivider(),
                          ),
                          for (final match in past)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8 * scale),
                              child: _MatchRow(match: match, past: true),
                            ),
                        ],
                        if (_showHistory && past.isEmpty)
                          const _NoPastMatches(),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(FootballMatch match) => switch (_filter) {
    MatchFilter.all => true,
    MatchFilter.created => match.participation == MatchParticipation.created,
    MatchFilter.joined => match.participation == MatchParticipation.joined,
  };
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            _month(date.month),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrevious,
          iconSize: 24 * kickoffScale(context),
          constraints: BoxConstraints(
            minWidth: 56 * kickoffScale(context),
            minHeight: 56 * kickoffScale(context),
          ),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: KickoffColors.muted,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          iconSize: 24 * kickoffScale(context),
          constraints: BoxConstraints(
            minWidth: 56 * kickoffScale(context),
            minHeight: 56 * kickoffScale(context),
          ),
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: KickoffColors.muted,
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDate,
    required this.matches,
    required this.onSelect,
  });

  final DateTime selectedDate;
  final List<FootballMatch> matches;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: _DayButton(
              date: start.add(Duration(days: index)),
              selectedDate: selectedDate,
              matches: matches,
              onTap: onSelect,
            ),
          ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selectedDate,
    required this.matches,
    required this.onTap,
  });

  final DateTime date;
  final DateTime selectedDate;
  final List<FootballMatch> matches;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final isSelected =
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;
    final hasMatch = matches.any(
      (match) =>
          match.scheduledAt.year == date.year &&
          match.scheduledAt.month == date.month &&
          match.scheduledAt.day == date.day,
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${_weekday(date.weekday)} ${date.day}',
      child: InkWell(
        onTap: () => onTap(date),
        borderRadius: BorderRadius.circular(20 * scale),
        child: SizedBox(
          height: 64 * scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekday(date.weekday).substring(0, 1),
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2 * scale),
              Container(
                width: 26 * scale,
                height: 26 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? KickoffColors.yellow : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isSelected ? KickoffColors.ink : Colors.white,
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 2 * scale),
              Container(
                width: 9 * scale,
                height: 9 * scale,
                decoration: BoxDecoration(
                  color: hasMatch ? KickoffColors.yellow : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.history,
    required this.onFilter,
    required this.onHistory,
  });

  final MatchFilter selected;
  final bool history;
  final ValueChanged<MatchFilter> onFilter;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final filter in MatchFilter.values) ...[
        RoundIconButton(
          icon: switch (filter) {
            MatchFilter.all => Icons.list_rounded,
            MatchFilter.created => Icons.workspace_premium_rounded,
            MatchFilter.joined => Icons.how_to_reg_rounded,
          },
          label: switch (filter) {
            MatchFilter.all => 'All matches',
            MatchFilter.created => 'Created matches',
            MatchFilter.joined => 'Joined matches',
          },
          selected: filter == selected,
          onPressed: () => onFilter(filter),
        ),
        SizedBox(width: 2 * kickoffScale(context)),
      ],
      const Spacer(),
      RoundIconButton(
        icon: Icons.history_rounded,
        label: history ? 'Hide past matches' : 'Show past matches',
        selected: history,
        onPressed: onHistory,
      ),
    ],
  );
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, this.past = false});

  final FootballMatch match;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final date = match.scheduledAt.toLocal();
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final textColor = past ? KickoffColors.muted : Colors.white;
    final bottomColor = past ? KickoffColors.panelDark : KickoffColors.blueDark;
    return Container(
      constraints: BoxConstraints(minHeight: 64 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 9 * scale,
      ),
      decoration: BoxDecoration(
        color: past ? KickoffColors.panel : KickoffColors.blue,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border(
          bottom: BorderSide(color: bottomColor, width: 4 * scale),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44 * scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    time,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _weekday(date.weekday),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  match.stadium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4 * scale),
                SlotDots(joined: match.joinedSlots, total: match.totalSlots),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          Icon(
            past
                ? Icons.check_circle_rounded
                : match.participation == MatchParticipation.created
                ? Icons.workspace_premium_rounded
                : Icons.how_to_reg_rounded,
            color: past
                ? KickoffColors.muted
                : match.participation == MatchParticipation.created
                ? KickoffColors.yellow
                : Colors.white,
            size: 24 * scale,
          ),
        ],
      ),
    );
  }
}

class _PastDivider extends StatelessWidget {
  const _PastDivider();

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      children: [
        const Expanded(child: Divider(color: KickoffColors.dim)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10 * scale),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: KickoffColors.dim,
                size: 16 * scale,
              ),
              SizedBox(width: 4 * scale),
              Text(
                'PAST',
                style: TextStyle(
                  color: KickoffColors.dim,
                  fontSize: 12 * scale,
                  letterSpacing: 2 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: Divider(color: KickoffColors.dim)),
      ],
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28 * scale),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 40 * scale,
            color: KickoffColors.dim,
          ),
          SizedBox(height: 8 * scale),
          Text(
            'No matches yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPastMatches extends StatelessWidget {
  const _NoPastMatches();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12 * kickoffScale(context)),
    child: Text(
      'No past matches',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: KickoffColors.dim,
        fontSize: 13 * kickoffScale(context),
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message,
          style: TextStyle(
            color: KickoffColors.muted,
            fontSize: 13 * kickoffScale(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      RoundIconButton(
        icon: Icons.refresh_rounded,
        label: 'Retry',
        onPressed: onRetry,
      ),
    ],
  );
}

String _month(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _weekday(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
