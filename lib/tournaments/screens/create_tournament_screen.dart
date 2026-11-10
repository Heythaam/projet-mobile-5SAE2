import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({
    required this.service,
    this.tournament,
    super.key,
  });

  final TournamentService service;

  /// When set, the screen edits this tournament instead of creating one.
  final Tournament? tournament;

  bool get isEditing => tournament != null;

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _prizeController;
  late TournamentFormat _format;
  late int _maxTeams;
  late int _teamSize;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.tournament;
    _nameController = TextEditingController(text: t?.name ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _locationController = TextEditingController(text: t?.location ?? '');
    _prizeController = TextEditingController(text: t?.prize ?? '');
    _format = t?.format ?? TournamentFormat.knockout;
    _maxTeams = t?.maxTeams ?? 8;
    _teamSize = t?.teamSize ?? 5;
    _startDate = t?.startDate ?? DateTime.now().add(const Duration(days: 7));
    _endDate = t?.endDate ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final name = TournamentFormRules.normalize(_nameController.text);
      final description =
          TournamentFormRules.normalize(_descriptionController.text);
      final location = TournamentFormRules.normalize(_locationController.text);
      final prize = TournamentFormRules.normalize(_prizeController.text);

      Tournament result;
      if (widget.isEditing) {
        result = await widget.service.editTournament(
          widget.tournament!.id,
          name: name,
          description: description,
          location: location,
          prize: prize.isEmpty ? null : prize,
          startDate: _dateString(_startDate),
          endDate: _dateString(_endDate),
        );
      } else {
        result = await widget.service.createTournament(
          name: name,
          format: _format.apiValue,
          startDate: _dateString(_startDate),
          endDate: _dateString(_endDate),
          maxTeams: _maxTeams,
          teamSize: _teamSize,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          prize: prize.isEmpty ? null : prize,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on TournamentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final isEditing = widget.isEditing;
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      appBar: AppBar(
        backgroundColor: KickoffColors.bg,
        foregroundColor: Colors.white,
        title: Text(
          isEditing
              ? TournamentStrings.EDIT_TOURNAMENT
              : TournamentStrings.CREATE_TOURNAMENT,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16 * scale),
          children: [
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(12 * scale),
                decoration: BoxDecoration(
                  color: TournamentColors.ERROR.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: TournamentColors.ERROR_TEXT,
                    fontSize: TournamentSizes.BODY * scale,
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
            ],
            _field(
              label: TournamentStrings.FIELD_NAME,
              controller: _nameController,
              validator: TournamentFormRules.validateName,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _field(
              label: TournamentStrings.FIELD_DESCRIPTION,
              controller: _descriptionController,
              validator: TournamentFormRules.validateDescription,
              maxLines: 3,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            if (!isEditing) ...[
              _dropdownField<TournamentFormat>(
                label: TournamentStrings.FIELD_FORMAT,
                value: _format,
                items: TournamentFormat.values,
                labelOf: (f) => f.label,
                onChanged: (value) => setState(() => _format = value!),
                scale: scale,
              ),
              SizedBox(height: 12 * scale),
              _dropdownField<int>(
                label: TournamentStrings.FIELD_MAX_TEAMS,
                value: _maxTeams,
                items: TournamentSizes.ALLOWED_MAX_TEAMS,
                labelOf: (v) => '$v',
                onChanged: (value) => setState(() => _maxTeams = value!),
                scale: scale,
              ),
              SizedBox(height: 12 * scale),
              _dropdownField<int>(
                label: TournamentStrings.FIELD_TEAM_SIZE,
                value: _teamSize,
                items: List.generate(
                  TournamentSizes.TEAM_SIZE_MAX,
                  (i) => i + TournamentSizes.TEAM_SIZE_MIN,
                ),
                labelOf: (v) => '$v',
                onChanged: (value) => setState(() => _teamSize = value!),
                scale: scale,
              ),
              SizedBox(height: 12 * scale),
            ],
            _dateField(
              label: TournamentStrings.FIELD_START_DATE,
              date: _startDate,
              onTap: () => _pickDate(isStart: true),
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _dateField(
              label: TournamentStrings.FIELD_END_DATE,
              date: _endDate,
              onTap: () => _pickDate(isStart: false),
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _field(
              label: TournamentStrings.FIELD_LOCATION,
              controller: _locationController,
              validator: TournamentFormRules.validateLocation,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _field(
              label: TournamentStrings.FIELD_PRIZE,
              controller: _prizeController,
              validator: TournamentFormRules.validatePrize,
              scale: scale,
            ),
            SizedBox(height: 24 * scale),
            SizedBox(
              height: TournamentSizes.MIN_TAP * scale,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KickoffColors.yellow,
                  foregroundColor: KickoffColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20 * scale,
                        height: 20 * scale,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing
                            ? TournamentStrings.SAVE
                            : TournamentStrings.CREATE,
                        style: TextStyle(
                          fontSize: TournamentSizes.CARD_TITLE * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? Function(String)? validator,
    int maxLines = 1,
    required double scale,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Colors.white, fontSize: TournamentSizes.BODY * scale),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: KickoffColors.muted),
          filled: true,
          fillColor: KickoffColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8 * scale),
            borderSide: BorderSide.none,
          ),
        ),
        validator: validator == null
            ? null
            : (value) => validator(value ?? ''),
      );

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
    required double scale,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(labelOf(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        style: TextStyle(color: Colors.white, fontSize: TournamentSizes.BODY * scale),
        dropdownColor: KickoffColors.panel,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: KickoffColors.muted),
          filled: true,
          fillColor: KickoffColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8 * scale),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required double scale,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: KickoffColors.muted),
            filled: true,
            fillColor: KickoffColors.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
              borderSide: BorderSide.none,
            ),
          ),
          child: Text(
            TournamentStrings.shortDate(date),
            style: TextStyle(
              color: Colors.white,
              fontSize: TournamentSizes.BODY * scale,
            ),
          ),
        ),
      );
}
