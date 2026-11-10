import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../chat_screen.dart';
import '../models.dart';
import '../screens/kickoff_style.dart';
import 'friends_service.dart';

/// The player's friends: pending requests, the friend list, adding someone by
/// username, and an invite message for people who are not on the app yet.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({required this.friends, required this.user, super.key});

  final FriendsService friends;
  final UserAccount user;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Friend> _friends = const [];
  List<FriendRequest> _requests = const [];
  bool _loading = true;
  String? _error;

  String get _inviteText =>
      'Join me on Kickoff and play football with friends! '
      'Add me as a friend: @${widget.user.username}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _message(Object error) =>
      error is FriendsException ? error.message : 'Could not reach the cloud.';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await widget.friends.getFriends();
      final requests = await widget.friends.getFriendRequests();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (done != null && mounted) _toast(done);
      await _load();
    } catch (error) {
      if (mounted) _toast(_message(error));
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _inviteText));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _inviteText));
      if (mounted) _toast('Invite copied');
    }
  }

  Future<void> _add() async {
    final username = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddFriendSheet(onShare: _share),
    );
    if (username == null || username.isEmpty) return;
    await _run(
      () => widget.friends.sendFriendRequest(username.replaceFirst('@', '')),
      done: 'Request sent to @${username.replaceFirst('@', '')}',
    );
  }

  Future<void> _remove(Friend friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove @${friend.username}?'),
        content: const Text('You will no longer be friends.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => widget.friends.removeFriend(friend));
  }

  void _chat(Friend friend) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        friends: widget.friends,
        currentUser: widget.user,
        friend: friend,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ArcadeBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
                    'Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('friends_add'),
                    tooltip: 'Add a friend',
                    onPressed: _add,
                    icon: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: KickoffColors.yellow,
                    ),
                  ),
                ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KickoffColors.muted),
            ),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          if (_requests.isNotEmpty) ...[
            const _Header('Requests'),
            for (final request in _requests)
              _Tile(
                key: ValueKey('request_${request.id}'),
                name: request.user.username,
                subtitle: 'Wants to be your friend',
                trailing: FilledButton(
                  onPressed: () => _run(
                    () => widget.friends.acceptFriendRequest(request),
                    done: 'You are now friends with @${request.user.username}',
                  ),
                  child: const Text('Accept'),
                ),
              ),
          ],
          _Header('Friends (${_friends.length})'),
          if (_friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No friends yet. Add someone by username, or send them an '
                'invite.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KickoffColors.muted),
              ),
            ),
          for (final friend in _friends)
            _Tile(
              key: ValueKey('friend_${friend.id}'),
              name: friend.username,
              subtitle: 'Tap to chat',
              onTap: () => _chat(friend),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('chat_${friend.id}'),
                    tooltip: 'Chat',
                    onPressed: () => _chat(friend),
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      color: KickoffColors.yellow,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove friend',
                    onPressed: () => _remove(friend),
                    icon: const Icon(
                      Icons.person_remove_rounded,
                      color: KickoffColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('friends_share'),
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Invite someone by message'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: KickoffColors.yellow,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.name,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    super.key,
  });

  final String name;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: KickoffColors.blue,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: KickoffColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bottom sheet to add a friend: a username, or an invite for someone who is
/// not on Kickoff yet.
class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.onShare});

  final Future<void> Function() onShare;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add a friend',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Type their username to send a request.',
          style: TextStyle(color: KickoffColors.muted),
        ),
        const SizedBox(height: 16),
        PillField(
          key: const ValueKey('friend_username'),
          controller: _controller,
          hint: 'Username',
          icon: Icons.alternate_email_rounded,
          autofocus: true,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => ChunkyButton(
            key: const ValueKey('friend_send'),
            label: 'Send request',
            icon: Icons.send_rounded,
            onPressed: value.text.trim().isEmpty ? null : _send,
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: Divider(color: KickoffColors.dim)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: TextStyle(color: KickoffColors.dim)),
            ),
            Expanded(child: Divider(color: KickoffColors.dim)),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('friend_invite'),
          onPressed: widget.onShare,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Invite by message'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: KickoffColors.dim),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'For friends who do not have Kickoff yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KickoffColors.dim, fontSize: 12),
        ),
      ],
    ),
  );
}
