import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import 'match_mock_data.dart';
import 'match_widgets.dart';

const _stadiumCardRadius = 22.0;
const _stadiumBorderWidth = 4.0;
const _visibilityCardHeight = 170.0;
const _matchTimes = 32;

class StadiumPickScreen extends StatefulWidget {
  const StadiumPickScreen({required this.controller, super.key});

  final MatchDemoController controller;

  @override
  State<StadiumPickScreen> createState() => _StadiumPickScreenState();
}

class _StadiumPickScreenState extends State<StadiumPickScreen> {
  late final PageController _pageController;
  int _selectedIndex = 0;
  bool _openingDate = false;
  bool _pageAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    body: SafeArea(
      child: Column(
        children: [
          _CreateStepHeader(
            current: 1,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = constraints.maxHeight.clamp(300.0, 390.0);
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          height: cardHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: widget.controller.stadiums.length,
                                onPageChanged: (index) =>
                                    setState(() => _selectedIndex = index),
                                itemBuilder: (context, index) {
                                  final stadium =
                                      widget.controller.stadiums[index];
                                  return AnimatedBuilder(
                                    animation: _pageController,
                                    builder: (context, child) {
                                      var page = _selectedIndex.toDouble();
                                      if (_pageController.hasClients &&
                                          _pageController
                                              .position
                                              .hasContentDimensions) {
                                        page =
                                            _pageController.page ??
                                            _selectedIndex.toDouble();
                                      }
                                      final distance = (page - index)
                                          .abs()
                                          .clamp(0.0, 1.0);
                                      return Opacity(
                                        opacity: 1 - distance * 0.2,
                                        child: Transform.scale(
                                          scale: 1 - distance * 0.08,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      child: _StadiumCard(stadium: stadium),
                                    ),
                                  );
                                },
                              ),
                              if (_selectedIndex > 0)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _CarouselArrow(
                                    icon: Icons.chevron_left_rounded,
                                    onTap: () => _changePage(-1),
                                  ),
                                ),
                              if (_selectedIndex <
                                  widget.controller.stadiums.length - 1)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _CarouselArrow(
                                    icon: Icons.chevron_right_rounded,
                                    onTap: () => _changePage(1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PagerDots(
                        count: widget.controller.stadiums.length,
                        selected: _selectedIndex,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ChunkyButton(
              label: 'Pick',
              icon: Icons.check_rounded,
              onPressed: _openingDate ? null : _openDateStep,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _openDateStep() async {
    if (_openingDate) return;
    setState(() => _openingDate = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DateTimePickScreen(
          controller: widget.controller,
          stadium: widget.controller.stadiums[_selectedIndex],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingDate = false);
    if (result == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _changePage(int direction) async {
    if (_pageAnimating) return;
    _pageAnimating = true;
    if (direction < 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    _pageAnimating = false;
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.stadium});

  final MatchStadiumData stadium;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: KickoffColors.blue,
      borderRadius: BorderRadius.circular(_stadiumCardRadius),
      border: Border.all(
        color: KickoffColors.yellow,
        width: _stadiumBorderWidth,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_stadiumCardRadius - 4),
      child: Column(
        children: [
          const Expanded(flex: 52, child: StadiumArt()),
          Expanded(
            flex: 48,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatChip(
                        icon: Icons.place_rounded,
                        label: stadium.distance,
                      ),
                      StatChip(
                        icon: Icons.monetization_on_rounded,
                        iconColor: KickoffColors.yellow,
                        label: '${stadium.coins}',
                      ),
                      StatChip(
                        icon: Icons.groups_rounded,
                        label: '${stadium.players}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = icon == Icons.chevron_left_rounded
        ? 'Previous stadium'
        : 'Next stadium';
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: KickoffColors.bg.withValues(alpha: 0.72),
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(icon, color: KickoffColors.dim, size: 30),
        ),
      ),
    );
  }
}

class _PagerDots extends StatelessWidget {
  const _PagerDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++) ...[
        if (index > 0) const SizedBox(width: 6),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == selected
                ? KickoffColors.yellow
                : Colors.transparent,
            border: index == selected
                ? null
                : Border.all(color: KickoffColors.dim, width: 1.5),
          ),
        ),
      ],
    ],
  );
}

class DateTimePickScreen extends StatefulWidget {
  const DateTimePickScreen({
    required this.controller,
    required this.stadium,
    super.key,
  });

  final MatchDemoController controller;
  final MatchStadiumData stadium;

  @override
  State<DateTimePickScreen> createState() => _DateTimePickScreenState();
}

class _DateTimePickScreenState extends State<DateTimePickScreen> {
  late final List<DateTime> _days;
  late DateTime? _selectedDay;
  TimeOfDay? _selectedTime;
  bool _openingVisibility = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _days = List.generate(14, (index) => today.add(Duration(days: index)));
    _selectedDay = _days[1];
    _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    body: SafeArea(
      child: Column(
        children: [
          _CreateStepHeader(
            current: 2,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: KickoffColors.yellow,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'When?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      final selected = DateUtils.isSameDay(day, _selectedDay);
                      return _DayChip(
                        date: day,
                        label: index == 0
                            ? 'Today'
                            : index == 1
                            ? 'Tomorrow'
                            : _weekday(day.weekday),
                        selected: selected,
                        onTap: () => _selectDay(day),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose a time',
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _matchTimes,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.65,
                  ),
                  itemBuilder: (context, index) {
                    final time = TimeOfDay(
                      hour: 8 + index ~/ 2,
                      minute: index.isEven ? 0 : 30,
                    );
                    final selected = _selectedTime == time;
                    final disabled = _isPastToday(time);
                    return _TimeChip(
                      time: time,
                      label: _timeLabel(time),
                      selected: selected,
                      disabled: disabled,
                      onTap: disabled
                          ? null
                          : () => setState(() => _selectedTime = time),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ChunkyButton(
              label: 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed:
                  _openingVisibility ||
                      _selectedDay == null ||
                      _selectedTime == null
                  ? null
                  : _openVisibilityStep,
            ),
          ),
        ],
      ),
    ),
  );

  bool _isPastToday(TimeOfDay time) {
    if (_selectedDay == null ||
        !DateUtils.isSameDay(_selectedDay, DateTime.now())) {
      return false;
    }
    final now = TimeOfDay.now();
    return time.hour < now.hour ||
        (time.hour == now.hour && time.minute <= now.minute);
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      if (_isPastToday(_selectedTime ?? TimeOfDay.now())) {
        _selectedTime = null;
      }
    });
  }

  static String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _openVisibilityStep() async {
    if (_openingVisibility) return;
    final day = _selectedDay;
    final time = _selectedTime;
    if (day == null || time == null) return;
    setState(() => _openingVisibility = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VisibilityScreen(
          controller: widget.controller,
          draft: CreateMatchDraft(
            stadium: widget.stadium,
            startsAt: DateTime(
              day.year,
              day.month,
              day.day,
              time.hour,
              time.minute,
            ),
            visibility: 'Private',
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingVisibility = false);
    if (result == true && mounted) Navigator.of(context).pop(true);
  }

  static String _weekday(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label ${date.day}',
    child: Material(
      color: selected ? KickoffColors.yellow : KickoffColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? KickoffColors.ink : KickoffColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? KickoffColors.ink : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final TimeOfDay time;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? KickoffColors.yellow : KickoffColors.panel,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        button: onTap != null,
        enabled: onTap != null,
        selected: selected,
        label: label,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: disabled
                    ? KickoffColors.dim
                    : selected
                    ? KickoffColors.ink
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class VisibilityScreen extends StatefulWidget {
  const VisibilityScreen({
    required this.controller,
    required this.draft,
    super.key,
  });

  final MatchDemoController controller;
  final CreateMatchDraft draft;

  @override
  State<VisibilityScreen> createState() => _VisibilityScreenState();
}

class _VisibilityScreenState extends State<VisibilityScreen> {
  String _visibility = 'Private';
  bool _creating = false;
  bool _allowCompletionPop = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_creating || _allowCompletionPop,
    child: Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _CreateStepHeader(
              current: _creating ? 4 : 3,
              onBack: () {
                if (!_creating) Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  _VisibilityCard(
                    label: 'Public',
                    icon: Icons.public_rounded,
                    selected: _visibility == 'Public',
                    onTap: () => setState(() => _visibility = 'Public'),
                  ),
                  const SizedBox(height: 12),
                  _VisibilityCard(
                    label: 'Private',
                    icon: Icons.lock_rounded,
                    selected: _visibility == 'Private',
                    onTap: () => setState(() => _visibility = 'Private'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _visibility == 'Public'
                        ? 'Anyone can find and join'
                        : 'Only people with your code can join',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: KickoffColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ChunkyButton(
                label: 'Create',
                icon: Icons.check_rounded,
                busy: _creating,
                onPressed: _createMatch,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _createMatch() async {
    if (_creating) return;
    setState(() => _creating = true);
    widget.controller.createMatch(
      CreateMatchDraft(
        stadium: widget.draft.stadium,
        startsAt: widget.draft.startsAt,
        visibility: _visibility,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _allowCompletionPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    height: _visibilityCardHeight,
    decoration: BoxDecoration(
      color: KickoffColors.blue,
      borderRadius: BorderRadius.circular(22),
      border: selected
          ? Border.all(color: KickoffColors.yellow, width: 4)
          : const Border(
              bottom: BorderSide(color: KickoffColors.blueDark, width: 6),
            ),
    ),
    child: Semantics(
      button: true,
      selected: selected,
      label: '$label visibility',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? KickoffColors.yellow : Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CreateStepHeader extends StatelessWidget {
  const _CreateStepHeader({required this.current, required this.onBack});

  final int current;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: KickoffColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: StepBar(current: current)),
      ],
    ),
  );
}
