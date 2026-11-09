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
    super.key,
  });

  final ChallengeRepository repository;
  final UserAccount user;

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxPlayersController = TextEditingController(text: '10');

  ChallengeType _selectedType = ChallengeType.open;
  Team? _selectedTeam;
  List<Team> _teams = const [];
  bool _loadingTeams = true;

  int _difficulty = 3;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);

  bool _submitting = false;
  Challenge? _createdChallenge;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _maxPlayersController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await widget.repository.getLocalTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        if (teams.isNotEmpty) {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == ChallengeType.team && _selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team for team challenge')),
      );
      return;
    }

    final maxPlayers = int.tryParse(_maxPlayersController.text.trim()) ?? 0;
    if (maxPlayers < 2 || maxPlayers > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max players must be between 2 and 50')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
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
        currentPlayers: 1, // creator is the first player
        joinCode: joinCode,
        createdByUserId: widget.user.id,
      );

      final created = await widget.repository.createChallenge(challenge);

      if (!mounted) return;
      setState(() {
        _createdChallenge = created;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create challenge: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);

    return ArcadeBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: KickoffColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: KickoffColors.muted),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _createdChallenge != null ? 'Challenge Created' : 'Create Challenge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16 * scale),
            child: _createdChallenge != null
                ? _buildSuccessView(scale)
                : _buildFormView(scale),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(double scale) {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step A: Challenge Type
          Text(
            '1. CHALLENGE TYPE',
            style: TextStyle(
              color: KickoffColors.dim,
              fontSize: 13 * scale,
              letterSpacing: 1.5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),

          Row(
            children: [
              Expanded(
                child: _TypeSelectionCard(
                  title: 'Open Challenge',
                  subtitle: 'Any player can join',
                  icon: Icons.public_rounded,
                  isSelected: _selectedType == ChallengeType.open,
                  onTap: () => setState(() => _selectedType = ChallengeType.open),
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: _TypeSelectionCard(
                  title: 'Team Challenge',
                  subtitle: 'Joined to your team',
                  icon: Icons.groups_rounded,
                  isSelected: _selectedType == ChallengeType.team,
                  onTap: () => setState(() => _selectedType = ChallengeType.team),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),

          // Team Selector if Team Challenge
          if (_selectedType == ChallengeType.team) ...[
            Text(
              'Select Team',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6 * scale),
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
            SizedBox(height: 16 * scale),
          ],

          // Step B: Details
          Text(
            '2. DETAILS',
            style: TextStyle(
              color: KickoffColors.dim,
              fontSize: 13 * scale,
              letterSpacing: 1.5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),

          PillField(
            controller: _descriptionController,
            hint: 'Description (e.g. 5v5 Weekend Battle)',
            icon: Icons.description_rounded,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          SizedBox(height: 12 * scale),

          PillField(
            controller: _locationController,
            hint: 'Location (e.g. Sunset Arena Pitch 1)',
            icon: Icons.location_on_rounded,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          SizedBox(height: 12 * scale),

          // Difficulty rating selector
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
          SizedBox(height: 12 * scale),

          // Date & Time pickers
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
          SizedBox(height: 12 * scale),

          // Max players
          PillField(
            controller: _maxPlayersController,
            hint: 'Max Players (e.g. 10)',
            icon: Icons.people_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final n = int.tryParse(v.trim());
              if (n == null || n < 2 || n > 50) return 'Enter 2 to 50 players';
              return null;
            },
          ),
          SizedBox(height: 24 * scale),

          // Submit button
          ChunkyButton(
            label: 'Create Challenge',
            icon: Icons.flash_on_rounded,
            onPressed: _submitting ? null : _submit,
            busy: _submitting,
            backgroundColor: KickoffColors.yellow,
            bottomColor: KickoffColors.yellowDark,
            foregroundColor: KickoffColors.ink,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(double scale) {
    final challenge = _createdChallenge!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
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
                style: TextStyle(
                  color: KickoffColors.muted,
                  fontSize: 14 * scale,
                ),
              ),
              SizedBox(height: 16 * scale),

              // Unique Join Code Box
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      challenge.joinCode,
                      style: TextStyle(
                        color: KickoffColors.yellow,
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3 * scale,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14 * scale),

              // Copy Code Button
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

        // Summary details card
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
              Text(
                'Type: ${challenge.isTeamChallenge ? "Team (${challenge.teamName})" : "Open"}',
                style: TextStyle(color: KickoffColors.muted, fontSize: 14 * scale),
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Location: ${challenge.locationName}',
                style: TextStyle(color: KickoffColors.muted, fontSize: 14 * scale),
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Max Players: ${challenge.maxPlayers}',
                style: TextStyle(color: KickoffColors.muted, fontSize: 14 * scale),
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * scale),

        // Done button
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
