import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bd/user_local_store.dart';
import '../../items/user/avatar_palette.dart';
import '../../items/user/avatar_picker.dart';
import '../../items/user/country_picker.dart';
import '../../services/user/country_service.dart';
import '../../items/user/photo_source.dart';
import '../../items/user/user_avatar.dart';
import '../../services/user/user_profile_controller.dart';
import '../../items/kickoff_style.dart';

/// Lets the player change their username, bio, position and avatar colour.
/// Everything is saved on the phone.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.controller,
    this.countries,
    this.photos,
    super.key,
  });

  final UserProfileController controller;

  /// Camera and gallery access. A default one is made when null.
  final PhotoSource? photos;

  /// Source of the country list. A default one is made when null.
  final CountryService? countries;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late String? _position;
  late int _avatarId;
  late String? _country;
  late String? _photoPath;
  late final PhotoSource _photos = widget.photos ?? ImagePickerPhotoSource();

  /// Copies made in this session and not saved yet. They are deleted when
  /// replaced, removed, or when the screen closes without saving them.
  final _unsaved = <String>{};
  late final CountryService _countries =
      widget.countries ?? CountryService();
  bool _saving = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _username = TextEditingController(text: profile?.username ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
    _position = profile?.position;
    _avatarId = profile?.avatarId ?? 0;
    _country = profile?.country;
    _photoPath = profile?.photoPath;
  }

  @override
  void dispose() {
    for (final path in _unsaved) {
      _photos.delete(path);
    }
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(PhotoChoice choice) async {
    try {
      final path = await _photos.pick(choice);
      if (path == null || !mounted) return;
      final previous = _photoPath;
      if (previous != null && _unsaved.remove(previous)) {
        _photos.delete(previous);
      }
      _unsaved.add(path);
      setState(() {
        _photoPath = path;
        _error = null;
      });
    } on PhotoException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _removePhoto() {
    final previous = _photoPath;
    if (previous != null && _unsaved.remove(previous)) {
      _photos.delete(previous);
    }
    setState(() => _photoPath = null);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final oldPhoto = widget.controller.profile?.photoPath;
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
      country: _country,
      clearCountry: _country == null,
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
    );
    if (!mounted) return;
    if (saved) {
      // The saved copy stays; the one it replaced is no longer needed.
      _unsaved.remove(_photoPath);
      if (oldPhoto != null && oldPhoto != _photoPath) {
        _photos.delete(oldPhoto);
      }
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.lastError;
      });
    }
  }

  Future<void> _pickCountry() async {
    final picked = await pickCountry(context, _countries);
    if (picked != null && mounted) setState(() => _country = picked.code);
  }

  Future<void> _chooseAvatar() async {
    final name = _username.text.trim().isEmpty
        ? '?'
        : _username.text.trim().toLowerCase();
    final look = await pickAvatarLook(
      context,
      username: name,
      colour: _avatarId % avatarColors.length,
      currentLook: avatarLook(_avatarId),
    );
    if (look == null || !mounted) return;
    setState(
      () => _avatarId =
          look * avatarColors.length + _avatarId % avatarColors.length,
    );
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
                child: Form(
                  key: _formKey,
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
                        child: UserAvatarFace(
                          username: _username.text.trim().isEmpty
                              ? initial
                              : _username.text.trim().toLowerCase(),
                          avatarId: _avatarId,
                          size: 80,
                          photoPath: _photoPath,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('photo_camera'),
                          onPressed: () => _takePhoto(PhotoChoice.camera),
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text('Camera'),
                        ),
                        TextButton.icon(
                          key: const ValueKey('photo_gallery'),
                          onPressed: () => _takePhoto(PhotoChoice.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Gallery'),
                        ),
                        if (_photoPath != null)
                          TextButton.icon(
                            key: const ValueKey('photo_remove'),
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < avatarColors.length; i++)
                          _AvatarChoice(
                            color: avatarColors[i],
                            selected: _avatarId % avatarColors.length == i,
                            onTap: () => setState(
                              () => _avatarId =
                                  avatarLook(_avatarId) * avatarColors.length + i,
                            ),
                          ),
                      ],
                    ),
                    if (_photoPath == null)
                      Center(
                        child: TextButton.icon(
                          key: const ValueKey('avatar_choose'),
                          onPressed: _chooseAvatar,
                          icon: const Icon(Icons.face_rounded),
                          label: const Text('Choose avatar'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const _Label('Username'),
                    TextFormField(
                      key: const ValueKey('edit_profile_username'),
                      controller: _username,
                      maxLength: 20,
                      autocorrect: false,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) =>
                          RegExp(r'^[a-zA-Z0-9_]{3,20}$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Use 3-20 letters, numbers, or underscores.',
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
                    const SizedBox(height: 8),
                    const _Label('Country'),
                    Material(
                      color: KickoffColors.field,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: const ValueKey('edit_profile_country'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickCountry,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Text(
                                _country == null ? '🌍' : flagEmoji(_country!),
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _country ?? 'Not set',
                                  style: TextStyle(
                                    color: _country == null
                                        ? KickoffColors.dim
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              if (_country != null)
                                IconButton(
                                  tooltip: 'Clear country',
                                  onPressed: () =>
                                      setState(() => _country = null),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: KickoffColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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
