import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import '../../local/match_local_store.dart';
import '../../matches/match_controller.dart';
import '../../matches/stadium_directory.dart';
import 'match_mock_data.dart';
import 'match_widgets.dart';

const _stadiumCardRadius = 22.0;
const _stadiumBorderWidth = 4.0;
const _visibilityCardHeight = 170.0;

class StadiumPickScreen extends StatefulWidget {
  const StadiumPickScreen({required this.controller, super.key});

  final MatchController controller;

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
    widget.controller.loadStadiums();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _buildPick(context),
  );

  Widget _buildPick(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    body: SafeArea(
      child: Column(
        children: [
          _CreateStepHeader(
            current: 1,
            onBack: () => Navigator.of(context).pop(),
          ),
          if (!widget.controller.stadiumsLoading &&
              widget.controller.usingSampleStadiums)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Sample stadiums. Sign in and start the server to book real ones.',
                key: ValueKey('sample_stadiums_note'),
                textAlign: TextAlign.center,
                style: TextStyle(color: KickoffColors.muted, fontSize: 12),
              ),
            ),
          Expanded(
            child: widget.controller.stadiumsLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
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
              onPressed: _openingDate || widget.controller.stadiumsLoading
                  ? null
                  : _openDateStep,
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
          stadium: widget.controller.stadiums[_selectedIndex.clamp(
            0,
            widget.controller.stadiums.length - 1,
          )],
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

  final MatchController controller;
  final MatchStadiumData stadium;

  @override
  State<DateTimePickScreen> createState() => _DateTimePickScreenState();
}

class _DateTimePickScreenState extends State<DateTimePickScreen> {
  late DateTime _day;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  bool _openingVisibility = false;

  // Real stadiums: the free slots of the selected day come from the server.
  List<FreeSlot> _slots = const [];
  FreeSlot? _selectedSlot;
  bool _loadingSlots = false;
  String? _slotsError;

  bool get _real => widget.stadium.stadiumId != null;
  int get _minutes => _time.hour * 60 + _time.minute;

  @override
  void initState() {
    super.initState();
    _day = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    if (_real) _loadSlots();
  }

  Future<void> _loadSlots() async {
    final day = _day;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _selectedSlot = null;
      _slots = const [];
    });
    try {
      final slots = await widget.controller.freeSlots(widget.stadium, day);
      if (!mounted || day != _day) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } on StadiumDirectoryException catch (error) {
      if (!mounted || day != _day) return;
      setState(() {
        _slotsError = error.message;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted || day != _day) return;
      setState(() {
        _slotsError = 'Could not load the free slots.';
        _loadingSlots = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = DateUtils.dateOnly(picked));
    if (_real) _loadSlots();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _selectedSlot = null;
    });
  }

  bool get _inPast {
    final at = DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);
    return !at.isAfter(DateTime.now());
  }

  List<FreeSlot> get _pitchesAtTime =>
      _slots.where((slot) => slot.start == _minutes).toList();

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
                const Text(
                  'When?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _PickerTile(
                  key: const ValueKey('pick_date'),
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: _dateLabel(_day),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 10),
                _PickerTile(
                  key: const ValueKey('pick_time'),
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: _timeLabel(_time),
                  onTap: _pickTime,
                ),
                if (_inPast)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'That time has already passed. Pick a later one.',
                      key: ValueKey('past_time'),
                      style: TextStyle(color: KickoffColors.orange),
                    ),
                  ),
                if (_real) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Choose a pitch',
                    style: TextStyle(
                      color: KickoffColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _pitchSection(),
                ],
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
                      _inPast ||
                      (_real && _selectedSlot == null)
                  ? null
                  : _openVisibilityStep,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pitchSection() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_slotsError != null) {
      return Column(
        children: [
          Text(
            _slotsError!,
            key: const ValueKey('slots_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: KickoffColors.orange),
          ),
          TextButton(onPressed: _loadSlots, child: const Text('Try again')),
        ],
      );
    }
    if (_slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No free slots this day. Try another day.',
          key: ValueKey('no_slots'),
          textAlign: TextAlign.center,
          style: TextStyle(color: KickoffColors.muted),
        ),
      );
    }
    final pitches = _pitchesAtTime;
    if (pitches.isEmpty) {
      final times = {for (final slot in _slots) slot.startLabel}.toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No pitch is free at ${_timeLabel(_time)}. '
          'Free start times: ${times.join(', ')}.',
          key: const ValueKey('no_pitch_at_time'),
          style: const TextStyle(color: KickoffColors.muted),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in pitches)
          ChoiceChip(
            key: ValueKey('pitch_${slot.pitch.id}'),
            label: Text('${slot.pitch.name} · ${slot.pitch.size}'),
            selected: identical(_selectedSlot, slot),
            onSelected: (_) => setState(() => _selectedSlot = slot),
          ),
      ],
    );
  }

  static String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime day) =>
      '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1]} '
      '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';

  Future<void> _openVisibilityStep() async {
    if (_openingVisibility) return;
    final slot = _selectedSlot;
    if (_inPast || (_real && slot == null)) return;
    final time = slot != null
        ? TimeOfDay(hour: slot.start ~/ 60, minute: slot.start % 60)
        : _time;
    setState(() => _openingVisibility = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VisibilityScreen(
          controller: widget.controller,
          draft: CreateMatchDraft(
            stadium: widget.stadium,
            startsAt: DateTime(
              _day.year,
              _day.month,
              _day.day,
              time.hour,
              time.minute,
            ),
            visibility: 'Private',
            slot: slot,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingVisibility = false);
    if (result == true && mounted) Navigator.of(context).pop(true);
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KickoffColors.panel,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: KickoffColors.yellow),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: KickoffColors.muted, fontSize: 14),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: KickoffColors.muted),
          ],
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

  final MatchController controller;
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
    try {
      await widget.controller.createMatch(
        CreateMatchDraft(
          stadium: widget.draft.stadium,
          startsAt: widget.draft.startsAt,
          visibility: _visibility,
          slot: widget.draft.slot,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is LocalMatchException
                  ? error.message
                  : error is MatchBookingException
                  ? error.message
                  : 'Could not save the match on this phone.',
            ),
          ),
        );
      return;
    }
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
