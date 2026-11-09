import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../local/user_local_store.dart';
import '../users/avatar_palette.dart';
import '../users/user_profile_controller.dart';
import 'kickoff_style.dart';

/// Lets the player change their username, bio, position and avatar colour.
/// Everything is saved on the phone.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.controller, super.key});

  final UserProfileController controller;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late String? _position;
  late int _avatarId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _username = TextEditingController(text: profile?.username ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
    _position = profile?.position;
    _avatarId = profile?.avatarId ?? 0;
  }

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.controller.save(
      username: _username.text,
      bio: _bio.text,
      position: _position,
      clearPosition: _position == null,
      avatarId: _avatarId,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _username.text.trim().isEmpty
        ? '?'
        : _username.text.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: ArcadeBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: KickoffColors.muted,
                      ),
                    ),
                    const Text(
                      'Edit profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        key: const ValueKey('edit_profile_avatar'),
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: avatarColor(_avatarId),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: KickoffColors.blue,
                            width: 4,
                          ),
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: KickoffColors.ink,
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < avatarColors.length; i++)
                          _AvatarChoice(
                            color: avatarColors[i],
                            selected: _avatarId == i,
                            onTap: () => setState(() => _avatarId = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _Label('Username'),
                    TextField(
                      key: const ValueKey('edit_profile_username'),
                      controller: _username,
                      maxLength: 20,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[a-zA-Z0-9_]'),
                        ),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: _fieldDecoration(
                        'Letters, numbers, underscores',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    const _Label('Bio'),
                    TextField(
                      key: const ValueKey('edit_profile_bio'),
                      controller: _bio,
                      maxLength: UserLocalStore.bioMaxLength,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: _fieldDecoration('Tell players about you'),
                    ),
                    const SizedBox(height: 8),
                    const _Label('Position'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final position in const ['GK', 'DEF', 'MID', 'FWD'])
                          ChoiceChip(
                            key: ValueKey('position_$position'),
                            label: Text(position),
                            selected: _position == position,
                            // Tapping the chosen position again clears it.
                            onSelected: (selected) => setState(
                              () => _position = selected ? position : null,
                            ),
                            selectedColor: KickoffColors.yellow,
                            backgroundColor: KickoffColors.panel,
                            labelStyle: TextStyle(
                              color: _position == position
                                  ? KickoffColors.ink
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        key: const ValueKey('edit_profile_error'),
                        style: const TextStyle(
                          color: KickoffColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Saved on this phone.',
                      style: TextStyle(color: KickoffColors.dim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ChunkyButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  busy: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: KickoffColors.dim),
    counterStyle: const TextStyle(color: KickoffColors.dim),
    filled: true,
    fillColor: KickoffColors.field,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: KickoffColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Avatar colour',
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: KickoffColors.ink)
            : null,
      ),
    ),
  );
}
