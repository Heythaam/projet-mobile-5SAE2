import 'package:flutter/material.dart';

import 'api_client.dart';
import 'chat_screen.dart';
import 'models.dart';

const _ink = Color(0xFF12251D);
const _pitch = Color(0xFF164A35);
const _lime = Color(0xFFD6F36A);
const _paper = Color(0xFFF7F7F1);
const _muted = Color(0xFF78827A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.api,
    required this.user,
    required this.onLogout,
    super.key,
  });

  final ApiClient api;
  final UserAccount user;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getFriends(),
        widget.api.getFriendRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<Friend>;
        _requests = results[1] as List<FriendRequest>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _inviteFriend() async {
    final username = await showDialog<String>(
      context: context,
      builder: (context) => const _InviteDialog(),
    );
    if (username == null || username.isEmpty || !mounted) return;
    try {
      await widget.api.sendFriendRequest(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to @$username'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await widget.api.acceptFriendRequest(request.id);
      await _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove teammate?'),
        content: Text('Remove @${friend.username} from your team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep friend'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true) return;
    try {
      await widget.api.removeFriend(friend.id);
      await _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _openChat(Friend friend) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          api: widget.api,
          currentUser: widget.user,
          friend: friend,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        bottom: false,
        child: _loadError != null
            ? _ErrorPanel(message: _loadError!, onRetry: _refresh)
            : _loading && _friends.isEmpty && _requests.isEmpty
            ? const Center(child: CircularProgressIndicator(color: _pitch))
            : IndexedStack(
                index: _tab,
                children: [_teamTab(), _requestsTab(), _accountTab()],
              ),
      ),
      bottomNavigationBar: _navigation(),
    );
  }

  Widget _teamTab() => RefreshIndicator(
    color: _pitch,
    onRefresh: _refresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _topBar()),
        SliverToBoxAdapter(child: _teamHero()),
        SliverToBoxAdapter(child: _sectionHeading()),
        if (_friends.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyTeam(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.separated(
              itemCount: _friends.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _friendTile(_friends[index]),
            ),
          ),
      ],
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
    child: Row(
      children: [
        Container(
          height: 39,
          width: 39,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            color: _lime,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'KICKOFF',
          style: TextStyle(
            color: _ink,
            letterSpacing: 2,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFFE9EBE5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 7, color: Color(0xFF49A66E)),
              const SizedBox(width: 7),
              Text(
                '@${widget.user.username}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _teamHero() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Container(
      height: 204,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D6345), Color(0xFF0E3022)],
        ),
        boxShadow: [
          BoxShadow(
            color: _pitch.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _TacticsPainter()),
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 20, 20, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _lime,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'YOUR SQUAD',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.north_east_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _friends.isEmpty
                      ? 'Build your\\nstarting XI.'
                      : 'Good teams\\nstart here.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.02,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _statBlock('${_friends.length}', 'TEAMMATES'),
                    Container(
                      height: 25,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    _statBlock(
                      '${_requests.length}',
                      _requests.length == 1 ? 'NEW REQUEST' : 'REQUESTS',
                    ),
                    const Spacer(),
                    _avatarStack(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statBlock(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: _lime,
          fontSize: 19,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 8,
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _avatarStack() {
    final sample = _friends.take(3).toList();
    if (sample.isEmpty) {
      return Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 17),
      );
    }
    return SizedBox(
      width: 32.0 + (sample.length - 1) * 20,
      height: 32,
      child: Stack(
        children: [
          for (var i = sample.length - 1; i >= 0; i--)
            Positioned(
              left: i * 20,
              child: _PlayerAvatar(
                username: sample[i].username,
                index: i,
                size: 32,
                light: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeading() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 20, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE LOCKER ROOM',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your people',
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _inviteFriend,
          style: TextButton.styleFrom(
            foregroundColor: _pitch,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            backgroundColor: const Color(0xFFE8EEDF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text(
            'ADD PLAYER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  Widget _emptyTeam() => Padding(
    padding: const EdgeInsets.fromLTRB(26, 16, 26, 40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          height: 74,
          width: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEDF),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.group_add_rounded,
            color: _pitch,
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Every great side starts\\nwith one invitation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 21,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your friends. The group chat and game plans\\ncome next.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 17),
        OutlinedButton.icon(
          onPressed: _inviteFriend,
          style: OutlinedButton.styleFrom(
            foregroundColor: _pitch,
            side: const BorderSide(color: Color(0xFFC9D4C5)),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Invite your first player'),
        ),
      ],
    ),
  );

  Widget _friendTile(Friend friend) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: () => _openChat(friend),
      borderRadius: BorderRadius.circular(19),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            _PlayerAvatar(username: friend.username, index: friend.id, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Teammate  ·  Tap to chat',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open chat',
              onPressed: () => _openChat(friend),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEAF0E7),
                foregroundColor: _pitch,
              ),
              icon: const Icon(Icons.arrow_outward_rounded, size: 18),
            ),
            PopupMenuButton<String>(
              tooltip: 'Player options',
              onSelected: (_) => _removeFriend(friend),
              icon: const Icon(Icons.more_horiz_rounded, color: _muted),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove teammate'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _requestsTab() => RefreshIndicator(
    color: _pitch,
    onRefresh: _refresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _tabTop('INCOMING PASSES', 'Requests')),
        if (_requests.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.mark_email_unread_outlined,
              title: 'Nothing in the inbox.',
              message: 'When a player invites you to their team,\\nthey’ll show up here.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverList.separated(
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = _requests[index];
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      _PlayerAvatar(
                        username: request.user.username,
                        index: request.id,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.user.username,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Wants you on their team',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _acceptRequest(request),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          foregroundColor: _lime,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        child: const Text(
                          'JOIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );

  Widget _accountTab() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _tabTop('PLAYER CARD', 'Your profile')),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KICKOFF  /  PLAYER',
                      style: TextStyle(
                        color: _lime,
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.sports_soccer_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                Row(
                  children: [
                    _PlayerAvatar(
                      username: widget.user.username,
                      index: widget.user.id,
                      size: 62,
                      light: true,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              letterSpacing: -0.7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _profileStat('${_friends.length}', 'TEAMMATES'),
                    const SizedBox(width: 32),
                    _profileStat('${_requests.length}', 'INVITES'),
                    const Spacer(),
                    const Text(
                      'READY TO PLAY',
                      style: TextStyle(
                        color: _lime,
                        fontSize: 9,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCOUNT',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                child: ListTile(
                  onTap: widget.onLogout,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFAF4F43),
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _profileStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 8,
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _tabTop(String eyebrow, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 21),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_soccer_rounded, color: _pitch, size: 21),
            const SizedBox(width: 8),
            const Text(
              'KICKOFF',
              style: TextStyle(
                color: _ink,
                letterSpacing: 1.7,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            _PlayerAvatar(
              username: widget.user.username,
              index: widget.user.id,
              size: 37,
            ),
          ],
        ),
        const SizedBox(height: 27),
        Text(
          eyebrow,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 32,
            letterSpacing: -1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _navigation() => NavigationBar(
    height: 72,
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFFE8EEDF),
    selectedIndex: _tab,
    onDestinationSelected: (index) => setState(() => _tab = index),
    destinations: [
      const NavigationDestination(
        icon: Icon(Icons.groups_2_outlined),
        selectedIcon: Icon(Icons.groups_2_rounded),
        label: 'My team',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _requests.isNotEmpty,
          label: Text('${_requests.length}'),
          child: const Icon(Icons.move_to_inbox_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: _requests.isNotEmpty,
          label: Text('${_requests.length}'),
          child: const Icon(Icons.move_to_inbox_rounded),
        ),
        label: 'Invites',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.username,
    required this.index,
    required this.size,
    this.light = false,
  });

  final String username;
  final int index;
  final double size;
  final bool light;

  static const _colors = [
    Color(0xFFD9E8C2),
    Color(0xFFF3D9B8),
    Color(0xFFD5E2EC),
    Color(0xFFF1D6D9),
    Color(0xFFE8E1B9),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = username.isEmpty ? '?' : username[0].toUpperCase();
    final color = _colors[index.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: 0.17) : color,
        shape: BoxShape.circle,
        border: Border.all(color: light ? Colors.white54 : Colors.white, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: light ? Colors.white : _pitch,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 0, 26, 60),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEDF),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: _pitch, size: 34),
        ),
        const SizedBox(height: 17),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.5, fontSize: 13),
        ),
      ],
    ),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _paper,
    title: const Text(
      'Add a player',
      style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: 'Their username',
        prefixText: '@',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Not now'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: _lime,
        ),
        child: const Text('Send invite'),
      ),
    ],
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: _pitch, size: 44),
          const SizedBox(height: 13),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _TacticsPainter extends CustomPainter {
  const _TacticsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final field = Rect.fromLTWH(
      size.width * 0.52,
      -size.height * 0.25,
      size.width * 0.74,
      size.height * 1.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(24)),
      line,
    );
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      line,
    );
    canvas.drawCircle(field.center, 42, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(field.left, field.center.dy),
        width: 72,
        height: 112,
      ),
      line,
    );
    final spot = Paint()..color = _lime;
    for (final point in [
      Offset(size.width * 0.72, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.72),
      Offset(size.width * 0.57, size.height * 0.55),
    ]) {
      canvas.drawCircle(point, 4, spot);
      canvas.drawCircle(
        point,
        12,
        Paint()
          ..color = _lime.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
