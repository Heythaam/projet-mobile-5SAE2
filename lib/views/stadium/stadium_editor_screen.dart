import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entities/stadium/stadium.dart';
import '../../entities/user/dial_codes.dart';
import '../../items/kickoff_style.dart';
import '../../items/maps/pick_on_map_button.dart';
import '../../items/stadium/stadium_icons.dart';
import '../../items/stadium/stadium_widgets.dart';
import '../../services/stadium/stadium_api.dart';

class StadiumEditorScreen extends StatefulWidget {
  const StadiumEditorScreen({required this.api, this.stadium, super.key});

  final StadiumApi api;

  /// The stadium to edit, or null to add a new one.
  final Stadium? stadium;

  @override
  State<StadiumEditorScreen> createState() => _StadiumEditorScreenState();
}

class _StadiumEditorScreenState extends State<StadiumEditorScreen> {
  late final StadiumDraft _draft = widget.stadium == null
      ? StadiumDraft()
      : StadiumDraft.from(widget.stadium!);
  late final _name = TextEditingController(text: _draft.name);
  late DialCode _dial = splitPhone(_draft.phone).dial;
  late final _phone = TextEditingController(
    text: splitPhone(_draft.phone).digits,
  );
  late final _address = TextEditingController(text: _draft.address);
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _busy = false;
  String? _stepError;

