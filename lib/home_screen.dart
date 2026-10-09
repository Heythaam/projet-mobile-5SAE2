import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'chat_screen.dart';
import 'models.dart';

const _ink = Color(0xFF10112F);
const _pitch = Color(0xFF0866F5);
const _lime = Color(0xFFFFD21E);
const _night = Color(0xFF17194F);
const _nightPanel = Color(0xFF3D4B70);
const _nightRaised = Color(0xFF0866F5);
const _nightText = Color(0xFFEAF0E8);
const _nightMuted = Color(0xFFCDD8F0);

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
  GamificationProfile? _career;
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
      final results = await Future.wait<Object>([
        widget.api.getFriends(),
        widget.api.getFriendRequests(),
        widget.api.getGamificationProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<Friend>;
        _requests = results[1] as List<FriendRequest>;
        _career = results[2] as GamificationProfile;
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
        backgroundColor: _nightPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _ink, width: 3),
        ),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _night,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _night,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _night,
        body: SafeArea(
          bottom: false,
          child: _loadError != null
              ? _ErrorPanel(message: _loadError!, onRetry: _refresh)
              : _loading && _friends.isEmpty && _requests.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _pitch))
              : IndexedStack(
                  index: _tab,
                  children: [
                    _teamTab(),
                    _requestsTab(),
                    _achievementsTab(),
                    _accountTab(),
                  ],
                ),
        ),
        bottomNavigationBar: _navigation(),
      ),
    );
  }

  Widget _teamTab() => RefreshIndicator(
    color: _pitch,
    onRefresh: _refresh,
    backgroundColor: _nightRaised,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _ArcadeBackgroundPainter()),
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _topBar()),
            SliverToBoxAdapter(child: _teamHero()),
            SliverToBoxAdapter(child: _streakCard()),
            SliverToBoxAdapter(child: _questBoard()),
            SliverToBoxAdapter(child: _sectionHeading()),
            if (_friends.isEmpty)
              SliverToBoxAdapter(child: _emptyTeam())
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
      ],
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 15, 22, 17),
    child: Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ink, width: 3),
            boxShadow: [const BoxShadow(color: _ink, offset: Offset(0, 4))],
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            color: _night,
            size: 25,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KICKOFF',
              style: TextStyle(
                color: _nightText,
                letterSpacing: 2.2,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'CAREER HUB  /  SEASON 01',
              style: TextStyle(
                color: _nightText,
                letterSpacing: 0.9,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _nightPanel,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 7, color: _lime),
              const SizedBox(width: 7),
              Text(
                '@${widget.user.username}',
                style: const TextStyle(
                  color: _nightText,
                  fontSize: 11,
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
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF168AFF), Color(0xFF0759E8), Color(0xFF0643B7)],
        ),
        border: Border.all(color: _ink, width: 3),
        boxShadow: [const BoxShadow(color: _ink, offset: Offset(0, 7))],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _TacticsPainter())),
          Positioned(
            right: -18,
            top: 38,
            child: Text(
              (_career?.level ?? 1).toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 180,
                height: 0.9,
                letterSpacing: -14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 17, 19, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _lime,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _ink, width: 2),
                      ),
                      child: const Text(
                        'PLAYER CAREER',
                        style: TextStyle(
                          color: _night,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.bolt_rounded, color: _lime, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_career?.xp ?? 0} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 0.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 84,
                      width: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF174EBB),
                              border: Border.all(color: _ink, width: 3),
                              boxShadow: const [
                                BoxShadow(color: _ink, offset: Offset(0, 4)),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: CircularProgressIndicator(
                              value:
                                  ((_career?.xpIntoLevel ?? 0) /
                                          (_career?.xpForNextLevel ?? 300))
                                      .clamp(0.0, 1.0),
                              strokeWidth: 4,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                _lime,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (_career?.level ?? 1).toString().padLeft(
                                  2,
                                  '0',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1,
                                  fontSize: 27,
                                  letterSpacing: -1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'LEVEL',
                                style: TextStyle(
                                  color: _lime,
                                  fontSize: 7,
                                  letterSpacing: 1.3,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_career?.rank ?? 'ROOKIE').toUpperCase(),
                            style: const TextStyle(
                              color: _lime,
                              fontSize: 9,
                              letterSpacing: 2.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            widget.user.username.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              letterSpacing: -1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _friends.isEmpty
                                ? 'BUILD YOUR SQUAD'
                                : '${_friends.length} TEAMMATE${_friends.length == 1 ? '' : 'S'}',
                            style: const TextStyle(
                              color: _nightMuted,
                              fontSize: 9,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _avatarStack(),
                  ],
                ),
                const SizedBox(height: 19),
                Container(height: 2, color: _ink.withValues(alpha: 0.45)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'NEXT LEVEL',
                      style: TextStyle(
                        color: _nightMuted,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_career?.xpIntoLevel ?? 0} / ${_career?.xpForNextLevel ?? 300} XP',
                      style: const TextStyle(
                        color: _lime,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value:
                        ((_career?.xpIntoLevel ?? 0) /
                                (_career?.xpForNextLevel ?? 300))
                            .clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: _lime,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${(_career?.xpForNextLevel ?? 300) - (_career?.xpIntoLevel ?? 0)} XP REMAINING  /  EARN IT ON THE PITCH',
                  style: const TextStyle(
                    color: _nightMuted,
                    fontSize: 8,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _streakCard() {
    final streak = _career?.currentStreak ?? 0;
    final nextMilestone = streak < 3 ? 3 : 7;
    final progress = streak >= 7 ? 1.0 : streak / nextMilestone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: const Color(0xFF263B71),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ink, width: 3),
          boxShadow: [const BoxShadow(color: _ink, offset: Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              height: 49,
              width: 49,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: streak == 0
                      ? const [Color(0xFF576071), Color(0xFF343A49)]
                      : const [Color(0xFFFFBB52), Color(0xFFF16D43)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  if (streak > 0)
                    BoxShadow(
                      color: const Color(0xFFFF8C4C).withValues(alpha: 0.24),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Icon(
                streak == 0
                    ? Icons.local_fire_department_outlined
                    : Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'DAILY STREAK',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'BEST ${_career?.bestStreak ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFFFFCA75),
                          fontSize: 8,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.05,
                          letterSpacing: -0.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 3),
                        child: Text(
                          streak == 1 ? 'DAY IN A ROW' : 'DAYS IN A ROW',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      color: const Color(0xFFFFB45E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFCB73),
                  size: 20,
                ),
                const SizedBox(height: 3),
                Text(
                  streak >= 7 ? 'MAX' : '${nextMilestone - streak} LEFT',
                  style: const TextStyle(
                    color: Color(0xFFFFCB73),
                    fontSize: 7,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _questBoard() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_soccer_rounded, color: _lime, size: 21),
            const SizedBox(width: 7),
            const Text(
              'MATCH MISSIONS',
              style: TextStyle(
                color: _nightText,
                fontSize: 11,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              _friends.length >= 3 ? 'SQUAD GOAL CLEARED' : 'SEASON CHALLENGES',
              style: const TextStyle(
                color: _nightMuted,
                fontSize: 8,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MissionTile(
          icon: Icons.groups_2_rounded,
          title: 'BUILD YOUR STARTING XI',
          subtitle: 'Recruit 3 teammates',
          progress: _friends.length.clamp(0, 3),
          total: 3,
          action: _friends.length >= 3 ? 'COMPLETE' : 'RECRUIT',
          onTap: _friends.length >= 3 ? null : _inviteFriend,
          complete: _friends.length >= 3,
        ),
        const SizedBox(height: 9),
        _MissionTile(
          icon: Icons.mark_email_unread_rounded,
          title: 'SCOUTING REPORT',
          subtitle: _requests.isEmpty
              ? 'No incoming transfer offers'
              : '${_requests.length} player${_requests.length == 1 ? '' : 's'} want to join your team',
          progress: _requests.isEmpty ? null : 1,
          total: 1,
          action: _requests.isEmpty ? 'SCOUTING' : 'REVIEW',
          onTap: _requests.isEmpty ? null : () => setState(() => _tab = 1),
          complete: false,
        ),
        const SizedBox(height: 9),
        _MissionTile(
          icon: Icons.forum_rounded,
          title: 'PLAYMAKER CHALLENGE',
          subtitle: _friends.isEmpty
              ? 'Unlocks after your first recruit'
              : '${_career?.sentMessages ?? 0} / 10 passes played',
          progress: _friends.isEmpty
              ? null
              : (_career?.sentMessages ?? 0).clamp(0, 10),
          total: 10,
          action: _friends.isEmpty ? 'LOCKED' : 'CHAT',
          onTap: _friends.isEmpty ? null : () => _openChat(_friends.first),
          complete: false,
        ),
      ],
    ),
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
        child: Text(
          '${_requests.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 2.4,
            fontWeight: FontWeight.w900,
          ),
        ),
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
                'SQUAD ROSTER',
                style: TextStyle(
                  color: _nightMuted,
                  fontSize: 9,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your line-up',
                style: TextStyle(
                  color: _nightText,
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
            foregroundColor: _night,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            backgroundColor: _lime,
            side: const BorderSide(color: _ink, width: 2),
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
            color: _nightRaised,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(Icons.group_add_rounded, color: _lime, size: 34),
        ),
        const SizedBox(height: 16),
        const Text(
          'Every great side starts\\nwith one invitation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _nightText,
            fontSize: 21,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your friends. The group chat and game plans\\ncome next.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _nightMuted, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 17),
        OutlinedButton.icon(
          onPressed: _inviteFriend,
          style: OutlinedButton.styleFrom(
            foregroundColor: _lime,
            backgroundColor: _nightRaised,
            side: BorderSide(color: _lime.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Invite your first player'),
        ),
      ],
    ),
  );

  Widget _friendTile(Friend friend) => Material(
    color: _nightPanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: _ink, width: 2),
    ),
    shadowColor: _ink,
    elevation: 4,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openChat(friend),
      borderRadius: BorderRadius.circular(19),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            _PlayerAvatar(
              username: friend.username,
              index: friend.id,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username,
                    style: const TextStyle(
                      color: _nightText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'SQUAD MEMBER  ·  TAP TO CHAT',
                    style: TextStyle(
                      color: _nightMuted,
                      fontSize: 9,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open chat',
              onPressed: () => _openChat(friend),
              style: IconButton.styleFrom(
                backgroundColor: _nightRaised,
                foregroundColor: _lime,
                side: const BorderSide(color: _ink, width: 2),
              ),
              icon: const Icon(Icons.arrow_outward_rounded, size: 18),
            ),
            PopupMenuButton<String>(
              tooltip: 'Player options',
              onSelected: (_) => _removeFriend(friend),
              icon: const Icon(Icons.more_horiz_rounded, color: _nightMuted),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove teammate')),
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
    backgroundColor: _nightPanel,
    child: CustomPaint(
      painter: const _ArcadeBackgroundPainter(),
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
                  return Material(
                    color: _nightRaised,
                    elevation: 5,
                    shadowColor: _ink,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        border: Border.all(color: _ink, width: 2),
                        borderRadius: BorderRadius.circular(14),
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
                                    color: _nightText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Wants you on their team',
                                  style: TextStyle(
                                    color: _nightMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _acceptRequest(request),
                            style: FilledButton.styleFrom(
                              backgroundColor: _lime,
                              foregroundColor: _ink,
                              side: const BorderSide(color: _ink, width: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
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
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );

  Widget _achievementsTab() {
    final badges = _career?.achievements ?? const <Achievement>[];
    final unlockedCount = badges.where((badge) => badge.unlocked).length;
    final totalReward = badges
        .where((badge) => badge.unlocked)
        .fold<int>(0, (sum, badge) => sum + badge.rewardXp);
    return CustomPaint(
      painter: const _ArcadeBackgroundPainter(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _tabTop('CAREER COLLECTION', 'Hall of fame'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 19),
              child: Container(
                height: 158,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF176CF3), Color(0xFF263B71)],
                  ),
                  border: Border.all(color: _ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: _ink, offset: Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _TacticsPainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(17),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'THE TROPHY ROOM',
                                  style: TextStyle(
                                    color: _lime,
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$unlockedCount / ${badges.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 35,
                                    height: 1,
                                    letterSpacing: -1.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'ACHIEVEMENTS UNLOCKED',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.bolt_rounded,
                                      size: 15,
                                      color: Color(0xFFFFD36B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$totalReward XP EARNED FROM BADGES',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD36B),
                                        fontSize: 8,
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 105,
                            width: 105,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFD36B)
                                        .withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: const Color(0xFFFFD36B)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                Transform.rotate(
                                  angle: 0.785,
                                  child: Container(
                                    height: 58,
                                    width: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD36B),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFD36B)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 39,
                                  color: Color(0xFF253251),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BADGE COLLECTION',
                      style: TextStyle(
                        color: _nightText,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${badges.length - unlockedCount} STILL LOCKED',
                    style: const TextStyle(
                      color: _nightMuted,
                      fontSize: 8,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (badges.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: _lime)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverGrid.builder(
                itemCount: badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                  mainAxisExtent: 175,
                ),
                itemBuilder: (context, index) =>
                    _AchievementCard(achievement: badges[index], index: index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _accountTab() => CustomPaint(
    painter: const _ArcadeBackgroundPainter(),
    child: CustomScrollView(
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
                    color: _nightMuted,
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: _nightPanel,
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
                        color: _nightText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_rounded,
                      color: _nightMuted,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
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
            const Icon(Icons.sports_soccer_rounded, color: _lime, size: 21),
            const SizedBox(width: 8),
            const Text(
              'KICKOFF',
              style: TextStyle(
                color: _nightText,
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
            color: _nightMuted,
            fontSize: 9,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _nightText,
            fontSize: 32,
            letterSpacing: -1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _navigation() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF465579), Color(0xFF29385F)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border(top: BorderSide(color: _ink, width: 4)),
    ),
    child: NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _lime : _nightMuted,
            fontSize: 9,
            letterSpacing: 0.3,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _night : _nightMuted,
            size: 21,
          );
        }),
      ),
      child: NavigationBar(
        height: 76,
        backgroundColor: Colors.transparent,
        indicatorColor: _lime,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Awards',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.index});

  final Achievement achievement;
  final int index;

  static const _colors = [
    Color(0xFF57D5B0),
    Color(0xFFFFB64D),
    Color(0xFF76A8FF),
    Color(0xFFFF7BA7),
    Color(0xFFB18CFF),
    Color(0xFFFF815B),
    Color(0xFFFFD45E),
  ];

  IconData get _icon => switch (achievement.icon) {
    'whistle' => Icons.sports_rounded,
    'team' => Icons.groups_2_rounded,
    'formation' => Icons.grid_view_rounded,
    'chat' => Icons.forum_rounded,
    'star' => Icons.stars_rounded,
    'flame' => Icons.local_fire_department_rounded,
    'crown' => Icons.workspace_premium_rounded,
    _ => Icons.military_tech_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = _colors[index % _colors.length];
    final progress = achievement.total == 0
        ? 0.0
        : (achievement.progress / achievement.total).clamp(0.0, 1.0);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF263B71) : const Color(0xFF202B52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: unlocked ? color : _ink, width: 2),
        boxShadow: [const BoxShadow(color: _ink, offset: Offset(0, 4))],
      ),
      child: Stack(
        children: [
          if (unlocked)
            Positioned(
              right: -23,
              top: -31,
              child: Container(
                height: 94,
                width: 94,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: unlocked
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color, color.withValues(alpha: 0.7)],
                              )
                            : null,
                        color: unlocked ? null : const Color(0xFF343B47),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (unlocked)
                            BoxShadow(
                              color: color.withValues(alpha: 0.22),
                              blurRadius: 11,
                            ),
                        ],
                      ),
                      child: Icon(
                        unlocked ? _icon : Icons.lock_rounded,
                        color: unlocked
                            ? const Color(0xFF15221D)
                            : Colors.white38,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (unlocked)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF80E4A4),
                        size: 17,
                      )
                    else
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white38,
                        size: 16,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  achievement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white70,
                    fontSize: 10,
                    height: 1.15,
                    letterSpacing: 0.45,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: unlocked ? 1 : progress,
                          minHeight: 4,
                          color: unlocked ? color : Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      unlocked
                          ? '+${achievement.rewardXp}'
                          : '${achievement.progress}/${achievement.total}',
                      style: TextStyle(
                        color: unlocked ? color : Colors.white54,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    Color(0xFF58D8CB),
    Color(0xFFFF75B5),
    Color(0xFFFFB147),
    Color(0xFF61B7FF),
    Color(0xFFFFD84D),
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
        color: light ? _lime : color,
        shape: BoxShape.circle,
        border: Border.all(color: _ink, width: 2.5),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: _ink,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.total,
    required this.action,
    required this.onTap,
    required this.complete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? progress;
  final int total;
  final String action;
  final VoidCallback? onTap;
  final bool complete;

  @override
  Widget build(BuildContext context) => Material(
    color: _nightRaised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: const BorderSide(color: _ink, width: 2),
    ),
    elevation: 5,
    shadowColor: _ink,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        child: Row(
          children: [
            Container(
              height: 41,
              width: 41,
              decoration: BoxDecoration(
                color: complete ? _lime : const Color(0xFF3CAFEF),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _ink, width: 2),
              ),
              child: Icon(
                complete ? Icons.check_rounded : icon,
                color: complete ? _night : _lime,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 0.65,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _nightMuted, fontSize: 10),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (progress! / total).clamp(0, 1),
                        minHeight: 4,
                        color: _lime,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  color: onTap == null ? const Color(0xFF596789) : _lime,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _ink, width: 2),
                  boxShadow: const [
                    BoxShadow(color: _ink, offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    color: onTap == null ? _nightMuted : _night,
                    fontSize: 8,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
            color: _nightRaised,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: _lime, size: 34),
        ),
        const SizedBox(height: 17),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _nightText,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _nightMuted, height: 1.5, fontSize: 13),
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
    backgroundColor: _nightPanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _ink, width: 3),
    ),
    title: const Text(
      'Add a player',
      style: TextStyle(color: _nightText, fontWeight: FontWeight.w900),
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: 'Their username',
        prefixText: '@',
        filled: true,
        fillColor: _nightRaised,
        labelStyle: const TextStyle(color: _nightMuted),
        hintStyle: const TextStyle(color: _nightMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ink, width: 2),
        ),
      ),
      style: const TextStyle(color: _nightText),
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
          backgroundColor: _lime,
          foregroundColor: _ink,
          side: const BorderSide(color: _ink, width: 2),
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

class _ArcadeBackgroundPainter extends CustomPainter {
  const _ArcadeBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 104.0;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fillA = Paint()
      ..color = const Color(0xFF28318B).withValues(alpha: 0.2);
    final fillB = Paint()
      ..color = const Color(0xFF101849).withValues(alpha: 0.16);

    for (var row = -1; row * tile < size.height + tile; row++) {
      final offset = row.isEven ? 0.0 : tile / 2;
      for (var column = -1; column * tile < size.width + tile; column++) {
        final center = Offset(column * tile + offset, row * tile);
        final path = Path()
          ..moveTo(center.dx, center.dy - tile / 2)
          ..lineTo(center.dx + tile / 2, center.dy)
          ..lineTo(center.dx, center.dy + tile / 2)
          ..lineTo(center.dx - tile / 2, center.dy)
          ..close();
        canvas.drawPath(path, (row + column).isEven ? fillA : fillB);
        canvas.drawPath(path, line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcadeBackgroundPainter oldDelegate) => false;
}
