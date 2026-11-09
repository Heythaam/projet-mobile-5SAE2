import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models.dart';
import '../../screens/kickoff_style.dart';
import '../models/challenge_model.dart';
import '../models/team_model.dart';
import '../repository/challenge_repository.dart';
import '../widgets/star_rating.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({
    required this.repository,
    required this.user,
    this.initialChallenge,
    super.key,
  });

  final ChallengeRepository repository;
  final UserAccount user;
  final Challenge? initialChallenge;

  bool get isEditing => initialChallenge != null;

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  int _currentStep = 0; // 0: Type, 1: Format & Title, 2: Venue & Schedule, 3: Capacity & Rules, 4: Success

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxPlayersController = TextEditingController(text: '10');
  final _rulesNotesController = TextEditingController();

  ChallengeType _selectedType = ChallengeType.open;
  Team? _selectedTeam;
  List<Team> _teams = const [];
  bool _loadingTeams = true;

  int _difficulty = 3;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);

  String _gameFormat = '5v5';
  String _pitchType = 'Turf';
  String _skillLevel = 'All Levels';
  int _durationMinutes = 60;

  bool _submitting = false;
  Challenge? _createdChallenge;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final c = widget.initialChallenge!;
      _selectedType = c.type;
      _descriptionController.text = c.description;
      _locationController.text = c.locationName;
      _maxPlayersController.text = c.maxPlayers.toString();
      _difficulty = c.difficulty;
      _selectedDate = c.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(c.dateTime);
      _gameFormat = c.gameFormat;
      _pitchType = c.pitchType;
      _skillLevel = c.skillLevel;
      _durationMinutes = c.durationMinutes;
      _rulesNotesController.text = c.rulesNotes ?? '';
    }
    _loadTeams();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _maxPlayersController.dispose();
    _rulesNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await widget.repository.getLocalTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        if (widget.isEditing && widget.initialChallenge!.teamId != null) {
          _selectedTeam = teams.firstWhere(
            (t) => t.id == widget.initialChallenge!.teamId,
            orElse: () => teams.first,
          );
        } else if (teams.isNotEmpty) {
          _selectedTeam = teams.first;
        }
        _loadingTeams = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTeams = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: KickoffColors.yellow,
            onPrimary: KickoffColors.ink,
            surface: KickoffColors.panel,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: KickoffColors.yellow,
            onPrimary: KickoffColors.ink,
            surface: KickoffColors.panel,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedType == ChallengeType.team && _selectedTeam == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a team for team challenge')),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a description or title')),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location or stadium name')),
        );
        return;
      }
      setState(() => _currentStep = 3);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    final maxPlayers = int.tryParse(_maxPlayersController.text.trim()) ?? 0;
    if (maxPlayers < 2 || maxPlayers > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max players must be between 2 and 50')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (widget.isEditing) {
        final existing = widget.initialChallenge!;
        final updated = existing.copyWith(
          type: _selectedType,
          teamId: _selectedType == ChallengeType.team ? _selectedTeam?.id : null,
          teamName: _selectedType == ChallengeType.team ? _selectedTeam?.name : null,
          description: _descriptionController.text.trim(),
          difficulty: _difficulty,
          locationName: _locationController.text.trim(),
          dateTime: _selectedDate,
          maxPlayers: maxPlayers,
          gameFormat: _gameFormat,
          pitchType: _pitchType,
          skillLevel: _skillLevel,
          durationMinutes: _durationMinutes,
          rulesNotes: _rulesNotesController.text.trim(),
        );

        final success = await widget.repository.updateChallenge(updated);
        if (!mounted) return;
        setState(() => _submitting = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Challenge updated successfully!')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update challenge.')),
          );
        }
      } else {
        final joinCode = await widget.repository.generateUniqueJoinCode();

        final challenge = Challenge(
          type: _selectedType,
          teamId: _selectedType == ChallengeType.team ? _selectedTeam?.id : null,
          teamName: _selectedType == ChallengeType.team ? _selectedTeam?.name : null,
          description: _descriptionController.text.trim(),
          difficulty: _difficulty,
          locationName: _locationController.text.trim(),
          dateTime: _selectedDate,
          maxPlayers: maxPlayers,
          currentPlayers: 1,
          joinCode: joinCode,
          createdByUserId: widget.user.id,
          gameFormat: _gameFormat,
          pitchType: _pitchType,
          skillLevel: _skillLevel,
          durationMinutes: _durationMinutes,
          rulesNotes: _rulesNotesController.text.trim(),
        );

        final created = await widget.repository.createChallenge(challenge);

        if (!mounted) return;
        setState(() {
          _createdChallenge = created;
          _currentStep = 4; // Success view
          _submitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save challenge: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);

    final titles = [
      'Step 1: Challenge Type',
      'Step 2: Game Format & Title',
      'Step 3: Schedule & Venue',
      'Step 4: Capacity & Rules',
      'Challenge Ready!',
    ];

    return ArcadeBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: KickoffColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: KickoffColors.muted),
            onPressed: () {
              if (_currentStep > 0 && _currentStep < 4) {
                _prevStep();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.isEditing ? 'Edit Challenge' : titles[_currentStep],
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Step Progress Bar
              if (_currentStep < 4 && !widget.isEditing) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isActive = index <= _currentStep;
                      return Expanded(
                        child: Container(
                          height: 6 * scale,
                          margin: EdgeInsets.symmetric(horizontal: 3 * scale),
                          decoration: BoxDecoration(
                            color: isActive ? KickoffColors.yellow : KickoffColors.panelDark,
                            borderRadius: BorderRadius.circular(3 * scale),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16 * scale),
                  child: Form(
                    key: _formKey,
                    child: switch (_currentStep) {
                      0 => _buildStep1(scale),
                      1 => _buildStep2(scale),
                      2 => _buildStep3(scale),
                      3 => _buildStep4(scale),
                      _ => _buildSuccessView(scale),
                    },
                  ),
                ),
              ),

              // Bottom Navigation Controls
              if (_currentStep < 4) ...[
                Container(
                  padding: EdgeInsets.all(16 * scale),
                  color: KickoffColors.panelDark,
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: ChunkyButton(
                            label: 'Back',
                            icon: Icons.arrow_back_rounded,
                            backgroundColor: KickoffColors.panel,
                            bottomColor: KickoffColors.field,
                            foregroundColor: Colors.white,
                            onPressed: _prevStep,
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                      ],
                      Expanded(
                        child: ChunkyButton(
                          label: _currentStep == 3
                              ? (widget.isEditing ? 'Save Changes' : 'Create Challenge')
                              : 'Next',
                          icon: _currentStep == 3
                              ? Icons.flash_on_rounded
                              : Icons.arrow_forward_rounded,
                          backgroundColor: KickoffColors.yellow,
                          bottomColor: KickoffColors.yellowDark,
                          foregroundColor: KickoffColors.ink,
                          busy: _submitting,
                          onPressed: _submitting
                              ? null
                              : (_currentStep == 3 ? _submit : _nextStep),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Step 1: Challenge Type & Team
  Widget _buildStep1(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SELECT CHALLENGE TYPE',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12 * scale),

        Row(
          children: [
            Expanded(
              child: _TypeSelectionCard(
                title: 'Open Challenge',
                subtitle: 'Any player can join directly',
                icon: Icons.public_rounded,
                isSelected: _selectedType == ChallengeType.open,
                onTap: () => setState(() => _selectedType = ChallengeType.open),
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: _TypeSelectionCard(
                title: 'Team Challenge',
                subtitle: 'Linked to a local team',
                icon: Icons.groups_rounded,
                isSelected: _selectedType == ChallengeType.team,
                onTap: () => setState(() => _selectedType = ChallengeType.team),
              ),
            ),
          ],
        ),
        SizedBox(height: 20 * scale),

        if (_selectedType == ChallengeType.team) ...[
          Text(
            'Select Local Team',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          _loadingTeams
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(16 * scale),
                    border: Border.all(color: KickoffColors.ink, width: 2 * scale),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Team>(
                      value: _selectedTeam,
                      isExpanded: true,
                      dropdownColor: KickoffColors.panel,
                      icon: const Icon(Icons.arrow_drop_down, color: KickoffColors.yellow),
                      style: TextStyle(color: Colors.white, fontSize: 15 * scale),
                      items: _teams
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_rounded,
                                        color: KickoffColors.yellow, size: 20 * scale),
                                    SizedBox(width: 8 * scale),
                                    Text(t.name),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTeam = val);
                      },
                    ),
                  ),
                ),
        ],
      ],
    );
  }

  // Step 2: Format & Description
  Widget _buildStep2(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillField(
          controller: _descriptionController,
          hint: 'Challenge Title (e.g. 5v5 Sunset Battle)',
          icon: Icons.description_rounded,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        SizedBox(height: 16 * scale),

        Text(
          'GAME FORMAT',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        Row(
          children: ['5v5', '7v7', '11v11'].map((format) {
            final isSel = _gameFormat == format;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gameFormat = format),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? KickoffColors.yellow : KickoffColors.field,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Text(
                    format,
                    style: TextStyle(
                      color: isSel ? KickoffColors.ink : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15 * scale,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16 * scale),

        Text(
          'SKILL LEVEL',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: ['All Levels', 'Beginner', 'Intermediate', 'Advanced'].map((level) {
            final isSel = _skillLevel == level;
            return ChoiceChip(
              label: Text(level),
              selected: isSel,
              selectedColor: KickoffColors.yellow,
              backgroundColor: KickoffColors.field,
              labelStyle: TextStyle(
                color: isSel ? KickoffColors.ink : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _skillLevel = level),
            );
          }).toList(),
        ),
        SizedBox(height: 16 * scale),

        // Difficulty star rating
        Container(
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: KickoffColors.panel,
            borderRadius: BorderRadius.circular(16 * scale),
          ),
          child: Row(
            children: [
              Icon(Icons.military_tech_rounded,
                  color: KickoffColors.yellow, size: 22 * scale),
              SizedBox(width: 8 * scale),
              Text(
                'Difficulty:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              StarRating(
                rating: _difficulty,
                onChanged: (val) => setState(() => _difficulty = val),
                size: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Venue & Schedule
  Widget _buildStep3(double scale) {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillField(
          controller: _locationController,
          hint: 'Location / Pitch Name (e.g. Arena Pitch 2)',
          icon: Icons.location_on_rounded,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        SizedBox(height: 16 * scale),

        Text(
          'PITCH TYPE',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: ['Turf', 'Natural Grass', 'Indoor', 'Concrete'].map((pitch) {
            final isSel = _pitchType == pitch;
            return ChoiceChip(
              label: Text(pitch),
              selected: isSel,
              selectedColor: KickoffColors.yellow,
              backgroundColor: KickoffColors.field,
              labelStyle: TextStyle(
                color: isSel ? KickoffColors.ink : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _pitchType = pitch),
            );
          }).toList(),
        ),
        SizedBox(height: 16 * scale),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 52 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(26 * scale),
                    border: Border.all(color: KickoffColors.ink, width: 2 * scale),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: KickoffColors.yellow, size: 20 * scale),
                      SizedBox(width: 6 * scale),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: GestureDetector(
                onTap: _pickTime,
                child: Container(
                  height: 52 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(26 * scale),
                    border: Border.all(color: KickoffColors.ink, width: 2 * scale),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: KickoffColors.yellow, size: 20 * scale),
                      SizedBox(width: 6 * scale),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16 * scale),

        Text(
          'MATCH DURATION',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        Row(
          children: [60, 90, 120].map((dur) {
            final isSel = _durationMinutes == dur;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _durationMinutes = dur),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? KickoffColors.yellow : KickoffColors.field,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Text(
                    '$dur min',
                    style: TextStyle(
                      color: isSel ? KickoffColors.ink : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * scale,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Step 4: Capacity & Special Rules
  Widget _buildStep4(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillField(
          controller: _maxPlayersController,
          hint: 'Max Players Slot Capacity (e.g. 10)',
          icon: Icons.people_rounded,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = int.tryParse(v.trim());
            if (n == null || n < 2 || n > 50) return 'Enter 2 to 50 players';
            return null;
          },
        ),
        SizedBox(height: 16 * scale),

        Text(
          'SPECIAL RULES / NOTES (OPTIONAL)',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        TextFormField(
          controller: _rulesNotesController,
          maxLines: 4,
          style: TextStyle(color: Colors.white, fontSize: 14 * scale),
          decoration: InputDecoration(
            hintText: 'e.g. Bring light/dark jerseys, no metal studs...',
            hintStyle: TextStyle(color: KickoffColors.muted, fontSize: 14 * scale),
            filled: true,
            fillColor: KickoffColors.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16 * scale),
              borderSide: BorderSide(color: KickoffColors.ink, width: 2 * scale),
            ),
          ),
        ),
      ],
    );
  }

  // Step 5: Success Summary
  Widget _buildSuccessView(double scale) {
    final challenge = _createdChallenge!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16 * scale),
          decoration: BoxDecoration(
            color: KickoffColors.blue,
            borderRadius: BorderRadius.circular(20 * scale),
            border: Border(
              bottom: BorderSide(color: KickoffColors.blueDark, width: 5 * scale),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 56 * scale,
                color: KickoffColors.yellow,
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Challenge Ready!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Share your Join Code with friends',
                style: TextStyle(color: KickoffColors.muted, fontSize: 14 * scale),
              ),
              SizedBox(height: 16 * scale),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 12 * scale,
                ),
                decoration: BoxDecoration(
                  color: KickoffColors.ink,
                  borderRadius: BorderRadius.circular(14 * scale),
                  border: Border.all(color: KickoffColors.yellow, width: 2 * scale),
                ),
                child: Text(
                  challenge.joinCode,
                  style: TextStyle(
                    color: KickoffColors.yellow,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3 * scale,
                  ),
                ),
              ),
              SizedBox(height: 14 * scale),

              ChunkyButton(
                label: 'Copy Code',
                icon: Icons.copy_rounded,
                backgroundColor: KickoffColors.yellow,
                bottomColor: KickoffColors.yellowDark,
                foregroundColor: KickoffColors.ink,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: challenge.joinCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Join Code ${challenge.joinCode} copied!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 20 * scale),

        Text(
          'SUMMARY',
          style: TextStyle(
            color: KickoffColors.dim,
            fontSize: 13 * scale,
            letterSpacing: 1.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8 * scale),

        Container(
          padding: EdgeInsets.all(16 * scale),
          decoration: BoxDecoration(
            color: KickoffColors.panel,
            borderRadius: BorderRadius.circular(16 * scale),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.description,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text('Format: ${challenge.gameFormat} | ${challenge.pitchType}',
                  style: TextStyle(color: KickoffColors.muted, fontSize: 13 * scale)),
              Text('Location: ${challenge.locationName}',
                  style: TextStyle(color: KickoffColors.muted, fontSize: 13 * scale)),
              Text('Skill: ${challenge.skillLevel} | Duration: ${challenge.durationMinutes} min',
                  style: TextStyle(color: KickoffColors.muted, fontSize: 13 * scale)),
            ],
          ),
        ),
        SizedBox(height: 24 * scale),

        ChunkyButton(
          label: 'Done',
          icon: Icons.check_rounded,
          backgroundColor: KickoffColors.blue,
          bottomColor: KickoffColors.blueDark,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _TypeSelectionCard extends StatelessWidget {
  const _TypeSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: isSelected ? KickoffColors.panel : KickoffColors.panelDark,
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(
            color: isSelected ? KickoffColors.yellow : Colors.transparent,
            width: 2 * scale,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28 * scale,
              color: isSelected ? KickoffColors.yellow : KickoffColors.muted,
            ),
            SizedBox(height: 6 * scale),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2 * scale),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: 11 * scale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