  bool get _editing => widget.stadium != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step -= 1;
        _stepError = null;
      });
    }
  }

  Future<void> _pickDial() async {
    final picked = await showModalBottomSheet<DialCode>(
      context: context,
      backgroundColor: KickoffColors.panel,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final dial in dialCodes)
              ListTile(
                key: ValueKey('dial_${dial.code}_${dial.country}'),
                title: Text(
                  dial.country,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  dial.code,
                  style: const TextStyle(
                    color: KickoffColors.yellow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(dial),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dial = picked;
      final digits = _phone.text;
      if (digits.length > picked.maxDigits) {
        _phone.text = digits.substring(0, picked.maxDigits);
      }
    });
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _draft
        ..name = _name.text
        ..phone = '${_dial.code} ${_phone.text.trim()}'
        ..address = _address.text;
    }
    if (_step == 2) {
      final error = _hoursError();
      if (error != null) {
        setState(() => _stepError = error);
        return;
      }
      await _submit();
      return;
    }
    setState(() {
      _step += 1;
      _stepError = null;
    });
  }

  String? _hoursError() {
    if (_draft.openDays == 0) return 'Pick at least one open day.';
    if (_draft.slotsPerDay == 0) {
      return 'Opening hours must fit at least one '
          '${stadiumSlotLabel(_draft.slotMinutes)} slot.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      final saved = _editing
          ? await widget.api.update(widget.stadium!.id, _draft)
          : await widget.api.create(_draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = stadiumMessage(error);
      });
    }
  }

  Future<void> _editPitch(int? index) async {
    final pitch = index == null
        ? const Pitch(size: '5v5', surface: 'turf')
        : _draft.pitches[index];
    final result = await showModalBottomSheet<_PitchEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: stadiumSheetShape(context),
      builder: (_) => _PitchSheet(
        pitch: pitch,
        letter: String.fromCharCode(65 + (index ?? _draft.pitches.length)),
        canRemove: index != null && _draft.pitches.length > 1,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.remove) {
        _draft.pitches.removeAt(index!);
      } else if (index == null) {
        _draft.pitches.add(result.pitch);
      } else {
        _draft.pitches[index] = result.pitch;
      }
      _draft.pitches = [
        for (final (i, p) in _draft.pitches.indexed)
          p.copyWith(name: String.fromCharCode(65 + i)),
      ];
    });
  }

  Future<void> _pickTime({required bool opening}) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: stadiumSheetShape(context),
      builder: (_) => _TimeSheet(
        title: opening ? 'Opens at' : 'Closes at',
        selected: opening ? _draft.openMinute : _draft.closeMinute,
        first: opening ? 0 : 30,
        last: opening ? 23 * 60 + 30 : 24 * 60,
      ),
    );
    if (value == null) return;
    setState(() {
      if (opening) {
        _draft.openMinute = value;
      } else {
        _draft.closeMinute = value;
      }
      _stepError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: StadiumPage(
        title: _editing ? 'Edit stadium' : 'Add stadium',
        onBack: _back,
        header: Padding(
          padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 8 * scale),
          child: StadiumProgress(step: _step, total: 3),
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stepError != null) ...[
              StadiumBanner(
                icon: Icons.error_outline_rounded,
                text: _stepError!,
                error: true,
              ),
              SizedBox(height: 10 * scale),
            ],
            ChunkyButton(
              key: const ValueKey('stadium_next'),
              label: _step < 2
                  ? 'Next'
                  : _editing
                  ? 'Save changes'
                  : 'Publish stadium',
              icon: _step < 2
                  ? Icons.arrow_forward_rounded
                  : Icons.check_rounded,
              busy: _busy,
              onPressed: _busy ? null : _next,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _basicsStep(scale),
              1 => _pitchesStep(scale),
              _ => _hoursStep(scale),
            },
          ),
        ),
      ),
    );
  }

  Widget _basicsStep(double scale) => Form(
    key: _formKey,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        8 * scale,
        16 * scale,
        16 * scale,
      ),
      children: [
        StadiumStepTitle(
          title: 'Your stadium',
          subtitle: 'Players see this when they pick where to play.',
        ),
        SizedBox(height: 14 * scale),
        PillField(
          key: const ValueKey('stadium_name'),
          controller: _name,
          hint: 'Stadium name',
          icon: Icons.stadium_rounded,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 2 || text.length > 40) {
              return 'Use 2-40 characters.';
            }
            return null;
          },
        ),
        SizedBox(height: 12 * scale),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: InkWell(
                key: const ValueKey('stadium_dial'),
                borderRadius: BorderRadius.circular(30 * scale),
                onTap: _pickDial,
                child: Container(
                  height: 52 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.panel,
                    borderRadius: BorderRadius.circular(30 * scale),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dial.code,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: KickoffColors.yellow,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: PillField(
                key: const ValueKey('stadium_phone'),
                controller: _phone,
                hint: 'Contact number',
                icon: Icons.call_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_dial.maxDigits),
                ],
                validator: (value) {
                  final digits = value?.trim() ?? '';
                  return digits.length >= _dial.minDigits &&
                          digits.length <= _dial.maxDigits
                      ? null
                      : _dial.exactDigits != null
                      ? '${_dial.code} numbers have ${_dial.exactDigits} digits.'
                      : 'Enter a valid phone number.';
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        PillField(
          key: const ValueKey('stadium_address'),
          controller: _address,
          hint: 'Address or area',
          icon: Icons.place_rounded,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 3 || text.length > 80) {
              return 'Use 3-80 characters.';
            }
            return null;
          },
        ),
        PickOnMapButton(
          title: 'Where is the stadium?',
          onPicked: (place) => setState(() => _address.text = place.label),
        ),
      ],
    ),
  );

  Widget _pitchesStep(double scale) => ListView(
    padding: EdgeInsets.fromLTRB(16 * scale, 8 * scale, 16 * scale, 16 * scale),
    children: [
      StadiumStepTitle(
        title: 'Pitches',
        subtitle: 'Each pitch can be booked on its own.',
      ),
      SizedBox(height: 12 * scale),
      for (final (index, pitch) in _draft.pitches.indexed) ...[
        StadiumChunkyTile(
          color: KickoffColors.blue,
          edge: KickoffColors.blueDark,
          onTap: () => _editPitch(index),
          semanticLabel: 'Edit pitch ${pitch.name}',
          padding: EdgeInsets.all(10 * scale),
          child: Row(
            children: [
              StadiumIconSquare(letter: pitch.name, color: StadiumColors.green),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pitch ${pitch.name}',
                      style: stadiumText(scale, 17, weight: FontWeight.w600),
                    ),
                    SizedBox(height: 2 * scale),
                    Row(
                      children: [
                        Text(pitch.size, style: stadiumText(scale, 14)),
                        SizedBox(width: 10 * scale),
                        Flexible(
                          child: StadiumIconText(
                            icon: stadiumSurfaceIcons[pitch.surface]!,
                            text: pitch.surfaceLabel,
                            color: KickoffColors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: Colors.white, size: 22 * scale),
            ],
          ),
        ),
        SizedBox(height: 10 * scale),
      ],
      if (_draft.pitches.length < stadiumMaxPitches)
        StadiumDashedAdd(
          key: const ValueKey('stadium_add_pitch'),
          label: 'Add pitch',
          onTap: () => _editPitch(null),
        ),
      SizedBox(height: 22 * scale),
      StadiumStepTitle(title: 'Features', subtitle: 'What players get on site.'),
      SizedBox(height: 12 * scale),
      Row(
        children: [
          for (final (index, entry) in stadiumFeatures.entries.indexed) ...[
            if (index > 0) SizedBox(width: 8 * scale),
            Expanded(
              child: StadiumFeatureTile(
                label: entry.value,
                icon: stadiumFeatureIcons[entry.key]!,
                selected: _draft.features.contains(entry.key),
                onTap: () => setState(() {
                  if (!_draft.features.remove(entry.key)) {
                    _draft.features.add(entry.key);
                  }
                }),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _hoursStep(double scale) {
    final eveningPrice =
        (_draft.pricePerHour * (1 + _draft.eveningSurcharge / 100)).round();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        8 * scale,
        16 * scale,
        16 * scale,
      ),
      children: [
        StadiumStepTitle(
          title: 'Open days',
          subtitle: 'Tap a day to open or close it.',
        ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            for (var day = 0; day < 7; day++) ...[
              if (day > 0) SizedBox(width: 6 * scale),
              Expanded(
                child: StadiumDayToggle(
                  letter: stadiumDayLetters[day],
                  name: stadiumDayFullNames[day],
                  selected: _draft.openDays & (1 << day) != 0,
                  onTap: () => setState(() {
                    _draft.openDays ^= 1 << day;
                    _stepError = null;
                  }),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 20 * scale),
        StadiumStepTitle(title: 'Opening hours'),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            Expanded(
              child: StadiumTimeButton(
                label: 'Opens',
                value: stadiumTime(_draft.openMinute),
                onTap: () => _pickTime(opening: true),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: KickoffColors.muted,
                size: 22 * scale,
              ),
            ),
            Expanded(
              child: StadiumTimeButton(
                label: 'Closes',
                value: stadiumTime(_draft.closeMinute),
                onTap: () => _pickTime(opening: false),
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              color: KickoffColors.yellow,
              size: 22 * scale,
            ),
            SizedBox(width: 10 * scale),
            for (final length in stadiumSlotChoices) ...[
              StadiumPill(
                label: stadiumSlotLabel(length),
                selected: _draft.slotMinutes == length,
                onTap: () => setState(() {
                  _draft.slotMinutes = length;
                  _stepError = null;
                }),
              ),
              SizedBox(width: 8 * scale),
            ],
          ],
        ),
        SizedBox(height: 20 * scale),
        StadiumStepTitle(title: 'Price'),
        SizedBox(height: 10 * scale),
        StadiumPanel(
          child: Row(
            children: [
              StadiumRoundAction(
                icon: Icons.remove_rounded,
                label: 'Lower price',
                onTap: _draft.pricePerHour > 5
                    ? () => setState(() => _draft.pricePerHour -= 5)
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: KickoffColors.yellow,
                          size: 24 * scale,
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          '${_draft.pricePerHour}',
                          key: const ValueKey('stadium_price'),
                          style: stadiumText(scale, 28, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      'per hour',
                      style: stadiumText(scale, 13, color: KickoffColors.muted),
                    ),
                  ],
                ),
              ),
              StadiumRoundAction(
                icon: Icons.add_rounded,
                label: 'Raise price',
                onTap: _draft.pricePerHour < 10000
                    ? () => setState(() => _draft.pricePerHour += 5)
                    : null,
              ),
            ],
          ),
        ),
        SizedBox(height: 10 * scale),
        StadiumPanel(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    color: KickoffColors.yellow,
                    size: 24 * scale,
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      _draft.eveningSurcharge == 0
                          ? 'Evening surcharge'
                          : '+${_draft.eveningSurcharge}% after 20:00',
                      style: stadiumText(scale, 16, weight: FontWeight.w600),
                    ),
                  ),
                  StadiumKickoffSwitch(
                    label: 'Evening surcharge',
                    value: _draft.eveningSurcharge > 0,
                    onChanged: (on) =>
                        setState(() => _draft.eveningSurcharge = on ? 20 : 0),
                  ),
                ],
              ),
              if (_draft.eveningSurcharge > 0) ...[
                SizedBox(height: 8 * scale),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Evening slots cost $eveningPrice per hour',
                        style: stadiumText(scale, 14, color: KickoffColors.muted),
                      ),
                    ),
                    StadiumRoundAction(
                      icon: Icons.remove_rounded,
                      label: 'Lower surcharge',
                      small: true,
                      onTap: _draft.eveningSurcharge > 5
                          ? () => setState(() => _draft.eveningSurcharge -= 5)
                          : null,
                    ),
                    SizedBox(width: 6 * scale),
                    StadiumRoundAction(
                      icon: Icons.add_rounded,
                      label: 'Raise surcharge',
                      small: true,
                      onTap: _draft.eveningSurcharge < 100
                          ? () => setState(() => _draft.eveningSurcharge += 5)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 14 * scale),
        Text(
          _draft.slotsPerDay == 0
              ? 'No slot fits these hours yet.'
              : '${_draft.slotsPerDay} slots a day on each pitch · '
                    '${_draft.pitches.length} '
                    '${_draft.pitches.length == 1 ? 'pitch' : 'pitches'}',
          textAlign: TextAlign.center,
          style: stadiumText(scale, 14, color: KickoffColors.muted),
        ),
      ],
    );
  }
}

class _PitchEdit {
  const _PitchEdit(this.pitch, {this.remove = false});

  final Pitch pitch;
  final bool remove;
}

class _PitchSheet extends StatefulWidget {
  const _PitchSheet({
    required this.pitch,
    required this.letter,
    required this.canRemove,
  });

  final Pitch pitch;
  final String letter;
  final bool canRemove;

  @override
  State<_PitchSheet> createState() => _PitchSheetState();
}

class _PitchSheetState extends State<_PitchSheet> {
  late String _size = widget.pitch.size;
  late String _surface = widget.pitch.surface;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return StadiumSheetBody(
      title: 'Pitch ${widget.letter}',
      children: [
        Text('Size', style: stadiumText(scale, 14, color: KickoffColors.muted)),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            for (final size in stadiumPitchSizes)
              StadiumPill(
                label: size,
                selected: _size == size,
                onTap: () => setState(() => _size = size),
              ),
          ],
        ),
        SizedBox(height: 16 * scale),
        Text('Surface', style: stadiumText(scale, 14, color: KickoffColors.muted)),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            for (final entry in stadiumSurfaces.entries)
              StadiumPill(
                label: entry.value,
                icon: stadiumSurfaceIcons[entry.key]!,
                selected: _surface == entry.key,
                onTap: () => setState(() => _surface = entry.key),
              ),
          ],
        ),
        SizedBox(height: 20 * scale),
        ChunkyButton(
          key: const ValueKey('pitch_save'),
          label: 'Save pitch',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(
            _PitchEdit(widget.pitch.copyWith(size: _size, surface: _surface)),
          ),
        ),
        if (widget.canRemove) ...[
          SizedBox(height: 8 * scale),
          StadiumTextAction(
            label: 'Remove pitch',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFFFB7AB),
            onTap: () =>
                Navigator.of(context)
                    .pop(_PitchEdit(widget.pitch, remove: true)),
          ),
        ],
      ],
    );
  }
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet({
    required this.title,
    required this.selected,
    required this.first,
    required this.last,
  });

  final String title;
  final int selected;
  final int first;
  final int last;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final times = [for (var m = first; m <= last; m += 30) m];
    return StadiumSheetBody(
      title: title,
      maxHeightFactor: 0.7,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8 * scale,
          crossAxisSpacing: 8 * scale,
          childAspectRatio: 1.6,
          children: [
            for (final minute in times)
              StadiumPill(
                label: stadiumTime(minute),
                selected: minute == selected,
                expand: true,
                onTap: () => Navigator.of(context).pop(minute),
              ),
          ],
        ),
      ],
    );
  }
}
