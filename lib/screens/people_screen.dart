import 'package:flutter/material.dart';

import '../local/user_local_store.dart';
import '../users/country_service.dart';
import '../users/user_avatar.dart';
import '../users/user_profile_controller.dart';
import 'kickoff_style.dart';

/// Profiles saved on this phone, with search and delete. The signed-in profile
/// is marked and cannot be deleted from here.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({required this.controller, super.key});

  final UserProfileController controller;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<LocalUser> _people = const [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final query = _query;
    try {
      final people = await widget.controller.search(query);
      if (!mounted || query != _query) return;
      setState(() {
        _people = people;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Profiles could not be loaded from this phone.';
      });
    }
  }

  Future<void> _delete(LocalUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete @${user.username}?'),
        content: const Text('This removes the profile from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await widget.controller.deleteOther(user.uid);
    if (!mounted) return;
    if (!done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.lastError ?? 'Not deleted.')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                    'On this phone',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey('people_search'),
                onChanged: (value) {
                  _query = value;
                  _load();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search username or bio',
                  hintStyle: const TextStyle(color: KickoffColors.dim),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: KickoffColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: KickoffColors.orange),
        ),
      );
    }
    if (_people.isEmpty) {
      return const Center(
        child: Text(
          'No profile found.',
          key: ValueKey('people_empty'),
          style: TextStyle(color: KickoffColors.muted),
        ),
      );
    }
    final me = widget.controller.uid;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _people[index];
        final isMe = user.uid == me;
        final details = [
          if (user.position != null) user.position!,
          if (user.country != null) flagEmoji(user.country!),
        ].join(' · ');
        return Container(
          key: ValueKey('person_${user.uid}'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KickoffColors.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: UserAvatarFace(
                  username: user.username,
                  avatarId: user.avatarId,
                  size: 44,
                  photoPath: user.photoPath,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${user.username}${isMe ? ' (you)' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: const TextStyle(
                          color: KickoffColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    if (user.bio.isNotEmpty)
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: KickoffColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isMe)
                IconButton(
                  key: ValueKey('delete_${user.uid}'),
                  tooltip: 'Delete profile',
                  onPressed: () => _delete(user),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: KickoffColors.orange,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
