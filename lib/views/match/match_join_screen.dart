import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location/player_location.dart';
import '../../items/kickoff_style.dart';
import 'match_create_screens.dart';
import 'match_lobby_screen.dart';
import '../../services/match/match_controller.dart';
import '../../entities/match/match_filter.dart';
import '../../entities/match/match_mock_data.dart';
import '../../items/match/match_widgets.dart';

const _joinCodeLength = 5;
const _publicListPadding = EdgeInsets.all(16);
const _allowedJoinCodeCharacters = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

class MatchJoinScreen extends StatefulWidget {
  const MatchJoinScreen({required this.controller, super.key});

  final MatchController controller;

  @override
  State<MatchJoinScreen> createState() => _MatchJoinScreenState();
}

class _MatchJoinScreenState extends State<MatchJoinScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  late final AnimationController _shakeController;
  int _tab = 0;
  bool _invalid = false;
  bool _joining = false;
  bool _creatingFromEmpty = false;
  Timer? _invalidTimer;

  String get _enteredCode => _codeController.text;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _codeController.addListener(_onCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tab == 0) _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _invalidTimer?.cancel();
    _shakeController.dispose();
    _codeController
      ..removeListener(_onCodeChanged)
      ..dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      backgroundColor: KickoffColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _tab == 0 ? _codeTab() : _publicTab()),
            _hiddenCodeField(),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Semantics(
            label: 'Back to Match Home',
            button: true,
            child: IconButton(
              tooltip: 'Back to Match Home',
              onPressed: _handleBack,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: KickoffColors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: PillToggle(selectedIndex: _tab, onChanged: _selectTab),
          ),
        ),
      ],
    ),
  );

  Widget _codeTab() => Column(
    children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final shift = _shakeController.isAnimating
                ? 8 *
                      (1 - _shakeController.value) *
                      ((_shakeController.value * 32).round().isEven ? 1 : -1)
                : 0.0;
            return Transform.translate(offset: Offset(shift, 0), child: child);
          },
          child: GestureDetector(
            onTap: _codeFocusNode.requestFocus,
            child: CodeBoxes(code: _enteredCode, invalid: _invalid),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ChunkyButton(
          label: 'Join',
          icon: Icons.login_rounded,
          onPressed: !_joining && _enteredCode.length == _joinCodeLength
              ? _joinByCode
              : null,
        ),
      ),
    ],
  );

  Widget _hiddenCodeField() => SizedBox(
    width: 1,
    height: 1,
    child: Opacity(
      opacity: 0,
      child: TextField(
        controller: _codeController,
        focusNode: _codeFocusNode,
        autofocus: false,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        maxLength: _joinCodeLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            final upper = newValue.text.toUpperCase();
            final filtered = upper
                .split('')
                .where(_allowedJoinCodeCharacters.contains)
                .take(_joinCodeLength)
                .join();
            return TextEditingValue(
              text: filtered,
              selection: TextSelection.collapsed(offset: filtered.length),
            );
          }),
        ],
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        showCursor: false,
        onSubmitted: (_) {
          if (_enteredCode.length == _joinCodeLength) _joinByCode();
        },
      ),
    ),
  );

  Widget _publicTab() => RefreshIndicator(
    onRefresh: () async {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() {});
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _publicListPadding,
      children: [
        _nearbyBar(),
        _filterBar(),
        if (widget.controller.publicMatches.isEmpty)
          SizedBox(
            height: 240,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.controller.filter.isEmpty
                      ? 'No public matches yet'
                      : 'No match fits these filters',
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _creatingFromEmpty ? null : _startCreateFromEmpty,
                  child: const Text('Create one'),
                ),
              ],
            ),
          )
        else
          for (final listing in widget.controller.publicMatches)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MatchRow(
                match: listing.match,
                timeLabel: listing.timeLabel,
                distanceKm: listing.distanceKm,
                onJoin: () => _joinPublicMatch(listing.match),
              ),
            ),
      ],
    ),
  );

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.filter.day ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      widget.controller.filter = widget.controller.filter.copyWith(day: picked);
    }
  }

  Future<void> _pickFromTime() async {
    final current = widget.controller.filter.fromMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (current ?? 18 * 60) ~/ 60,
        minute: (current ?? 18 * 60) % 60,
      ),
    );
    if (picked != null && mounted) {
      widget.controller.filter = widget.controller.filter.copyWith(
        fromMinute: picked.hour * 60 + picked.minute,
      );
    }
  }

  /// Narrows the public matches by date, part of the day and start time.
  Widget _filterBar() {
    final controller = widget.controller;
    final filter = controller.filter;
    String dayLabel(DateTime day) =>
        '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}';
    String timeLabel(int minute) =>
        '${(minute ~/ 60).toString().padLeft(2, '0')}:'
        '${(minute % 60).toString().padLeft(2, '0')}';
    return Container(
      key: const ValueKey('filter_card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: KickoffColors.yellow),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Filter matches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!filter.isEmpty)
                TextButton(
                  key: const ValueKey('filter_clear'),
                  onPressed: () => controller.filter = const MatchFilter(),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final part in DayPart.values)
                ChoiceChip(
                  key: ValueKey('filter_${part.name}'),
                  label: Text(part.label),
                  selected: filter.part == part,
                  onSelected: (on) => controller.filter = on
                      ? filter.copyWith(part: part)
                      : filter.copyWith(clearPart: true),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                key: const ValueKey('filter_day'),
                avatar: const Icon(Icons.event_rounded, size: 18),
                label: Text(
                  filter.day == null ? 'Any date' : dayLabel(filter.day!),
                ),
                onPressed: _pickDay,
              ),
              if (filter.day != null)
                ActionChip(
                  label: const Text('Any date'),
                  onPressed: () =>
                      controller.filter = filter.copyWith(clearDay: true),
                ),
              ActionChip(
                key: const ValueKey('filter_time'),
                avatar: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(
                  filter.fromMinute == null
                      ? 'Any time'
                      : 'From ${timeLabel(filter.fromMinute!)}',
                ),
                onPressed: _pickFromTime,
              ),
              if (filter.fromMinute != null)
                ActionChip(
                  label: const Text('Any time'),
                  onPressed: () => controller.filter = filter.copyWith(
                    clearFromMinute: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Offers to sort the public matches by distance. The location stays on the
  /// phone and is only asked for when the player taps the button.
  Widget _nearbyBar() {
    final controller = widget.controller;
    final status = controller.locationStatus;
    final sorted = controller.sortedByDistance;
    final blocked = status == LocationStatus.deniedForever;
    final message = sorted
        ? 'Showing the nearest matches first.'
        : switch (status) {
            LocationStatus.denied =>
              'Location permission was refused. Allow it to get suggestions.',
            LocationStatus.deniedForever =>
              'Location is blocked. Turn it on in the phone settings.',
            LocationStatus.serviceOff =>
              'Location is switched off on your phone. Switch it on, then retry.',
            LocationStatus.unavailable =>
              'Could not read your location. Try again.',
            _ => 'Turn on your location to get matches close to you first.',
          };
    final serviceOff = status == LocationStatus.serviceOff;
    final action = controller.locating
        ? 'Locating…'
        : serviceOff
        ? 'Turn on location'
        : blocked
        ? 'Open settings'
        : status == null
        ? 'Enable location'
        : 'Try again';
    return Container(
      key: const ValueKey('nearby_card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sorted ? Icons.near_me_rounded : Icons.location_off_rounded,
                color: sorted ? KickoffColors.yellow : KickoffColors.muted,
              ),
              const SizedBox(width: 8),
              const Text(
                'Matches near you',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: KickoffColors.muted, fontSize: 14),
          ),
          SwitchListTile(
            key: const ValueKey('location_switch'),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: KickoffColors.yellow,
            title: const Text(
              'Use my location',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Switch it off any time. Your position is never saved.',
              style: TextStyle(color: KickoffColors.muted, fontSize: 12),
            ),
            value: sorted || controller.locating,
            onChanged: controller.locating
                ? null
                : (on) {
                    if (on) {
                      controller.useMyLocation();
                    } else {
                      controller.stopUsingLocation();
                    }
                  },
          ),
          if (!sorted && (serviceOff || blocked))
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('enable_location'),
                style: FilledButton.styleFrom(
                  backgroundColor: KickoffColors.yellow,
                  foregroundColor: KickoffColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: serviceOff
                    ? Geolocator.openLocationSettings
                    : Geolocator.openAppSettings,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(action),
              ),
            ),
          if (!sorted && serviceOff)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('retry_location'),
                onPressed: controller.locating
                    ? null
                    : controller.useMyLocation,
                child: const Text('I turned it on, try again'),
              ),
            ),
        ],
      ),
    );
  }

  void _onCodeChanged() {
    if (!mounted) return;
    setState(() {
      _invalid = false;
      _joining = false;
    });
  }

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 0) {
      _codeFocusNode.requestFocus();
    } else {
      _codeFocusNode.unfocus();
    }
  }

  void _handleBack() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      _codeFocusNode.unfocus();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _joinByCode() async {
    if (_joining) return;
    _joining = true;
    final found = widget.controller.findMatchByCode(_enteredCode);
    if (found == null) {
      _showInvalidCode();
      return;
    }
    if (found.players >= found.capacity &&
        !widget.controller.hasJoined(found)) {
      _joining = false;
      _showMessage('This match is full');
      return;
    }
    final joined = widget.controller.hasJoined(found)
        ? found
        : await widget.controller.joinByCode(_enteredCode);
    if (!mounted) return;
    _finishJoin(joined);
  }

  Future<void> _joinPublicMatch(MatchHomeMatch match) async {
    if (_joining) return;
    _joining = true;
    final joined = await widget.controller.joinPublicMatch(match);
    if (!mounted) return;
    _finishJoin(joined);
  }

  void _finishJoin(MatchHomeMatch? joined) {
    if (joined != null) {
      _openLobby(joined);
      return;
    }
    _joining = false;
    _showMessage(
      widget.controller.lastError ?? 'Could not join this match',
    );
  }

  Future<void> _startCreateFromEmpty() async {
    if (_creatingFromEmpty) return;
    setState(() => _creatingFromEmpty = true);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StadiumPickScreen(controller: widget.controller),
      ),
    );
    final match = widget.controller.upcomingMatch;
    if (!mounted) return;
    setState(() => _creatingFromEmpty = false);
    if (created == true && match != null) _openLobby(match);
  }

  void _openLobby(MatchHomeMatch match) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchLobbyScreen(match: match, controller: widget.controller),
      ),
    );
  }

  void _showInvalidCode() {
    _invalidTimer?.cancel();
    setState(() => _invalid = true);
    _shakeController.forward(from: 0);
    _invalidTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _invalid = false;
          _joining = false;
        });
      }
    });
    _showMessage('No match with this code');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
